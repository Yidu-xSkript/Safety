#Requires -RunAsAdministrator
param(
    [string]$SrcDir     = "$PSScriptRoot/../src",
    [string]$SecretsDir = "C:\ProgramData\AccountabilityAgent",
    [string]$RuntimeDir = "C:\ProgramData\AccountabilityAgentRuntime",
    [Parameter(Mandatory)][string]$ConfigPath,  # path to the filled-in agent-config.json
    [string]$UninstallPassword                  # optional: witness sets this to gate uninstall.ps1
)

# --- Stop any PREVIOUS instances first. Re-registering the task with -Force orphans a running
# enforcer/monitor process (it keeps looping the old code), so without this a reinstall leaves
# multiple enforcers all rewriting the hosts file every few seconds — they lock each other out
# ("hosts is being used by another process") and each orphan re-sends witness alerts. Kill them,
# then let the file handles release before we re-register. ---
foreach ($t in 'AccountabilityEnforcer','AccountabilityMonitor') {
    Stop-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
}
foreach ($t in 'AccountabilitySinkhole') { Stop-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue }
Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='wscript.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'enforcer\.ps1|monitor\.ps1|sinkhole\.ps1|run-monitor-hidden\.vbs' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 1   # let the hosts-file handle from any killed enforcer release

# --- Secrets dir: admin-only. Holds the config with the SMTP app password. ---
New-Item -ItemType Directory -Path $SecretsDir -Force | Out-Null
Copy-Item $ConfigPath (Join-Path $SecretsDir "agent-config.json") -Force
icacls $SecretsDir /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" | Out-Null

# Fresh install stamp each run — the enforcer alerts the witness when this changes (i.e. someone
# re-ran the installer, which can re-register the agent or change the uninstall password).
[guid]::NewGuid().ToString() | Set-Content -Path (Join-Path $SecretsDir "install.stamp") -Encoding ASCII

# --- Optional uninstall password (witness-set). Prompted securely if not passed on the command
# --- line, so it never lands in PowerShell history. Stored as a salted hash in the admin-only dir.
if (-not $UninstallPassword) {
    $sec = Read-Host "Set an uninstall password (leave blank to skip)" -AsSecureString
    if ($sec.Length -gt 0) {
        $UninstallPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    }
}
if ($UninstallPassword) {
    Import-Module "$SrcDir/Common.psm1" -Force
    New-PasswordHash -Password $UninstallPassword | Set-Content -Path (Join-Path $SecretsDir "uninstall.hash") -Encoding ASCII
    Write-Host "Uninstall password set - uninstall.ps1 will require it."
}

# --- Runtime dir: the standard-user monitor must read/write here. NO secrets live here. ---
New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
icacls $RuntimeDir /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" "Users:(OI)(CI)M" | Out-Null
# Publish a secrets-free policies file the user-session monitor reads for time-box matching.
$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
@($cfg.appPolicies) | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $RuntimeDir "policies.json") -Encoding utf8

# --- Copy source into a Program Files location the standard user can't modify. ---
$installSrc = "C:\Program Files\AccountabilityAgent"
New-Item -ItemType Directory -Path $installSrc -Force | Out-Null
Copy-Item "$SrcDir/*" $installSrc -Recurse -Force

# Hidden launcher for the monitor: powershell -WindowStyle Hidden still flashes/leaves a closeable
# console. wscript.Run(..., 0, ...) launches it with a truly hidden window — no terminal appears.
$hiddenVbs = Join-Path $installSrc "run-monitor-hidden.vbs"
# window style 0 = hidden; wait = True so wscript stays alive for the monitor's lifetime, keeping
# the scheduled task in the 'Running' state (single-instance) instead of exiting immediately.
$vbsLine = 'CreateObject("Wscript.Shell").Run "powershell -NoProfile -ExecutionPolicy Bypass -File ""' `
    + "$installSrc\monitor.ps1" + '"" -RuntimeDir ""' + $RuntimeDir + '""", 0, True'
Set-Content -Path $hiddenVbs -Value $vbsLine -Encoding ASCII

icacls $installSrc /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" "Users:(OI)(CI)RX" | Out-Null

# Enforcer: runs as SYSTEM at boot, restarts if it exits.
$enfAction  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$installSrc\enforcer.ps1`" -SecretsDir `"$SecretsDir`" -RuntimeDir `"$RuntimeDir`""
$enfTrigger = New-ScheduledTaskTrigger -AtStartup
$enfSet     = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -DisallowStartIfOnBatteries:$false -StopIfGoingOnBatteries:$false
Register-ScheduledTask -TaskName "AccountabilityEnforcer" -Action $enfAction -Trigger $enfTrigger `
    -Settings $enfSet -User "SYSTEM" -RunLevel Highest -Force

# Monitor: runs in the interactive user's session at logon (RuntimeDir only — no secrets).
# Launched via the hidden VBScript wrapper so no console window ever appears.
$monAction  = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$hiddenVbs`""
$monTrigger = New-ScheduledTaskTrigger -AtLogOn
$monSet     = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -DisallowStartIfOnBatteries:$false -StopIfGoingOnBatteries:$false
Register-ScheduledTask -TaskName "AccountabilityMonitor" -Action $monAction -Trigger $monTrigger `
    -Settings $monSet -RunLevel Limited -Force

# Sinkhole: runs as SYSTEM at boot (binds loopback :443/:80 to log blocked-domain attempts, VPN-proof).
$sinkAction  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$installSrc\sinkhole.ps1`" -RuntimeDir `"$RuntimeDir`""
$sinkTrigger = New-ScheduledTaskTrigger -AtStartup
$sinkSet     = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -DisallowStartIfOnBatteries:$false -StopIfGoingOnBatteries:$false
Register-ScheduledTask -TaskName "AccountabilitySinkhole" -Action $sinkAction -Trigger $sinkTrigger `
    -Settings $sinkSet -User "SYSTEM" -RunLevel Highest -Force

# Start both now so protection is active immediately (don't wait for a reboot/logon).
Start-ScheduledTask -TaskName "AccountabilityEnforcer" -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName "AccountabilityMonitor"  -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName "AccountabilitySinkhole" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "Installed and started. Current state:"
Get-ScheduledTask -TaskName Accountability* | Select-Object TaskName, State | Format-Table -AutoSize
