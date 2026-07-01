#Requires -RunAsAdministrator
param(
    [string]$SrcDir  = "$PSScriptRoot/../src",
    [string]$DataDir = "C:\ProgramData\AccountabilityAgent",
    [Parameter(Mandatory)][string]$ConfigPath   # path to the filled-in agent-config.json
)

New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
Copy-Item $ConfigPath (Join-Path $DataDir "agent-config.json") -Force

# Lock the data dir: SYSTEM + Administrators full control, remove inherited user access.
icacls $DataDir /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" | Out-Null

# Copy source into a Program Files location the standard user can't modify.
$installSrc = "C:\Program Files\AccountabilityAgent"
New-Item -ItemType Directory -Path $installSrc -Force | Out-Null
Copy-Item "$SrcDir/*" $installSrc -Recurse -Force
icacls $installSrc /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" "Users:(OI)(CI)RX" | Out-Null

# Enforcer: runs as SYSTEM at boot, restarts if it exits.
$enfAction  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$installSrc\enforcer.ps1`" -DataDir `"$DataDir`""
$enfTrigger = New-ScheduledTaskTrigger -AtStartup
$enfSet     = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName "AccountabilityEnforcer" -Action $enfAction -Trigger $enfTrigger `
    -Settings $enfSet -User "SYSTEM" -RunLevel Highest -Force

# Monitor: runs in the interactive user's session at logon.
$monAction  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installSrc\monitor.ps1`" -DataDir `"$DataDir`""
$monTrigger = New-ScheduledTaskTrigger -AtLogOn
$monSet     = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName "AccountabilityMonitor" -Action $monAction -Trigger $monTrigger `
    -Settings $monSet -RunLevel Limited -Force

Write-Host "Installed. Start now with: Start-ScheduledTask -TaskName AccountabilityEnforcer; Start-ScheduledTask -TaskName AccountabilityMonitor"
