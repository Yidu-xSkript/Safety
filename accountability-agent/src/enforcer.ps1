param([string]$DataDir = "C:\ProgramData\AccountabilityAgent")

Import-Module "$PSScriptRoot/Common.psm1"    -Force
Import-Module "$PSScriptRoot/Detection.psm1" -Force
Import-Module "$PSScriptRoot/Report.psm1"    -Force
Import-Module "$PSScriptRoot/Enforce.psm1"   -Force
Import-Module "$PSScriptRoot/Policy.psm1"    -Force

$cfg       = Get-AgentConfig -Path (Join-Path $DataDir "agent-config.json")
$heartbeat = Join-Path $DataDir "monitor.heartbeat"
$lastReport = Get-Date
$tamperNotified = $false

Set-DohFirewallBlock -NextDnsIps $cfg.nextDnsIps

while ($true) {
    # --- VPN kill-switch (Option A: kill unapproved VPN, keep internet) ---
    $vpn = Get-VpnAdapterState
    if (Test-UnapprovedVpn -VpnAdapterPresent $vpn.Present `
            -ActiveRemoteIps (Get-ActiveRemoteIp) -ApprovedIps $cfg.approvedVpnIps) {
        Disable-VpnAdapter -Adapters $vpn.Adapters
        $alert = Format-AlertEmail -Kind "UnapprovedVPN" -Detail (($vpn.Adapters.Name) -join ", ")
        Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $alert.Subject -Body $alert.Body
        Write-AgentLog "Unapproved VPN disabled: $($alert.Body)"
    }

    # --- DNS re-lock ---
    Set-NextDnsLock -NextDnsIps $cfg.nextDnsIps

    # --- App policy: hosts-block 'block' apps + over-limit time-box apps ---
    $overLimit = @()
    $day = Get-Date -Format "yyyyMMdd"
    foreach ($p in $cfg.appPolicies) {
        if ($p.policy -eq "time-box") {
            $file = Join-Path $DataDir ("usage-{0}-{1}.txt" -f $p.name, $day)
            $secs = 0; if (Test-Path $file) { $secs = [int](Get-Content $file -Raw) }
            if (Test-OverDailyLimit -AccruedMinutes ([int]($secs/60)) -LimitMinutes $p.dailyLimitMinutes) {
                $overLimit += $p.name
            }
        }
    }
    Set-HostsBlock -Domains (Get-DesiredHostsEntries -Policies $cfg.appPolicies -OverLimitApps $overLimit)

    # --- Dead-man's switch: monitor heartbeat must be fresh ---
    $lastBeat = $null
    if (Test-Path $heartbeat) { $lastBeat = [datetime](Get-Content $heartbeat -Raw) }
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
        & "$PSScriptRoot/reporter.ps1" -DataDir $DataDir
        $lastReport = Get-Date
    }

    Start-Sleep -Seconds ([int]$cfg.vpnPollSeconds)
}
