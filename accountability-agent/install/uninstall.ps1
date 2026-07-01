#Requires -RunAsAdministrator
param([string]$DataDir = "C:\ProgramData\AccountabilityAgent")

Unregister-ScheduledTask -TaskName "AccountabilityEnforcer" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "AccountabilityMonitor"  -Confirm:$false -ErrorAction SilentlyContinue
Get-NetFirewallRule -DisplayName "AA-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Write-Host "Removed tasks and firewall rules. DNS settings and $DataDir left in place; remove manually if desired."
