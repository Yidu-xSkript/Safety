#Requires -RunAsAdministrator
param(
    [string]$SecretsDir = "C:\ProgramData\AccountabilityAgent",
    [string]$RuntimeDir = "C:\ProgramData\AccountabilityAgentRuntime"
)

# --- Uninstall password gate (witness-held). If a hash was set at install, require it. ---
$hashFile = Join-Path $SecretsDir "uninstall.hash"
if (Test-Path $hashFile) {
    # Load helpers from the installed source (fallback to the repo src).
    $common = "C:\Program Files\AccountabilityAgent\Common.psm1"
    if (-not (Test-Path $common)) { $common = "$PSScriptRoot/../src/Common.psm1" }
    Import-Module $common -Force
    Import-Module (Join-Path (Split-Path $common) "Report.psm1") -Force -ErrorAction SilentlyContinue

    $stored = (Get-Content $hashFile -Raw).Trim()
    $sec = Read-Host "Enter the uninstall password" -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

    if (-not (Test-PasswordHash -Password $plain -Stored $stored)) {
        Write-Host "Wrong password. Uninstall aborted." -ForegroundColor Red
        # Notify the witness of the attempt (best-effort).
        try {
            $cfg = Get-AgentConfig -Path (Join-Path $SecretsDir "agent-config.json")
            $a = Format-AlertEmail -Kind "UninstallAttempt" -Detail ""
            Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $a.Subject -Body $a.Body
        } catch { }
        exit 1
    }
}

Unregister-ScheduledTask -TaskName "AccountabilityEnforcer" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "AccountabilityMonitor"  -Confirm:$false -ErrorAction SilentlyContinue
Get-NetFirewallRule -DisplayName "AA-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Write-Host "Removed tasks and firewall rules. DNS settings, $SecretsDir, and $RuntimeDir left in place; remove manually if desired."
