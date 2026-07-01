# Accountability Blocker — Windows Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a tamper-resistant Windows accountability agent that reports active-window activity to a witness by email, kills unapproved VPNs, enforces NextDNS, and alerts the witness on tamper or silence — for a mutual two-person setup.

**Architecture:** Two cooperating scheduled tasks. An **enforcer** runs as SYSTEM (a standard user can't stop it): it kills unapproved VPN adapters, re-applies NextDNS + DoH-block firewall rules, runs the dead-man's switch, and triggers reports. A **monitor** runs in the user's logon session: it samples the active-window title to a spool file and writes a heartbeat. If the user kills the monitor, its heartbeat goes stale and the enforcer emails the witness (dead-man's switch). URL history is covered by NextDNS (incognito-proof), not by the agent.

**Tech Stack:** Windows PowerShell 5.1 (in-box), Windows Task Scheduler, .NET `System.Net.Mail` for email, Win32 `user32.dll` for the foreground window, `NetSecurity`/`NetTCPIP`/`NetAdapter` PowerShell modules, Pester 3.4 (in-box) for unit tests.

---

## Pure-vs-side-effect rule (read first)

Decision logic (VPN allow/deny, staleness, report text) lives in **pure functions** in `.psm1` modules and is unit-tested with Pester. OS actions (disable adapter, send email, set DNS) are thin wrappers in the `.ps1` scripts that call those pure functions. Test the decisions, not the OS.

## File structure

```
accountability-agent/
  config/
    agent-config.example.json     # template; real config written by installer to ProgramData
  src/
    Common.psm1                   # config load, logging, Send-WitnessEmail
    Detection.psm1                # pure: Test-UnapprovedVpn, Test-HeartbeatStale; wrappers: Get-VpnAdapterState, Get-ActiveRemoteIp
    Report.psm1                   # pure: Format-WitnessReport, Format-AlertEmail
    Enforce.psm1                  # wrappers: Set-NextDnsLock, Set-DohFirewallBlock, Disable-VpnAdapter
    monitor.ps1                   # user-session loop: window title -> spool + heartbeat
    enforcer.ps1                  # SYSTEM loop: VPN kill, DNS lock, dead-man, scheduled report
    reporter.ps1                  # read spool -> email witness
  install/
    install.ps1                   # admin: ProgramData ACLs, scheduled tasks, DNS, firewall
    uninstall.ps1                 # admin: remove tasks, restore DNS/firewall
  tests/
    Detection.Tests.ps1
    Report.Tests.ps1
  README.md                       # operator runbook (both users)
```

Runtime data (config, spool, heartbeat, logs) lives in `C:\ProgramData\AccountabilityAgent\`, ACL'd to SYSTEM + Administrators only (a standard user cannot read SMTP creds or edit config).

---

## Task 0: Manual setup — NextDNS + phones (no code)

This task is a checklist the two users do by hand. It delivers the blocking + incognito-proof history layer before any code runs.

**Files:**
- Create: `accountability-agent/README.md` (record the steps + who holds what)

- [ ] **Step 1: Each user creates the OTHER user's NextDNS account**
  - You create a NextDNS config for your friend; your friend creates one for you. The *witness owns the login*; the protected user never gets the password.
  - In each config, enable: **Parental Control → Block category "Porn"**, plus the **Security → "Block Proxies & VPNs"** blocklist, and **Enforce SafeSearch**.

- [ ] **Step 2: Apply NextDNS on each Windows PC**
  - Use the NextDNS Windows setup (DoH). Record the config's DoH template and its two plain-DNS IPs (shown in the NextDNS "Setup" tab) — these go into `agent-config.json` so the enforcer can re-lock them.

- [ ] **Step 3: Lock phones**
  - iPhone (you): install the NextDNS **configuration profile**; enable **Screen Time → Content Restrictions**; set the Screen Time passcode to one **your friend** enters and keeps.
  - Android (friend): set **Private DNS** to the NextDNS hostname; turn on **Digital Wellbeing** limits; you keep any lock secret.

- [ ] **Step 4: Record custody in README.md**
  - Table: for each user — witness name, witness email, who holds Windows admin password, who holds phone passcode, NextDNS config IDs. Commit.

Expected: browsing porn on any device (including incognito) is now blocked and logged in NextDNS, visible to the witness. No verification command — confirm by visiting a known-blocked test domain and seeing it blocked + logged.

---

## Task 1: Project skeleton + git

**Files:**
- Create: `accountability-agent/config/agent-config.example.json`
- Create: `accountability-agent/README.md` (if not already from Task 0)
- Create: `.gitignore`

- [ ] **Step 1: Initialize git at the project root**

Run:
```bash
git init
git add -A
git commit -m "chore: existing research + spec"
```
Expected: repo created, first commit succeeds.

- [ ] **Step 2: Write `.gitignore`**

```
# runtime secrets / data never belong in git
*-config.json
!*-config.example.json
*.log
spool/
```

- [ ] **Step 3: Write `config/agent-config.example.json`**

```json
{
  "role": "protected-user-A",
  "witnessEmail": "friend@example.com",
  "supporterEmail": null,
  "approvedVpnIps": ["181.214.9.54"],
  "nextDnsIps": ["45.90.28.0", "45.90.30.0"],
  "reportIntervalMinutes": 60,
  "heartbeatStaleSeconds": 180,
  "vpnPollSeconds": 5,
  "appPolicies": [
    { "name": "Instagram", "policy": "block",       "domains": ["instagram.com", "cdninstagram.com"], "titleMatch": "Instagram", "dailyLimitMinutes": null },
    { "name": "TikTok",    "policy": "time-box",     "domains": ["tiktok.com"],                        "titleMatch": "TikTok",    "dailyLimitMinutes": 20 },
    { "name": "Reddit",    "policy": "report-only",  "domains": ["reddit.com"],                        "titleMatch": "Reddit",    "dailyLimitMinutes": null }
  ],
  "smtp": {
    "host": "smtp.gmail.com",
    "port": 587,
    "useSsl": true,
    "username": "sender@example.com",
    "appPassword": "REPLACE_WITH_APP_PASSWORD",
    "fromAddress": "sender@example.com"
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add accountability-agent/config/agent-config.example.json .gitignore
git commit -m "feat: project skeleton and config template"
```

---

## Task 2: Common.psm1 — config load + logging

**Files:**
- Create: `accountability-agent/src/Common.psm1`
- Test: `accountability-agent/tests/Detection.Tests.ps1` (shared test file; config test lives here)

- [ ] **Step 1: Write the failing test**

Add to `tests/Detection.Tests.ps1`:
```powershell
Import-Module "$PSScriptRoot/../src/Common.psm1" -Force

Describe "Get-AgentConfig" {
    It "parses required fields from a config file" {
        $tmp = Join-Path $env:TEMP "cfg-test.json"
        '{ "witnessEmail": "w@x.com", "approvedVpnIps": ["1.2.3.4"], "reportIntervalMinutes": 60 }' |
            Set-Content -Path $tmp -Encoding utf8
        $cfg = Get-AgentConfig -Path $tmp
        $cfg.witnessEmail | Should Be "w@x.com"
        $cfg.approvedVpnIps[0] | Should Be "1.2.3.4"
        Remove-Item $tmp
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Invoke-Pester ./accountability-agent/tests/Detection.Tests.ps1`
Expected: FAIL — `Get-AgentConfig` not recognized.

- [ ] **Step 3: Write minimal implementation**

`src/Common.psm1`:
```powershell
function Get-AgentConfig {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-Content -Path $Path -Raw | ConvertFrom-Json)
}

function Write-AgentLog {
    param([string]$Message, [string]$LogDir = "C:\ProgramData\AccountabilityAgent")
    $line = "{0} {1}" -f (Get-Date -Format "s"), $Message
    Add-Content -Path (Join-Path $LogDir "agent.log") -Value $line
}

function Send-WitnessEmail {
    param(
        [Parameter(Mandatory)]$Smtp,
        [Parameter(Mandatory)][string]$To,
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Body
    )
    $msg = New-Object System.Net.Mail.MailMessage($Smtp.fromAddress, $To, $Subject, $Body)
    $client = New-Object System.Net.Mail.SmtpClient($Smtp.host, [int]$Smtp.port)
    $client.EnableSsl = [bool]$Smtp.useSsl
    $client.Credentials = New-Object System.Net.NetworkCredential($Smtp.username, $Smtp.appPassword)
    $client.Send($msg)
    $msg.Dispose(); $client.Dispose()
}

Export-ModuleMember -Function Get-AgentConfig, Write-AgentLog, Send-WitnessEmail
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Invoke-Pester ./accountability-agent/tests/Detection.Tests.ps1`
Expected: PASS (the `Get-AgentConfig` test; other Describes added later).

- [ ] **Step 5: Commit**

```bash
git add accountability-agent/src/Common.psm1 accountability-agent/tests/Detection.Tests.ps1
git commit -m "feat: config loader, logger, email sender"
```

---

## Task 3: Detection.psm1 — VPN allow/deny decision (pure)

This is the security-critical decision. It is pure and fully tested.

**Files:**
- Create: `accountability-agent/src/Detection.psm1`
- Test: `accountability-agent/tests/Detection.Tests.ps1`

- [ ] **Step 1: Write the failing tests**

Add to `tests/Detection.Tests.ps1`:
```powershell
Import-Module "$PSScriptRoot/../src/Detection.psm1" -Force

Describe "Test-UnapprovedVpn" {
    $approved = @("181.214.9.54")

    It "returns false when no VPN adapter is present" {
        Test-UnapprovedVpn -VpnAdapterPresent $false -ActiveRemoteIps @("8.8.8.8") -ApprovedIps $approved |
            Should Be $false
    }
    It "returns false when the VPN connects to an approved endpoint" {
        Test-UnapprovedVpn -VpnAdapterPresent $true -ActiveRemoteIps @("181.214.9.54","1.1.1.1") -ApprovedIps $approved |
            Should Be $false
    }
    It "returns true when a VPN is up and no approved endpoint is in use" {
        Test-UnapprovedVpn -VpnAdapterPresent $true -ActiveRemoteIps @("203.0.113.9") -ApprovedIps $approved |
            Should Be $true
    }
    It "returns true when a VPN is up and there are no active connections" {
        Test-UnapprovedVpn -VpnAdapterPresent $true -ActiveRemoteIps @() -ApprovedIps $approved |
            Should Be $true
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Invoke-Pester ./accountability-agent/tests/Detection.Tests.ps1 -TestName "Test-UnapprovedVpn"`
Expected: FAIL — function not defined.

- [ ] **Step 3: Write minimal implementation**

`src/Detection.psm1`:
```powershell
function Test-UnapprovedVpn {
    # Pure decision: a VPN adapter is up AND none of the currently-active
    # remote endpoints is on the approved list => unapproved, must be killed.
    param(
        [Parameter(Mandatory)][bool]$VpnAdapterPresent,
        [string[]]$ActiveRemoteIps = @(),
        [string[]]$ApprovedIps = @()
    )
    if (-not $VpnAdapterPresent) { return $false }
    foreach ($ip in $ActiveRemoteIps) {
        if ($ApprovedIps -contains $ip) { return $false }
    }
    return $true
}

Export-ModuleMember -Function Test-UnapprovedVpn
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Invoke-Pester ./accountability-agent/tests/Detection.Tests.ps1 -TestName "Test-UnapprovedVpn"`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add accountability-agent/src/Detection.psm1 accountability-agent/tests/Detection.Tests.ps1
git commit -m "feat: pure VPN allow/deny decision with tests"
```

---

## Task 4: Detection.psm1 — OS wrappers for VPN state

Thin wrappers over the OS. Heuristic; not unit-tested (side-effecting). `// ponytail: heuristic VPN detection by adapter description — extend the regex as new clients show up.`

**Files:**
- Modify: `accountability-agent/src/Detection.psm1`

- [ ] **Step 1: Add wrappers**

Append to `src/Detection.psm1` (before `Export-ModuleMember`, then update the export line):
```powershell
function Get-VpnAdapterState {
    # Returns @{ Present = <bool>; Adapters = <adapter objects> }
    $pattern = 'VPN|TAP|TUN|WireGuard|Wintun|OpenVPN|WAN Miniport \((IKEv2|L2TP|PPTP|SSTP|Network Monitor)\)'
    $vpn = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -match $pattern }
    return @{ Present = [bool]$vpn; Adapters = $vpn }
}

function Get-ActiveRemoteIp {
    # Distinct remote IPv4 addresses of currently-established connections.
    return (Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty RemoteAddress -Unique)
}
```
Update export:
```powershell
Export-ModuleMember -Function Test-UnapprovedVpn, Get-VpnAdapterState, Get-ActiveRemoteIp
```

- [ ] **Step 2: Smoke-test the wrappers manually**

Run: `Import-Module ./accountability-agent/src/Detection.psm1 -Force; (Get-VpnAdapterState).Present; Get-ActiveRemoteIp`
Expected: prints `False` (assuming no VPN up) and a list of remote IPs. No crash.

- [ ] **Step 3: Commit**

```bash
git add accountability-agent/src/Detection.psm1
git commit -m "feat: VPN adapter + active-connection OS wrappers"
```

---

## Task 5: Detection.psm1 — heartbeat staleness (pure) + dead-man's switch input

**Files:**
- Modify: `accountability-agent/src/Detection.psm1`
- Test: `accountability-agent/tests/Detection.Tests.ps1`

- [ ] **Step 1: Write the failing tests**

Add to `tests/Detection.Tests.ps1`:
```powershell
Describe "Test-HeartbeatStale" {
    It "is stale when the last beat is older than the threshold" {
        $old = (Get-Date).AddSeconds(-600)
        Test-HeartbeatStale -LastBeat $old -Now (Get-Date) -ThresholdSeconds 180 | Should Be $true
    }
    It "is fresh when the last beat is within the threshold" {
        $recent = (Get-Date).AddSeconds(-30)
        Test-HeartbeatStale -LastBeat $recent -Now (Get-Date) -ThresholdSeconds 180 | Should Be $false
    }
    It "is stale when there is no last beat" {
        Test-HeartbeatStale -LastBeat $null -Now (Get-Date) -ThresholdSeconds 180 | Should Be $true
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Invoke-Pester ./accountability-agent/tests/Detection.Tests.ps1 -TestName "Test-HeartbeatStale"`
Expected: FAIL — function not defined.

- [ ] **Step 3: Write minimal implementation**

Append to `src/Detection.psm1` and add to the export line:
```powershell
function Test-HeartbeatStale {
    param(
        [datetime]$LastBeat,
        [Parameter(Mandatory)][datetime]$Now,
        [Parameter(Mandatory)][int]$ThresholdSeconds
    )
    if ($null -eq $LastBeat) { return $true }
    return (($Now - $LastBeat).TotalSeconds -gt $ThresholdSeconds)
}
```
```powershell
Export-ModuleMember -Function Test-UnapprovedVpn, Get-VpnAdapterState, Get-ActiveRemoteIp, Test-HeartbeatStale
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Invoke-Pester ./accountability-agent/tests/Detection.Tests.ps1 -TestName "Test-HeartbeatStale"`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add accountability-agent/src/Detection.psm1 accountability-agent/tests/Detection.Tests.ps1
git commit -m "feat: pure heartbeat-staleness check with tests"
```

---

## Task 6: Report.psm1 — witness report + alert formatting (pure)

**Files:**
- Create: `accountability-agent/src/Report.psm1`
- Test: `accountability-agent/tests/Report.Tests.ps1`

- [ ] **Step 1: Write the failing tests**

`tests/Report.Tests.ps1`:
```powershell
Import-Module "$PSScriptRoot/../src/Report.psm1" -Force

Describe "Format-WitnessReport" {
    It "includes each window-title sample line" {
        $samples = @(
            "2026-07-01T10:00:00 | Google Chrome - news",
            "2026-07-01T10:05:00 | Notepad"
        )
        $body = Format-WitnessReport -Samples $samples -Since "2026-07-01T09:00:00"
        $body | Should Match "news"
        $body | Should Match "Notepad"
        $body | Should Match "2 activity samples"
    }
    It "says so when there is no activity" {
        (Format-WitnessReport -Samples @() -Since "x") | Should Match "No activity"
    }
}

Describe "Format-AlertEmail" {
    It "labels an unapproved-VPN alert" {
        (Format-AlertEmail -Kind "UnapprovedVPN" -Detail "203.0.113.9").Subject |
            Should Match "Unapproved VPN"
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Invoke-Pester ./accountability-agent/tests/Report.Tests.ps1`
Expected: FAIL — functions not defined.

- [ ] **Step 3: Write minimal implementation**

`src/Report.psm1`:
```powershell
function Format-WitnessReport {
    param([string[]]$Samples = @(), [string]$Since)
    $header = "Accountability report (since $Since) — $($Samples.Count) activity samples`n`n"
    if ($Samples.Count -eq 0) { return $header + "No activity captured in this window." }
    return $header + ($Samples -join "`n")
}

function Format-AlertEmail {
    param([Parameter(Mandatory)][string]$Kind, [string]$Detail)
    switch ($Kind) {
        "UnapprovedVPN" { return @{ Subject = "[Accountability] Unapproved VPN killed"; Body = "An unapproved VPN was detected and disabled. Endpoint(s): $Detail" } }
        "Tamper"        { return @{ Subject = "[Accountability] Tamper / silence detected"; Body = "The monitor stopped reporting. Detail: $Detail" } }
        default         { return @{ Subject = "[Accountability] Alert: $Kind"; Body = $Detail } }
    }
}

Export-ModuleMember -Function Format-WitnessReport, Format-AlertEmail
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Invoke-Pester ./accountability-agent/tests/Report.Tests.ps1`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add accountability-agent/src/Report.psm1 accountability-agent/tests/Report.Tests.ps1
git commit -m "feat: pure report and alert formatting with tests"
```

---

## Task 7: monitor.ps1 — user-session window sampler + heartbeat

Runs in the logon session (it needs the interactive desktop to read the foreground window). If the user kills it, the heartbeat goes stale and the enforcer alerts the witness.

**Files:**
- Create: `accountability-agent/src/monitor.ps1`

- [ ] **Step 1: Write the script**

```powershell
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
    }
    Set-Content -Path $heartbeat -Value (Get-Date -Format "o")
    Start-Sleep -Seconds 15
}
```

- [ ] **Step 2: Smoke-test in the foreground**

Run: `./accountability-agent/src/monitor.ps1 -DataDir $env:TEMP` for ~20s, switch windows, Ctrl-C.
Check: `Get-Content $env:TEMP\spool.txt` shows window titles; `$env:TEMP\monitor.heartbeat` exists with a recent timestamp.
Expected: titles captured, heartbeat fresh.

- [ ] **Step 3: Commit**

```bash
git add accountability-agent/src/monitor.ps1
git commit -m "feat: user-session window sampler with heartbeat"
```

---

## Task 8: reporter.ps1 — drain spool, email witness

**Files:**
- Create: `accountability-agent/src/reporter.ps1`

- [ ] **Step 1: Write the script**

```powershell
param([string]$DataDir = "C:\ProgramData\AccountabilityAgent")

Import-Module "$PSScriptRoot/Common.psm1" -Force
Import-Module "$PSScriptRoot/Report.psm1" -Force

$cfg   = Get-AgentConfig -Path (Join-Path $DataDir "agent-config.json")
$spool = Join-Path $DataDir "spool.txt"

$samples = @()
if (Test-Path $spool) { $samples = Get-Content -Path $spool }

$since = (Get-Date).AddMinutes(-1 * [int]$cfg.reportIntervalMinutes).ToString("s")
$body  = Format-WitnessReport -Samples $samples -Since $since

Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail `
    -Subject "[Accountability] Activity report" -Body $body

# Rotate spool so the next report only contains new samples.
if (Test-Path $spool) { Clear-Content -Path $spool }
Write-AgentLog "Report sent to $($cfg.witnessEmail): $($samples.Count) samples"
```

- [ ] **Step 2: Smoke-test with a throwaway config**

Copy `agent-config.example.json` to `$env:TEMP\agent-config.json`, fill in real SMTP + your own address as `witnessEmail`, seed `$env:TEMP\spool.txt` with a line, then:
Run: `./accountability-agent/src/reporter.ps1 -DataDir $env:TEMP`
Expected: you receive the email; spool is cleared; log line written.

- [ ] **Step 3: Commit**

```bash
git add accountability-agent/src/reporter.ps1
git commit -m "feat: reporter drains spool and emails witness"
```

---

## Task 9: Enforce.psm1 — DNS lock, DoH-block firewall, adapter disable

**Files:**
- Create: `accountability-agent/src/Enforce.psm1`

- [ ] **Step 1: Write the wrappers**

```powershell
function Set-NextDnsLock {
    # Re-apply NextDNS on every active interface if it has drifted.
    param([Parameter(Mandatory)][string[]]$NextDnsIps)
    Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | ForEach-Object {
        $cur = (Get-DnsClientServerAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
        if (($cur -join ',') -ne ($NextDnsIps -join ',')) {
            Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses $NextDnsIps -ErrorAction SilentlyContinue
        }
    }
}

function Set-DohFirewallBlock {
    # Block outbound plain DNS (port 53) to anything except NextDNS, and block
    # known DoH resolver IPs so a browser can't switch DNS. Idempotent by rule name.
    param([Parameter(Mandatory)][string[]]$NextDnsIps)
    $dohIps = @("1.1.1.1","1.0.0.1","8.8.8.8","8.8.4.4","9.9.9.9","149.112.112.112")
    if (-not (Get-NetFirewallRule -DisplayName "AA-Block-DoH" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "AA-Block-DoH" -Direction Outbound -Action Block `
            -RemoteAddress $dohIps -Protocol TCP -RemotePort 443 | Out-Null
    }
    if (-not (Get-NetFirewallRule -DisplayName "AA-Block-Plain-DNS" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "AA-Block-Plain-DNS" -Direction Outbound -Action Block `
            -Protocol UDP -RemotePort 53 | Out-Null
        New-NetFirewallRule -DisplayName "AA-Allow-NextDNS" -Direction Outbound -Action Allow `
            -RemoteAddress $NextDnsIps -Protocol UDP -RemotePort 53 | Out-Null
    }
}

function Disable-VpnAdapter {
    param([Parameter(Mandatory)]$Adapters)
    foreach ($a in $Adapters) {
        Disable-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Set-NextDnsLock, Set-DohFirewallBlock, Disable-VpnAdapter
```

- [ ] **Step 2: Smoke-test firewall rule creation (admin shell)**

Run: `Import-Module ./accountability-agent/src/Enforce.psm1 -Force; Set-DohFirewallBlock -NextDnsIps @("45.90.28.0","45.90.30.0"); Get-NetFirewallRule -DisplayName "AA-*"`
Expected: three `AA-*` rules exist. (Clean up after: `Get-NetFirewallRule -DisplayName "AA-*" | Remove-NetFirewallRule`.)

- [ ] **Step 3: Commit**

```bash
git add accountability-agent/src/Enforce.psm1
git commit -m "feat: DNS lock, DoH-block firewall, adapter disable wrappers"
```

---

## Task 10: enforcer.ps1 — SYSTEM main loop

Ties it together: fast VPN poll + kill, periodic DNS re-lock, dead-man's switch, scheduled report trigger.

**Files:**
- Create: `accountability-agent/src/enforcer.ps1`

- [ ] **Step 1: Write the script**

```powershell
param([string]$DataDir = "C:\ProgramData\AccountabilityAgent")

Import-Module "$PSScriptRoot/Common.psm1"    -Force
Import-Module "$PSScriptRoot/Detection.psm1" -Force
Import-Module "$PSScriptRoot/Report.psm1"    -Force
Import-Module "$PSScriptRoot/Enforce.psm1"   -Force

$cfg       = Get-AgentConfig -Path (Join-Path $DataDir "agent-config.json")
$heartbeat = Join-Path $DataDir "monitor.heartbeat"
$lastReport = Get-Date
$tamperNotified = $false

Set-DohFirewallBlock -NextDnsIps $cfg.nextDnsIps

while ($true) {
    # --- VPN kill-switch (Option A: kill unapproved VPN, keep internet) ---
    $vpn = Get-VpnAdapterState
    if (Test-UnapprovedVpn -VpnAdapterPresent $vpn.Present `
            -ActiveRemoteIps (Get-ActiveRemoteIp) -ApprovedIps $cfg.approvedVpnIps) {
        Disable-VpnAdapter -Adapters $vpn.Adapters
        $alert = Format-AlertEmail -Kind "UnapprovedVPN" -Detail (($vpn.Adapters.Name) -join ", ")
        Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $alert.Subject -Body $alert.Body
        Write-AgentLog "Unapproved VPN disabled: $($alert.Body)"
    }

    # --- DNS re-lock ---
    Set-NextDnsLock -NextDnsIps $cfg.nextDnsIps

    # --- Dead-man's switch: monitor heartbeat must be fresh ---
    $lastBeat = $null
    if (Test-Path $heartbeat) { $lastBeat = [datetime](Get-Content $heartbeat -Raw) }
    if (Test-HeartbeatStale -LastBeat $lastBeat -Now (Get-Date) -ThresholdSeconds ([int]$cfg.heartbeatStaleSeconds)) {
        if (-not $tamperNotified) {
            $alert = Format-AlertEmail -Kind "Tamper" -Detail "monitor heartbeat stale > $($cfg.heartbeatStaleSeconds)s"
            Send-WitnessEmail -Smtp $cfg.smtp -To $cfg.witnessEmail -Subject $alert.Subject -Body $alert.Body
            Write-AgentLog "Dead-man alert sent."
            $tamperNotified = $true
        }
    } else { $tamperNotified = $false }

    # --- Scheduled report ---
    if (((Get-Date) - $lastReport).TotalMinutes -ge [int]$cfg.reportIntervalMinutes) {
        & "$PSScriptRoot/reporter.ps1" -DataDir $DataDir
        $lastReport = Get-Date
    }

    Start-Sleep -Seconds ([int]$cfg.vpnPollSeconds)
}
```

- [ ] **Step 2: Smoke-test the loop body once (admin shell, short poll)**

Temporarily set `reportIntervalMinutes` high and run for ~30s against `$env:TEMP` data dir with the monitor also running. Confirm: no crash, DNS rule stays applied, log shows loop activity. Ctrl-C.
Expected: stable loop; a manually-started unapproved VPN gets disabled within `vpnPollSeconds`.

- [ ] **Step 3: Commit**

```bash
git add accountability-agent/src/enforcer.ps1
git commit -m "feat: SYSTEM enforcer loop (VPN kill, DNS lock, dead-man, reports)"
```

---

## Task 11: install.ps1 — ACLs + scheduled tasks + enforcement

Requires an elevated (admin) shell. This is what makes it tamper-proof: enforcer runs as SYSTEM, data dir is locked to SYSTEM/Admins, the protected user is a standard account.

**Files:**
- Create: `accountability-agent/install/install.ps1`
- Create: `accountability-agent/install/uninstall.ps1`

- [ ] **Step 1: Write install.ps1**

```powershell
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
```

- [ ] **Step 2: Write uninstall.ps1**

```powershell
#Requires -RunAsAdministrator
param([string]$DataDir = "C:\ProgramData\AccountabilityAgent")

Unregister-ScheduledTask -TaskName "AccountabilityEnforcer" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "AccountabilityMonitor"  -Confirm:$false -ErrorAction SilentlyContinue
Get-NetFirewallRule -DisplayName "AA-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Write-Host "Removed tasks and firewall rules. DNS settings and $DataDir left in place; remove manually if desired."
```

- [ ] **Step 3: Install and verify (admin shell)**

Run:
```powershell
Copy-Item ./accountability-agent/config/agent-config.example.json $env:TEMP\real-config.json
# edit $env:TEMP\real-config.json with real SMTP, witness email, approved VPN IP, NextDNS IPs
./accountability-agent/install/install.ps1 -ConfigPath $env:TEMP\real-config.json
Start-ScheduledTask -TaskName AccountabilityEnforcer
Start-ScheduledTask -TaskName AccountabilityMonitor
Get-ScheduledTask -TaskName Accountability*
```
Expected: both tasks `Ready`/`Running`; enforcer principal is `SYSTEM`.

- [ ] **Step 4: Commit**

```bash
git add accountability-agent/install/install.ps1 accountability-agent/install/uninstall.ps1
git commit -m "feat: tamper-proof installer and uninstaller"
```

---

## Task 12: End-to-end verification (manual runbook)

**Files:**
- Modify: `accountability-agent/README.md` (append this checklist)

- [ ] **Step 1: Run the acceptance checklist as a standard (non-admin) user**

Log in as the standard user account and verify each:
- [ ] Porn test domain is blocked in a normal window **and** in incognito (NextDNS layer).
- [ ] The blocked attempt appears in the witness's NextDNS dashboard.
- [ ] Connect an **unapproved** VPN → it is disabled within `vpnPollSeconds`; witness gets the "Unapproved VPN killed" email.
- [ ] Connect the **approved** VPN (`181.214.9.54`) → it stays up, no email.
- [ ] Kill the monitor task (`Stop-ScheduledTask` as admin to simulate; a standard user cannot) → within `heartbeatStaleSeconds` the witness gets the "Tamper / silence" email.
- [ ] As the standard user, try `Unregister-ScheduledTask AccountabilityEnforcer` → **access denied**.
- [ ] Wait one report interval → witness receives the activity report with window titles; spool clears.

- [ ] **Step 2: Repeat the whole install on the friend's PC** with his config (his witness = you, his approved VPN endpoints, his NextDNS IPs).

- [ ] **Step 3: Commit the completed runbook**

```bash
git add accountability-agent/README.md
git commit -m "docs: end-to-end acceptance runbook"
```

---

## Addendum A: App & social-media policies (extends Tasks 1, 7, 10)

Adds per-app **report-only / time-box / block** policy. Policies live in the admin-locked config (Task 1 already includes the `appPolicies` field). Pure decisions are unit-tested; enforcement uses the Windows hosts file (block) and per-app foreground-minute accrual (time-box). `// ponytail: hosts-file block + title-match time accrual — simplest real enforcement; upgrade to per-process kill or NextDNS-API sync later.`

### Task A1: Policy.psm1 — pure app-policy decisions

**Files:**
- Create: `accountability-agent/src/Policy.psm1`
- Test: `accountability-agent/tests/Policy.Tests.ps1`

- [ ] **Step 1: Write the failing tests**

`tests/Policy.Tests.ps1`:
```powershell
Import-Module "$PSScriptRoot/../src/Policy.psm1" -Force

$policies = @(
    [pscustomobject]@{ name="Instagram"; policy="block";      domains=@("instagram.com"); titleMatch="Instagram"; dailyLimitMinutes=$null },
    [pscustomobject]@{ name="TikTok";    policy="time-box";   domains=@("tiktok.com");    titleMatch="TikTok";    dailyLimitMinutes=20 },
    [pscustomobject]@{ name="Reddit";    policy="report-only";domains=@("reddit.com");    titleMatch="Reddit";    dailyLimitMinutes=$null }
)

Describe "Get-AppForTitle" {
    It "matches an app by title substring" {
        (Get-AppForTitle -Title "TikTok - Chrome" -Policies $policies).name | Should Be "TikTok"
    }
    It "returns null when nothing matches" {
        Get-AppForTitle -Title "Visual Studio Code" -Policies $policies | Should Be $null
    }
}

Describe "Test-OverDailyLimit" {
    It "is over when accrued exceeds the limit" { Test-OverDailyLimit -AccruedMinutes 25 -LimitMinutes 20 | Should Be $true }
    It "is not over when under the limit"      { Test-OverDailyLimit -AccruedMinutes 5  -LimitMinutes 20 | Should Be $false }
    It "is never over when limit is null"      { Test-OverDailyLimit -AccruedMinutes 999 -LimitMinutes $null | Should Be $false }
}

Describe "Get-DesiredHostsEntries" {
    It "always blocks 'block' apps and adds over-limit time-box apps" {
        $entries = Get-DesiredHostsEntries -Policies $policies -OverLimitApps @("TikTok")
        $entries | Should Contain "instagram.com"
        $entries | Should Contain "tiktok.com"
        $entries | Should Not Contain "reddit.com"
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Invoke-Pester ./accountability-agent/tests/Policy.Tests.ps1`
Expected: FAIL — functions not defined.

- [ ] **Step 3: Write minimal implementation**

`src/Policy.psm1`:
```powershell
function Get-AppForTitle {
    param([string]$Title, [Parameter(Mandatory)]$Policies)
    if (-not $Title) { return $null }
    foreach ($p in $Policies) {
        if ($p.titleMatch -and $Title -like "*$($p.titleMatch)*") { return $p }
    }
    return $null
}

function Test-OverDailyLimit {
    param([int]$AccruedMinutes, $LimitMinutes)
    if ($null -eq $LimitMinutes) { return $false }
    return ($AccruedMinutes -gt [int]$LimitMinutes)
}

function Get-DesiredHostsEntries {
    # Domains that should be hosts-blocked right now: all 'block' apps,
    # plus any 'time-box' app named in OverLimitApps.
    param([Parameter(Mandatory)]$Policies, [string[]]$OverLimitApps = @())
    $out = @()
    foreach ($p in $Policies) {
        if ($p.policy -eq "block" -or ($p.policy -eq "time-box" -and $OverLimitApps -contains $p.name)) {
            $out += $p.domains
        }
    }
    return ($out | Select-Object -Unique)
}

Export-ModuleMember -Function Get-AppForTitle, Test-OverDailyLimit, Get-DesiredHostsEntries
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Invoke-Pester ./accountability-agent/tests/Policy.Tests.ps1`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add accountability-agent/src/Policy.psm1 accountability-agent/tests/Policy.Tests.ps1
git commit -m "feat: pure app-policy decisions with tests"
```

### Task A2: monitor.ps1 — accrue per-app foreground minutes

**Files:**
- Modify: `accountability-agent/src/monitor.ps1`

- [ ] **Step 1: Add accrual to the monitor loop**

At the top of `monitor.ps1`, after the existing `Add-Type` block, import Policy and load config:
```powershell
Import-Module "C:\Program Files\AccountabilityAgent\Policy.psm1" -Force
Import-Module "C:\Program Files\AccountabilityAgent\Common.psm1" -Force
$cfg = Get-AgentConfig -Path (Join-Path $DataDir "agent-config.json")
```
Inside the `while` loop, after computing `$title`, before `Start-Sleep`, add:
```powershell
$app = Get-AppForTitle -Title $title -Policies $cfg.appPolicies
if ($app -and $app.policy -eq "time-box") {
    # One usage file per app per day: "usage-<app>-<yyyyMMdd>.txt" holding accrued seconds.
    $day  = Get-Date -Format "yyyyMMdd"
    $file = Join-Path $DataDir ("usage-{0}-{1}.txt" -f $app.name, $day)
    $secs = 0; if (Test-Path $file) { $secs = [int](Get-Content $file -Raw) }
    Set-Content -Path $file -Value ($secs + 15)   # loop samples every 15s
}
```

- [ ] **Step 2: Smoke-test accrual**

Run monitor for ~45s against `$env:TEMP` with a window whose title contains "TikTok" (rename a Notepad, or open tiktok.com). 
Check: `Get-Content $env:TEMP\usage-TikTok-*.txt` shows a growing number (~30–45).
Expected: seconds accrue only while the matching window is foreground.

- [ ] **Step 3: Commit**

```bash
git add accountability-agent/src/monitor.ps1
git commit -m "feat: monitor accrues per-app foreground time for time-box policy"
```

### Task A3: enforcer.ps1 + Enforce.psm1 — apply hosts block from policy

**Files:**
- Modify: `accountability-agent/src/Enforce.psm1`
- Modify: `accountability-agent/src/enforcer.ps1`

- [ ] **Step 1: Add Set-HostsBlock to Enforce.psm1**

Append to `src/Enforce.psm1` and add to its export line:
```powershell
function Set-HostsBlock {
    # Idempotently maintain a managed block section in the hosts file.
    param([string[]]$Domains = @(), [string]$HostsPath = "$env:WINDIR\System32\drivers\etc\hosts")
    $begin = "# BEGIN AccountabilityAgent"; $end = "# END AccountabilityAgent"
    $content = if (Test-Path $HostsPath) { Get-Content $HostsPath } else { @() }
    # Strip any existing managed block.
    $kept = @(); $inBlock = $false
    foreach ($line in $content) {
        if ($line -eq $begin) { $inBlock = $true; continue }
        if ($line -eq $end)   { $inBlock = $false; continue }
        if (-not $inBlock)    { $kept += $line }
    }
    $block = @($begin) + ($Domains | ForEach-Object { "127.0.0.1 $_" }) + @($end)
    Set-Content -Path $HostsPath -Value ($kept + $block) -Encoding ASCII
}
```
```powershell
Export-ModuleMember -Function Set-NextDnsLock, Set-DohFirewallBlock, Disable-VpnAdapter, Set-HostsBlock
```

- [ ] **Step 2: Wire policy enforcement into enforcer.ps1**

In `enforcer.ps1`, add near the other imports:
```powershell
Import-Module "$PSScriptRoot/Policy.psm1" -Force
```
Inside the `while` loop, after the DNS re-lock block, add:
```powershell
# --- App policy: hosts-block 'block' apps + over-limit time-box apps ---
$overLimit = @()
$day = Get-Date -Format "yyyyMMdd"
foreach ($p in $cfg.appPolicies) {
    if ($p.policy -eq "time-box") {
        $file = Join-Path $DataDir ("usage-{0}-{1}.txt" -f $p.name, $day)
        $secs = 0; if (Test-Path $file) { $secs = [int](Get-Content $file -Raw) }
        if (Test-OverDailyLimit -AccruedMinutes ([int]($secs/60)) -LimitMinutes $p.dailyLimitMinutes) {
            $overLimit += $p.name
        }
    }
}
Set-HostsBlock -Domains (Get-DesiredHostsEntries -Policies $cfg.appPolicies -OverLimitApps $overLimit)
```

- [ ] **Step 3: Smoke-test hosts enforcement (admin shell)**

Run one enforcer loop iteration manually with a config whose Instagram policy is `block`; then:
Run: `Get-Content $env:WINDIR\System32\drivers\etc\hosts | Select-String "AccountabilityAgent","instagram"`
Expected: a managed block with `127.0.0.1 instagram.com`. Browsing instagram.com now fails. (Uninstall/`Set-HostsBlock -Domains @()` clears it.)

- [ ] **Step 4: Commit**

```bash
git add accountability-agent/src/Enforce.psm1 accountability-agent/src/enforcer.ps1
git commit -m "feat: enforce app policies via hosts-file block + daily time limits"
```

### Task A4: acceptance additions

**Files:**
- Modify: `accountability-agent/README.md`

- [ ] **Step 1: Add to the Task 12 checklist**

- [ ] A `block` app's domain fails to load and shows the managed hosts entry.
- [ ] A `time-box` app becomes blocked after its daily limit; the usage file resets the next day.
- [ ] A `report-only` app stays usable and appears in the witness report + NextDNS log.
- [ ] The standard user cannot edit the config to change a policy (config dir is admin-only).

- [ ] **Step 2: Commit**

```bash
git add accountability-agent/README.md
git commit -m "docs: app-policy acceptance checks"
```

---

## Self-review notes

- **Spec coverage:** Block (Task 0/NextDNS) ✅ · witness sees history (Task 0/NextDNS) ✅ · incognito (Task 0 + window titles Task 7) ✅ · VPN kill + allowlist `181.214.9.54` (Tasks 3,4,9) ✅ · tamper/dead-man (Tasks 5,10) ✅ · phones (Task 0) ✅ · app policies report-only/time-box/block (Addendum A) ✅ · mutual two-person (Task 12 Step 2) ✅ · Supporter mode — **deferred** (config field `supporterEmail` reserved; no task) — noted below.
- **Deferred vs spec (flagged):** (a) browser-history-*file* reader — URL history comes from NextDNS instead; (b) Supporter/encouragement-only emails — field reserved, build when a partner is actually added; (c) event-driven VPN trigger — v1 uses a `vpnPollSeconds` short poll instead of network-change events. All three are additive and don't change the interfaces above.
- **Type consistency:** config field names (`approvedVpnIps`, `nextDnsIps`, `heartbeatStaleSeconds`, `reportIntervalMinutes`, `vpnPollSeconds`, `smtp.*`) are identical across config example, Common, enforcer, reporter. Function names match across modules and callers.
