#Requires -RunAsAdministrator
param(
    [string]$SrcDir     = "$PSScriptRoot/../src",
    [string]$SecretsDir = "C:\ProgramData\AccountabilityAgent",
    [string]$RuntimeDir = "C:\ProgramData\AccountabilityAgentRuntime",
    [Parameter(Mandatory)][string]$ConfigPath   # path to the filled-in agent-config.json
)

# --- Secrets dir: admin-only. Holds the config with the SMTP app password. ---
New-Item -ItemType Directory -Path $SecretsDir -Force | Out-Null
Copy-Item $ConfigPath (Join-Path $SecretsDir "agent-config.json") -Force
icacls $SecretsDir /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" | Out-Null

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
icacls $installSrc /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" "Users:(OI)(CI)RX" | Out-Null

# Enforcer: runs as SYSTEM at boot, restarts if it exits.
$enfAction  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$installSrc\enforcer.ps1`" -SecretsDir `"$SecretsDir`" -RuntimeDir `"$RuntimeDir`""
$enfTrigger = New-ScheduledTaskTrigger -AtStartup
$enfSet     = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName "AccountabilityEnforcer" -Action $enfAction -Trigger $enfTrigger `
    -Settings $enfSet -User "SYSTEM" -RunLevel Highest -Force

# Monitor: runs in the interactive user's session at logon (RuntimeDir only — no secrets).
$monAction  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installSrc\monitor.ps1`" -RuntimeDir `"$RuntimeDir`""
$monTrigger = New-ScheduledTaskTrigger -AtLogOn
$monSet     = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName "AccountabilityMonitor" -Action $monAction -Trigger $monTrigger `
    -Settings $monSet -RunLevel Limited -Force

Write-Host "Installed. Start now with: Start-ScheduledTask -TaskName AccountabilityEnforcer; Start-ScheduledTask -TaskName AccountabilityMonitor"
