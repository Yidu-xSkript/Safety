param([string]$RuntimeDir = "C:\ProgramData\AccountabilityAgentRuntime")

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win32Fg {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
}
"@

Import-Module "$PSScriptRoot/Policy.psm1" -Force
Import-Module "$PSScriptRoot/BrowserHistory.psm1" -Force

# The monitor runs as the standard (non-admin) user, so it must NOT read the SMTP-bearing
# config. It reads only a secrets-free policies file the installer publishes to RuntimeDir.
$policies = @()
$polFile = Join-Path $RuntimeDir "policies.json"
if (Test-Path $polFile) { $policies = @((Get-Content $polFile -Raw | ConvertFrom-Json)) }

$spool       = Join-Path $RuntimeDir "spool.txt"
$histSpool   = Join-Path $RuntimeDir "history-spool.txt"
$histMarkFile = Join-Path $RuntimeDir "history.watermark"
$heartbeat   = Join-Path $RuntimeDir "monitor.heartbeat"

# Browser-history watermark (Chrome/WebKit time). Only visits newer than this get reported.
$histMark = if (Test-Path $histMarkFile) { [long](Get-Content $histMarkFile -Raw) } else { 0 }
$histCounter = 0

while ($true) {
    $h = [Win32Fg]::GetForegroundWindow()
    $sb = New-Object System.Text.StringBuilder 512
    [void][Win32Fg]::GetWindowText($h, $sb, $sb.Capacity)
    $title = $sb.ToString()
    if ($title) {
        $line = "{0} | {1}" -f (Get-Date -Format "s"), $title
        Add-Content -Path $spool -Value $line

        $app = Get-AppForTitle -Title $title -Policies $policies
        if ($app -and $app.policy -eq "time-box") {
            # One usage file per app per day, holding accrued seconds; loop samples every 15s.
            $day  = Get-Date -Format "yyyyMMdd"
            $file = Join-Path $RuntimeDir ("usage-{0}-{1}.txt" -f $app.name, $day)
            $secs = 0; if (Test-Path $file) { $secs = [int](Get-Content $file -Raw) }
            Set-Content -Path $file -Value ($secs + 15)
        }
    }
    # Every ~4 loops (~60s), pull new browser history (full URLs + search queries) into a spool the
    # reporter sends. Works during a VPN (reads the browser's own on-disk history). Incognito is not
    # recorded by the browser, so it is not captured. Only visits newer than the watermark are added.
    $histCounter++
    if ($histCounter -ge 4) {
        $histCounter = 0
        try {
            $hr = Get-BrowserHistory -SinceChromeTime $histMark
            if ($hr.Entries.Count -gt 0) {
                Add-Content -Path $histSpool -Value $hr.Entries
                $histMark = [long]$hr.MaxChromeTime
                Set-Content -Path $histMarkFile -Value $histMark
            }
        } catch { }
    }

    Set-Content -Path $heartbeat -Value (Get-Date -Format "o")
    Start-Sleep -Seconds 15
}
