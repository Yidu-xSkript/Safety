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

# The monitor runs as the standard (non-admin) user, so it must NOT read the SMTP-bearing
# config. It reads only a secrets-free policies file the installer publishes to RuntimeDir.
$policies = @()
$polFile = Join-Path $RuntimeDir "policies.json"
if (Test-Path $polFile) { $policies = @((Get-Content $polFile -Raw | ConvertFrom-Json)) }

$spool     = Join-Path $RuntimeDir "spool.txt"
$heartbeat = Join-Path $RuntimeDir "monitor.heartbeat"

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
    Set-Content -Path $heartbeat -Value (Get-Date -Format "o")
    Start-Sleep -Seconds 15
}
