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
$staleSince = $null      # when the monitor heartbeat first went stale (for self-heal + alert timing)
$tamperNotified = $false
$timeBoxAlerted = @{}   # "app|yyyyMMdd" -> $true, so each over-limit app alerts the witness once per day
$tamperAlerted  = @{}   # "kind|yyyyMMdd" -> $true, so each tamper kind alerts the witness once per day
$pornAlerted    = @{}   # "url|yyyyMMdd" -> $true, so each adult URL fires one instant alert per day (no spam on repeat visits)
# PERSIST the tamper-alert dedup across restarts. In-memory only, it was re-armed on every enforcer
# restart (reinstall, dead-man self-heal, crash) — so the witness got the SAME alert re-sent each
# time (the #1 cause of inbox spam during setup). Load today's already-sent keys so we don't re-fire.
$alertStateFile = Join-Path $SecretsDir "alert-state.txt"
$todayInit = Get-Date -Format "yyyyMMdd"
if (Test-Path $alertStateFile) {
    foreach ($key in (Get-Content $alertStateFile -ErrorAction SilentlyContinue)) {
        if ($key -and $key.EndsWith("|$todayInit")) { $tamperAlerted[$key] = $true }
    }
}
$lastAlertKeys = (($tamperAlerted.Keys | Sort-Object) -join "`n")
$firstLoop      = $true # suppress alerts on the initial DNS/hosts application (that's setup, not tampering)
$failsafeTripped = $false # true while NextDNS is unreachable and the DNS lock has been backed off
$configPath = Join-Path $SecretsDir "agent-config.json"
$configHash = try { (Get-FileHash -Path $configPath -Algorithm SHA256 -ErrorAction Stop).Hash } catch { "" }
$installStampFile = Join-Path $SecretsDir "install.stamp"
$installSeenFile  = Join-Path $SecretsDir "install.seen"
$installSeen = if (Test-Path $installSeenFile) { (Get-Content $installSeenFile -Raw).Trim() } else { "" }

# Porn blocklist (VPN-proof via the hosts file). Downloaded + refreshed daily by the agent.
$hostsPath   = "$env:WINDIR\System32\drivers\etc\hosts"
$pornCache   = Join-Path $SecretsDir "porn-blocklist.txt"
$pornUrl     = if ($cfg.pornBlocklistUrl) { "$($cfg.pornBlocklistUrl)" } else { "" }   # "" = built-in curated top list
$pornMax     = if ($cfg.pornBlocklistMaxDomains) { [int]$cfg.pornBlocklistMaxDomains } else { 20000 }  # hard cap so hosts stays fast
$pornEnabled = -not ($cfg.pornBlocklistEnabled -eq $false)   # default ON unless config sets it false
$safeSearchEnabled = -not ($cfg.safeSearchEnabled -eq $false)   # force SafeSearch (Google/Bing/DDG); default ON
$dohFwEnabled = ($cfg.dohFirewallEnabled -eq $true)   # aggressive DNS firewall block; OFF by default (can break VPNs)
$dnsMgmtEnabled = -not ($cfg.dnsManagementEnabled -eq $false)   # let the agent manage OS DNS; set false when the NextDNS app (DoH) handles DNS
$incognitoDisableEnabled = -not ($cfg.incognitoDisableEnabled -eq $false)   # kill browser incognito/private mode; default ON
$torBlockEnabled = -not ($cfg.torBlockEnabled -eq $false)   # detect + close Tor Browser (bypasses NextDNS); default ON
$instantPornAlertEnabled = -not ($cfg.instantPornAlertEnabled -eq $false)   # email witness the moment a porn URL is seen; default ON
$expectedHostsHash = ""     # hash of the hosts file after our last write, for cheap tamper detection
$desired = $null            # cached desired domain set (app-policy + porn); recomputed only on change
$safeRedirects = @{}        # cached SafeSearch host->IP redirects; recomputed with $desired
$lastOverKey = ""; $lastPornMtime = $null; $lastVpnActive = $false

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

    # --- Disable browser incognito/private mode. Pre-seeds enterprise policies so even a
    # not-yet-installed browser honors it on first launch, restoring history-reader visibility.
    # Idempotent + SYSTEM-written each loop, so a deleted key self-heals. ---
    if ($incognitoDisableEnabled) {
        $incognitoChanged = Set-IncognitoDisabled
        # A correction after startup means a browser policy was flipped back on (tamper).
        if ($incognitoChanged -and -not $firstLoop) {
            $streak.Flagged = $true
            $k = "IncognitoTamper|$day"
            if (-not $tamperAlerted[$k]) {
                $al = Format-AlertEmail -Kind "IncognitoTamper" -Detail ""
                Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $al.Subject -Body $al.Body
                Write-AgentLog "Tamper: incognito re-enabled; re-disabled + alerted."
                $tamperAlerted[$k] = $true
            }
        }
    }

    # --- Close Tor Browser on sight. Tor bypasses NextDNS and the history report entirely, and
    # ignores the incognito policy, so process-kill is the only lever (friction not lock — bridges/
    # mirrors remain get-aroundable, but every launch is closed + logged + alerted). ---
    if ($torBlockEnabled) {
        $torKilled = Stop-TorBrowser
        if ($torKilled.Count -gt 0) {
            $streak.Flagged = $true
            $k = "TorBlocked|$day"
            if (-not $tamperAlerted[$k]) {
                $al = Format-AlertEmail -Kind "TorBlocked" -Detail ($torKilled -join ", ")
                Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $al.Subject -Body $al.Body
                Write-AgentLog "Tor Browser detected and closed ($($torKilled -join ', ')); witness alerted."
                $tamperAlerted[$k] = $true
            }
        }
    }

    # --- VPN kill-switch (Option A: kill unapproved VPN, keep internet) ---
    $vpn = Get-VpnAdapterState
    $vpnActive = Test-VpnActive -ApprovedVpnIps $cfg.approvedVpnIps   # robust "is any VPN up?" check
    if (Test-UnapprovedVpn -VpnAdapterPresent $vpn.Present `
            -ActiveRemoteIps (Get-ActiveRemoteIp) -ApprovedIps $cfg.approvedVpnIps) {
        Disable-VpnAdapter -Adapters $vpn.Adapters
        $alert = Format-AlertEmail -Kind "UnapprovedVPN" -Detail (($vpn.Adapters.Name) -join ", ")
        Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $alert.Subject -Body $alert.Body
        Write-AgentLog "Unapproved VPN disabled: $($alert.Body)"
        $streak.Flagged = $true   # today is not a clean day
    }
    elseif ($vpnActive) {
        # An approved/allowed VPN is up. NextDNS logging is blind during it, so notify the witness
        # (once per day) that a VPN session is happening and to review the activity report.
        $k = "ApprovedVpn|$day"
        if (-not $tamperAlerted[$k]) {
            $al = Format-AlertEmail -Kind "ApprovedVpnActive" -Detail ""
            Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $al.Subject -Body $al.Body
            Write-AgentLog "Approved VPN active; witness notified."
            $tamperAlerted[$k] = $true
        }
    }

    # --- DNS lock (fail-safe + VPN-safe). SKIPPED entirely when the NextDNS app / another tool
    # already handles DNS (config: dnsManagementEnabled=false) — the agent must not fight it,
    # which otherwise causes reachable/unreachable flapping and failsafe-alert spam. ---
    if (-not $dnsMgmtEnabled) {
      Remove-DohFirewallBlock   # just make sure no stale AA firewall rules linger
    } else {
    # The DoH FIREWALL block (blocking all DNS except NextDNS) can strangle a VPN's own DNS and has
    # broken connectivity in practice, so it is OPT-IN (config: dohFirewallEnabled, default off).
    if (-not $dohFwEnabled) { Remove-DohFirewallBlock }

    if ($vpnActive) {
        # A VPN is up — it owns DNS/routing. Do NOT lock DNS or firewall-block; remove any block so
        # the VPN's own DNS works. Hosts-based blocking (porn/SafeSearch/apps) still applies.
        Remove-DohFirewallBlock
    } elseif (Test-NextDnsReachable -NextDnsIps $cfg.nextDnsIps) {
        if ($failsafeTripped) { Write-AgentLog "NextDNS reachable again; re-arming DNS lock."; $failsafeTripped = $false }
        if ($dohFwEnabled) { Set-DohFirewallBlock -NextDnsIps $cfg.nextDnsIps }
        $dnsChanged = Set-NextDnsLock -NextDnsIps $cfg.nextDnsIps
        # A VPN legitimately changes DNS, so only treat a DNS change as tampering when NO VPN is up.
        if ($dnsChanged -and -not $firstLoop -and -not $vpnActive) {
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
    }  # end: dnsMgmtEnabled

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
    if (($null -eq $desired) -or ($overKey -ne $lastOverKey) -or ($pornMtime -ne $lastPornMtime) -or ($vpnActive -ne $lastVpnActive)) {
        # Porn is hosts-blocked ONLY while a VPN is up (NextDNS is blind then). With no VPN we leave
        # porn to NextDNS, so the ATTEMPT is logged and visible to the witness instead of being
        # silently dropped by the hosts file before any query reaches NextDNS.
        $pornDomains = if ($pornEnabled -and $vpnActive) { Get-PornBlocklist -CachePath $pornCache } else { @() }
        # Tor DOWNLOAD domains are blocked ALWAYS (not VPN-gated like porn): the goal is to friction
        # the install, not to log a visit. Pairs with the Stop-TorBrowser process kill.
        $torDomains  = if ($torBlockEnabled) { Get-TorBlockDomains } else { @() }
        $appDomains  = Get-DesiredHostsEntries -Policies $cfg.appPolicies -OverLimitApps $overLimit
        $desired = @(@($appDomains) + @($pornDomains) + @($torDomains) | Select-Object -Unique)
        $safeRedirects = if ($safeSearchEnabled) { Get-SafeSearchRedirects } else { @{} }
        $lastOverKey = $overKey; $lastPornMtime = $pornMtime; $lastVpnActive = $vpnActive
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

    # --- Re-install / uninstall-password-change detection ---
    # install.ps1 writes a fresh install.stamp each run; a change means the installer was re-run
    # (which can re-register the agent or change the uninstall password). Alert the witness.
    $installNow = if (Test-Path $installStampFile) { (Get-Content $installStampFile -Raw).Trim() } else { "" }
    if ($installNow -and $installNow -ne $installSeen) {
        if ($installSeen) {   # not the very first install -> the installer was re-run
            $streak.Flagged = $true
            $k = "AgentReinstalled|$day"
            if (-not $tamperAlerted[$k]) {
                $al = Format-AlertEmail -Kind "AgentReinstalled" -Detail ""
                Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $al.Subject -Body $al.Body
                Write-AgentLog "Agent re-installed / uninstall password may have changed; witness alerted."
                $tamperAlerted[$k] = $true
            }
        }
        $installSeen = $installNow
        Set-Content -Path $installSeenFile -Value $installSeen -Encoding ASCII
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

    # --- Persist the tamper-alert dedup when it changed, so a later restart won't re-send today's
    # alerts. (Old keys self-expire: startup only loads keys ending in today's date.) ---
    $alertKeys = (($tamperAlerted.Keys | Sort-Object) -join "`n")
    if ($alertKeys -ne $lastAlertKeys) {
        Set-Content -Path $alertStateFile -Value @($tamperAlerted.Keys | Where-Object { $_ }) -Encoding ASCII
        $lastAlertKeys = $alertKeys
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
    $stale = $pastStartupGrace -and (Test-HeartbeatStale -LastBeat $lastBeat -Now (Get-Date) -ThresholdSeconds ([int]$cfg.heartbeatStaleSeconds))
    if ($stale) {
        if ($null -eq $staleSince) { $staleSince = Get-Date; Write-AgentLog "Monitor heartbeat stale; restarting monitor task." }
        # SELF-HEAL: (re)start the monitor task each loop while it's stale. The enforcer runs as
        # SYSTEM, so it can start the user-session monitor task. A monitor that was never started
        # (task 'Ready') or was killed comes back on its own within seconds.
        try { Start-ScheduledTask -TaskName "AccountabilityMonitor" -ErrorAction SilentlyContinue } catch { }
        # Only alert the witness if it STAYS stale well past the threshold despite restart attempts
        # (i.e. the monitor genuinely can't run) — so a self-healed blip never spams an email.
        if ((((Get-Date) - $staleSince).TotalSeconds -gt (2 * [int]$cfg.heartbeatStaleSeconds)) -and -not $tamperNotified) {
            $alert = Format-AlertEmail -Kind "Tamper" -Detail "monitor stale > $($cfg.heartbeatStaleSeconds)s and would not restart"
            Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $alert.Subject -Body $alert.Body
            Write-AgentLog "Dead-man alert sent (monitor failed to restart)."
            $tamperNotified = $true
        }
    } else {
        if ($staleSince) { Write-AgentLog "Monitor heartbeat healthy again." }
        $staleSince = $null; $tamperNotified = $false
    }

    # --- Instant adult-site alert: scan new browser-history lines each poll and email the witness
    # the MOMENT a porn URL appears, rather than waiting for the hourly report. Reads the same
    # history spool the reporter sends (RuntimeDir); dedupe by url|day means the reporter clearing
    # the file hourly is harmless and a repeat visit to the same URL won't re-spam. ---
    if ($instantPornAlertEnabled) {
        $histSpool = Join-Path $RuntimeDir "history-spool.txt"
        if (Test-Path $histSpool) {
            $pornList = Get-PornBlocklist -CachePath $pornCache
            $histLines = @(Get-Content $histSpool -ErrorAction SilentlyContinue)
            foreach ($hit in @(Select-PornHits -Lines $histLines -Domains $pornList)) {
                $url = ((($hit -split '\s*\|\s*', 2)[-1]).Trim())
                $k = "$url|$day"
                if (-not $pornAlerted[$k]) {
                    $streak.Flagged = $true
                    $al = Format-AlertEmail -Kind "PornAccess" -Detail $hit
                    Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $al.Subject -Body $al.Body
                    Write-AgentLog "Instant alert: adult site accessed ($url); witness notified."
                    $pornAlerted[$k] = $true
                }
            }
        }
    }

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
