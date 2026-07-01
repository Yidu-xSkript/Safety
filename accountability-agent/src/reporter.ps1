param(
    [string]$SecretsDir = "C:\ProgramData\AccountabilityAgent",
    [string]$RuntimeDir = "C:\ProgramData\AccountabilityAgentRuntime"
)

Import-Module "$PSScriptRoot/Common.psm1" -Force
Import-Module "$PSScriptRoot/Report.psm1" -Force

$cfg   = Get-AgentConfig -Path (Join-Path $SecretsDir "agent-config.json")
$spool = Join-Path $RuntimeDir "spool.txt"

$samples = @()
if (Test-Path $spool) { $samples = Get-Content -Path $spool }

$since = (Get-Date).AddMinutes((-1 * [int]$cfg.reportIntervalMinutes)).ToString("s")
$body  = Format-WitnessReport -Samples $samples -Since $since

Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail `
    -Subject "[Accountability] Activity report" -Body $body

# Rotate spool so the next report only contains new samples.
if (Test-Path $spool) { Clear-Content -Path $spool }
Write-AgentLog "Report sent to $($cfg.witnessEmail): $($samples.Count) samples"
