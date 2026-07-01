param([string]$DataDir = "C:\ProgramData\AccountabilityAgent")

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
Import-Module "$PSScriptRoot/Common.psm1" -Force
$cfg = Get-AgentConfig -Path (Join-Path $DataDir "agent-config.json")

$spool     = Join-Path $DataDir "spool.txt"
$heartbeat = Join-Path $DataDir "monitor.heartbeat"

while ($true) {
    $h = [Win32Fg]::GetForegroundWindow()
    $sb = New-Object System.Text.StringBuilder 512
    [void][Win32Fg]::GetWindowText($h, $sb, $sb.Capacity)
    $title = $sb.ToString()
    if ($title) {
        $line = "{0} | {1}" -f (Get-Date -Format "s"), $title
        Add-Content -Path $spool -Value $line

        $app = Get-AppForTitle -Title $title -Policies $cfg.appPolicies
        if ($app -and $app.policy -eq "time-box") {
            # One usage file per app per day, holding accrued seconds; loop samples every 15s.
            $day  = Get-Date -Format "yyyyMMdd"
            $file = Join-Path $DataDir ("usage-{0}-{1}.txt" -f $app.name, $day)
            $secs = 0; if (Test-Path $file) { $secs = [int](Get-Content $file -Raw) }
            Set-Content -Path $file -Value ($secs + 15)
        }
    }
    Set-Content -Path $heartbeat -Value (Get-Date -Format "o")
    Start-Sleep -Seconds 15
}
