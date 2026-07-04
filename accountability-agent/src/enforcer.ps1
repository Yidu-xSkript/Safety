param(
    [string]$SecretsDir = "C:\ProgramData\AccountabilityAgent",
    [string]$RuntimeDir = "C:\ProgramData\AccountabilityAgentRuntime"
)

Import-Module "$PSScriptRoot/Common.psm1"    -Force
Import-Module "$PSScriptRoot/Detection.psm1" -Force
Import-Module "$PSScriptRoot/Report.psm1"    -Force
Import-Module "$PSScriptRoot/Enforce.psm1"   -Force
Import-Module "$PSScriptRoot/Policy.psm1"    -Force
Import-Module "$PSScriptRoot/Streak.psm1"    -Force
Import-Module "$PSScriptRoot/Blocklist.psm1" -Force

$cfg       = Get-AgentConfig -Path (Join-Path $SecretsDir "agent-config.json")
$heartbeat = Join-Path $RuntimeDir "monitor.heartbeat"
$lastReport = Get-Date
$startTime  = Get-Date   # for the dead-man startup grace
$tamperNotified = $false
$timeBoxAlerted = @{}   # "app|yyyyMMdd" -> $true, so each over-limit app alerts the witness once per day
$tamperAlerted  = @{}   # "kind|yyyyMMdd" -> $true, so each tamper kind alerts the witness once per day
$firstLoop      = $true # suppress alerts on the initial DNS/hosts application (that's setup, not tampering)
$failsafeTripped = $false # true while NextDNS is unreachable and the DNS lock has been backed off
$configPath = Join-Path $SecretsDir "agent-config.json"
$configHash = try { (Get-FileHash -Path $configPath -Algorithm SHA256 -ErrorAction Stop).Hash } catch { "" }

# Porn blocklist (VPN-proof via the hosts file). Downloaded + refreshed daily by the agent.
$hostsPath   = "$env:WINDIR\System32\drivers\etc\hosts"
$pornCache   = Join-Path $SecretsDir "porn-blocklist.txt"
$pornUrl     = if ($cfg.pornBlocklistUrl) { "$($cfg.pornBlocklistUrl)" } else { "" }   # "" = built-in curated top list
$pornMax     = if ($cfg.pornBlocklistMaxDomains) { [int]$cfg.pornBlocklistMaxDomains } else { 20000 }  # hard cap so hosts stays fast
$pornEnabled = -not ($cfg.pornBlocklistEnabled -eq $false)   # default ON unless config sets it false
$safeSearchEnabled = -not ($cfg.safeSearchEnabled -eq $false)   # force SafeSearch (Google/Bing/DDG); default ON
$dohFwEnabled = ($cfg.dohFirewallEnabled -eq $true)   # aggressive DNS firewall block; OFF by default (can break VPNs)
$expectedHostsHash = ""     # hash of the hosts file after our last write, for cheap tamper detection
$desired = $null            # cached desired domain set (app-policy + porn); recomputed only on change
$safeRedirects = @{}        # cached SafeSearch host->IP redirects; recomputed with $desired
$lastOverKey = ""; $lastPornMtime = $null

# Supporter-mode streak state lives in the admin-only SecretsDir (SYSTEM-written) so the
# protected user cannot fabricate a milestone message to their partner.
$streakFile = Join-Path $SecretsDir "streak.json"
$milestones = if ($cfg.supporterMilestones) { @($cfg.supporterMilestones | ForEach-Object { [int]$_ }) } else { @(7,30,90) }
$streak = if (Test-Path $streakFile) {
    $o = Get-Content $streakFile -Raw | ConvertFrom-Json
    @{ Day = "$($o.Day)"; Flagged = [bool]$o.Flagged; StreakDays = [int]$o.StreakDays; LastNotified = [int]$o.LastNotified }
} else {
    @{ Day = ""; Flagged = $false; StreakDays = 0; LastNotified = 0 }
}
$lastStreakSerialized = ($streak | ConvertTo-Json -Compress)

# NOTE: the DNS firewall lock is applied INSIDE the loop, and only when NextDNS is verified
# reachable (see the DNS section). This is the fail-safe: we never strangle DNS blindly.

while ($true) {
  # One transient failure (SMTP hiccup, partial file read) must not kill the loop and
  # trigger a restart that re-fires alerts. Contain each iteration; log and continue.
  try {
    $day = Get-Date -Format "yyyyMMdd"
    # Roll the clean-day streak forward if the calendar day changed.
    $streak = Update-DayState -State $streak -Today $day

    # --- VPN kill-switch (Option A: kill unapproved VPN, keep internet) ---
    $vpn = Get-VpnAdapterState
    if (Test-UnapprovedVpn -VpnAdapterPresent $vpn.Present `
            -ActiveRemoteIps (Get-ActiveRemoteIp) -ApprovedIps $cfg.approvedVpnIps) {
        Disable-VpnAdapter -Adapters $vpn.Adapters
        $alert = Format-AlertEmail -Kind "UnapprovedVPN" -Detail (($vpn.Adapters.Name) -join ", ")
        Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $alert.Subject -Body $alert.Body
        Write-AgentLog "Unapproved VPN disabled: $($alert.Body)"
        $streak.Flagged = $true   # today is not a clean day
    }

    # --- DNS lock (fail-safe + VPN-safe) ---
    # The DoH FIREWALL block (blocking all DNS except NextDNS) can strangle a VPN's own DNS and has
    # broken connectivity in practice, so it is OPT-IN (config: dohFirewallEnabled, default off).
    # When it's off we make sure no stale AA firewall rules linger. DNS enforcement then uses only
    # the gentle Set-NextDnsLock (sets the DNS server; blocks nothing).
    if (-not $dohFwEnabled) { Remove-DohFirewallBlock }

    if ($vpn.Present) {
        # A VPN is up — it owns DNS/routing. Do NOT lock DNS or firewall-block; remove any block so
        # the VPN's own DNS works. Hosts-based blocking (porn/SafeSearch/apps) still applies.
        Remove-DohFirewallBlock
    } elseif (Test-NextDnsReachable -NextDnsIps $cfg.nextDnsIps) {
        if ($failsafeTripped) { Write-AgentLog "NextDNS reachable again; re-arming DNS lock."; $failsafeTripped = $false }
        if ($dohFwEnabled) { Set-DohFirewallBlock -NextDnsIps $cfg.nextDnsIps }
        $dnsChanged = Set-NextDnsLock -NextDnsIps $cfg.nextDnsIps
        # A VPN legitimately changes DNS, so only treat a DNS change as tampering when NO VPN is up.
        if ($dnsChanged -and -not $firstLoop -and -not $vpn.Present) {
            $streak.Flagged = $true
            $k = "DnsTamper|$day"
            if (-not $tamperAlerted[$k]) {
                $al = Format-AlertEmail -Kind "DnsTamper" -Detail ""
                Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $al.Subject -Body $al.Body
                Write-AgentLog "Tamper: DNS changed away from NextDNS; restored + alerted."
                $tamperAlerted[$k] = $true
            }
        }
    } else {
        # NextDNS not answering — do NOT strangle DNS. Back off to keep the machine online.
        Remove-DohFirewallBlock
        Reset-DnsToAuto
        if (-not $failsafeTripped) {
            $al = Format-AlertEmail -Kind "DnsFailsafe" -Detail ""
            try { Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $al.Subject -Body $al.Body } catch { }
            Write-AgentLog "NextDNS unreachable; DNS lock backed off to preserve connectivity."
            $failsafeTripped = $true
        }
    }

    # --- App policy: hosts-block 'block' apps + over-limit time-box apps ---
    $overLimit = @()
    foreach ($p in $cfg.appPolicies) {
        if ($p.policy -eq "time-box") {
            $file = Join-Path $RuntimeDir ("usage-{0}-{1}.txt" -f $p.name, $day)
            $secs = 0; if (Test-Path $file) { $secs = [int](Get-Content $file -Raw) }
            if (Test-OverDailyLimit -AccruedMinutes ([int]($secs/60)) -LimitMinutes $p.dailyLimitMinutes) {
                $overLimit += $p.name
                $key = "$($p.name)|$day"
                if (-not $timeBoxAlerted[$key]) {
                    $a = Format-AlertEmail -Kind "TimeBox" -Detail $p.name
                    Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $a.Subject -Body $a.Body
                    Write-AgentLog "Time-box limit reached: $($p.name)"
                    $timeBoxAlerted[$key] = $true
                }
            }
        }
    }
    if ($overLimit.Count -gt 0) { $streak.Flagged = $true }   # a breach means today is not clean

    # --- Hosts block: app-policy 'block' domains + the porn blocklist (VPN-proof) ---
    # Refresh the porn list at most daily (cheap no-op when fresh). Rebuild the desired set only
    # when the over-limit apps or the porn list actually change (avoids re-sorting tens of
    # thousands of domains every poll). Tamper is caught by hashing the hosts file each loop
    # against what we last wrote — a hosts edit with an unchanged desired set means an external edit.
    Update-PornBlocklist -Url $pornUrl -CachePath $pornCache -MaxAgeHours 24 -MaxDomains $pornMax | Out-Null
    $pornMtime = if (Test-Path $pornCache) { (Get-Item $pornCache).LastWriteTimeUtc } else { $null }
    $overKey = (@($overLimit) | Sort-Object) -join ','
    if (($null -eq $desired) -or ($overKey -ne $lastOverKey) -or ($pornMtime -ne $lastPornMtime)) {
        $pornDomains = if ($pornEnabled) { Get-PornBlocklist -CachePath $pornCache } else { @() }
        $appDomains  = Get-DesiredHostsEntries -Policies $cfg.appPolicies -OverLimitApps $overLimit
        $desired = @(@($appDomains) + @($pornDomains) | Select-Object -Unique)
        $safeRedirects = if ($safeSearchEnabled) { Get-SafeSearchRedirects } else { @{} }
        $lastOverKey = $overKey; $lastPornMtime = $pornMtime
        $setChanged = $true
    } else { $setChanged = $false }

    $curHostsHash = if (Test-Path $hostsPath) { (Get-FileHash -Path $hostsPath -Algorithm SHA256).Hash } else { "" }
    $tampered = (-not $firstLoop) -and (-not $setChanged) -and ($curHostsHash -ne $expectedHostsHash)
    if ($firstLoop -or $setChanged -or $tampered) {
        Set-HostsBlock -Domains $desired -Redirects $safeRedirects | Out-Null
        $expectedHostsHash = if (Test-Path $hostsPath) { (Get-FileHash -Path $hostsPath -Algorithm SHA256).Hash } else { "" }
        if ($tampered) {
            $streak.Flagged = $true
            $k = "HostsTamper|$day"
            if (-not $tamperAlerted[$k]) {
                $al = Format-AlertEmail -Kind "HostsTamper" -Detail ""
                Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $al.Subject -Body $al.Body
                Write-AgentLog "Tamper: hosts block edited externally; restored + alerted."
                $tamperAlerted[$k] = $true
            }
        }
    }

    # --- Config-file tamper: alert if agent-config.json changed on disk ---
    $curHash = try { (Get-FileHash -Path $configPath -Algorithm SHA256 -ErrorAction Stop).Hash } catch { $configHash }
    if ($configHash -and $curHash -ne $configHash) {
        $streak.Flagged = $true
        $k = "ConfigTamper|$day"
        if (-not $tamperAlerted[$k]) {
            $al = Format-AlertEmail -Kind "ConfigTamper" -Detail ""
            Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $al.Subject -Body $al.Body
            Write-AgentLog "Tamper: agent-config.json altered + alerted."
            $tamperAlerted[$k] = $true
        }
        $configHash = $curHash
    }

    # --- Supporter mode: milestone encouragement to the partner (opt-in via supporterEmail) ---
    $due = Get-DueMilestone -StreakDays $streak.StreakDays -Milestones $milestones -LastNotified $streak.LastNotified
    if ($due -gt 0 -and $cfg.supporterEmail) {
        $s = Format-SupporterEmail -StreakDays $streak.StreakDays -Milestone $due
        Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.supporterEmail -Subject $s.Subject -Body $s.Body
        Write-AgentLog "Supporter milestone $due sent to $($cfg.supporterEmail)."
        $streak.LastNotified = $due
    }

    # --- Purge usage files from previous days ---
    Get-ChildItem -Path $RuntimeDir -Filter "usage-*.txt" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*-$day.txt" } | Remove-Item -Force -ErrorAction SilentlyContinue

    # --- Persist streak state only when it changed ---
    $serialized = ($streak | ConvertTo-Json -Compress)
    if ($serialized -ne $lastStreakSerialized) {
        $serialized | Set-Content -Path $streakFile -Encoding utf8
        $lastStreakSerialized = $serialized
    }

    # --- Dead-man's switch: monitor heartbeat must be fresh ---
    $lastBeat = $null
    if (Test-Path $heartbeat) {
        $raw = (Get-Content $heartbeat -Raw)
        if ($raw) {
            try { $lastBeat = [datetime]::ParseExact($raw.Trim(), 'o', [Globalization.CultureInfo]::InvariantCulture) }
            catch { $lastBeat = $null }
        }
    }
    # Startup grace: don't fire the dead-man until the enforcer has run longer than the stale
    # window, so a monitor that is still coming up after boot/login doesn't false-alarm.
    $pastStartupGrace = ((Get-Date) - $startTime).TotalSeconds -gt [int]$cfg.heartbeatStaleSeconds
    if ($pastStartupGrace -and (Test-HeartbeatStale -LastBeat $lastBeat -Now (Get-Date) -ThresholdSeconds ([int]$cfg.heartbeatStaleSeconds))) {
        if (-not $tamperNotified) {
            $alert = Format-AlertEmail -Kind "Tamper" -Detail "monitor heartbeat stale > $($cfg.heartbeatStaleSeconds)s"
            Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $alert.Subject -Body $alert.Body
            Write-AgentLog "Dead-man alert sent."
            $tamperNotified = $true
        }
    } else { $tamperNotified = $false }

    # --- Scheduled report ---
    if (((Get-Date) - $lastReport).TotalMinutes -ge [int]$cfg.reportIntervalMinutes) {
        & "$PSScriptRoot/reporter.ps1" -SecretsDir $SecretsDir -RuntimeDir $RuntimeDir
        $lastReport = Get-Date
    }

    $firstLoop = $false   # initial DNS/hosts application done; further corrections count as tampering
  } catch {
    Write-AgentLog "Enforcer loop error: $($_.Exception.Message)"
  }

  Start-Sleep -Seconds ([int]$cfg.vpnPollSeconds)
}
