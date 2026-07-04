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

$cfg       = Get-AgentConfig -Path (Join-Path $SecretsDir "agent-config.json")
$heartbeat = Join-Path $RuntimeDir "monitor.heartbeat"
$lastReport = Get-Date
$tamperNotified = $false
$timeBoxAlerted = @{}   # "app|yyyyMMdd" -> $true, so each over-limit app alerts the witness once per day
$tamperAlerted  = @{}   # "kind|yyyyMMdd" -> $true, so each tamper kind alerts the witness once per day
$firstLoop      = $true # suppress alerts on the initial DNS/hosts application (that's setup, not tampering)
$lastDesiredKey = ""    # last desired hosts-domain set, to tell agent-driven changes from external edits
$configPath = Join-Path $SecretsDir "agent-config.json"
$configHash = try { (Get-FileHash -Path $configPath -Algorithm SHA256 -ErrorAction Stop).Hash } catch { "" }

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

Set-DohFirewallBlock -NextDnsIps $cfg.nextDnsIps

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

    # --- DNS re-lock (non-VPN adapters only) + tamper alert ---
    $dnsChanged = Set-NextDnsLock -NextDnsIps $cfg.nextDnsIps
    if ($dnsChanged -and -not $firstLoop) {
        $streak.Flagged = $true
        $k = "DnsTamper|$day"
        if (-not $tamperAlerted[$k]) {
            $al = Format-AlertEmail -Kind "DnsTamper" -Detail ""
            Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $al.Subject -Body $al.Body
            Write-AgentLog "Tamper: DNS changed away from NextDNS; restored + alerted."
            $tamperAlerted[$k] = $true
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
    # Apply the hosts block. If the file had to be rewritten even though the DESIRED set of
    # domains did not change since last loop, that means the file was edited externally = tamper.
    $desired = Get-DesiredHostsEntries -Policies $cfg.appPolicies -OverLimitApps $overLimit
    $desiredKey = (@($desired) | Sort-Object) -join ','
    $hostsChanged = Set-HostsBlock -Domains $desired
    if ($hostsChanged -and -not $firstLoop -and $desiredKey -eq $lastDesiredKey) {
        $streak.Flagged = $true
        $k = "HostsTamper|$day"
        if (-not $tamperAlerted[$k]) {
            $al = Format-AlertEmail -Kind "HostsTamper" -Detail ""
            Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $al.Subject -Body $al.Body
            Write-AgentLog "Tamper: hosts block edited externally; restored + alerted."
            $tamperAlerted[$k] = $true
        }
    }
    $lastDesiredKey = $desiredKey

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
    if (Test-HeartbeatStale -LastBeat $lastBeat -Now (Get-Date) -ThresholdSeconds ([int]$cfg.heartbeatStaleSeconds)) {
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
