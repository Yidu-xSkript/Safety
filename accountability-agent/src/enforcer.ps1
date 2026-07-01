param(
    [string]$SecretsDir = "C:\ProgramData\AccountabilityAgent",
    [string]$RuntimeDir = "C:\ProgramData\AccountabilityAgentRuntime"
)

Import-Module "$PSScriptRoot/Common.psm1"    -Force
Import-Module "$PSScriptRoot/Detection.psm1" -Force
Import-Module "$PSScriptRoot/Report.psm1"    -Force
Import-Module "$PSScriptRoot/Enforce.psm1"   -Force
Import-Module "$PSScriptRoot/Policy.psm1"    -Force

$cfg       = Get-AgentConfig -Path (Join-Path $SecretsDir "agent-config.json")
$heartbeat = Join-Path $RuntimeDir "monitor.heartbeat"
$lastReport = Get-Date
$tamperNotified = $false
$timeBoxAlerted = @{}   # "app|yyyyMMdd" -> $true, so each over-limit app alerts the witness once per day

Set-DohFirewallBlock -NextDnsIps $cfg.nextDnsIps

while ($true) {
  # One transient failure (SMTP hiccup, partial file read) must not kill the loop and
  # trigger a restart that re-fires alerts. Contain each iteration; log and continue.
  try {
    # --- VPN kill-switch (Option A: kill unapproved VPN, keep internet) ---
    $vpn = Get-VpnAdapterState
    if (Test-UnapprovedVpn -VpnAdapterPresent $vpn.Present `
            -ActiveRemoteIps (Get-ActiveRemoteIp) -ApprovedIps $cfg.approvedVpnIps) {
        Disable-VpnAdapter -Adapters $vpn.Adapters
        $alert = Format-AlertEmail -Kind "UnapprovedVPN" -Detail (($vpn.Adapters.Name) -join ", ")
        Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $alert.Subject -Body $alert.Body
        Write-AgentLog "Unapproved VPN disabled: $($alert.Body)"
    }

    # --- DNS re-lock (non-VPN adapters only) ---
    Set-NextDnsLock -NextDnsIps $cfg.nextDnsIps

    # --- App policy: hosts-block 'block' apps + over-limit time-box apps ---
    $overLimit = @()
    $day = Get-Date -Format "yyyyMMdd"
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
    Set-HostsBlock -Domains (Get-DesiredHostsEntries -Policies $cfg.appPolicies -OverLimitApps $overLimit)

    # --- Purge usage files from previous days ---
    Get-ChildItem -Path $RuntimeDir -Filter "usage-*.txt" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*-$day.txt" } | Remove-Item -Force -ErrorAction SilentlyContinue

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
  } catch {
    Write-AgentLog "Enforcer loop error: $($_.Exception.Message)"
  }

  Start-Sleep -Seconds ([int]$cfg.vpnPollSeconds)
}
