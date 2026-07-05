param(
    [string]$SecretsDir = "C:\ProgramData\AccountabilityAgent",
    [string]$RuntimeDir = "C:\ProgramData\AccountabilityAgentRuntime"
)

Import-Module "$PSScriptRoot/Common.psm1" -Force
Import-Module "$PSScriptRoot/Report.psm1" -Force

$cfg   = Get-AgentConfig -Path (Join-Path $SecretsDir "agent-config.json")
$spool     = Join-Path $RuntimeDir "spool.txt"
$histSpool = Join-Path $RuntimeDir "history-spool.txt"

$samples = @()
if (Test-Path $spool) { $samples = Get-Content -Path $spool }
$history = @()
if (Test-Path $histSpool) { $history = Get-Content -Path $histSpool }

$since = (Get-Date).AddMinutes((-1 * [int]$cfg.reportIntervalMinutes)).ToString("s")
$body  = Format-WitnessReport -Samples $samples -Since $since
if ($history.Count -gt 0) {
    $distinctUrls = @(@($history | ForEach-Object { (($_ -split '\s*\|\s*', 2)[-1]).Trim() } | Where-Object { $_ }) | Select-Object -Unique).Count
    $body += "`n`n--- Browser history ($distinctUrls distinct URLs, incl. search queries; non-incognito, VPN-proof) ---`n" + (Group-ActivitySamples -Lines $history)
}

Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail `
    -Subject "[Accountability] Activity report" -Body $body

# Rotate spools so the next report only contains new entries.
if (Test-Path $spool) { Clear-Content -Path $spool }
if (Test-Path $histSpool) { Clear-Content -Path $histSpool }
Write-AgentLog "Report sent to $($cfg.witnessEmail): $($samples.Count) titles, $($history.Count) urls"
