#Requires -RunAsAdministrator
param(
    [string]$SecretsDir = "C:\ProgramData\AccountabilityAgent",
    [string]$RuntimeDir = "C:\ProgramData\AccountabilityAgentRuntime"
)

Unregister-ScheduledTask -TaskName "AccountabilityEnforcer" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "AccountabilityMonitor"  -Confirm:$false -ErrorAction SilentlyContinue
Get-NetFirewallRule -DisplayName "AA-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Write-Host "Removed tasks and firewall rules. DNS settings, $SecretsDir, and $RuntimeDir left in place; remove manually if desired."
