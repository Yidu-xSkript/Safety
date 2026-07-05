# Read-only end-to-end verification for the Accountability Agent.
# Changes NOTHING. Run in an ELEVATED PowerShell (SYSTEM/Highest scheduled tasks and the
# admin-only SecretsDir are invisible from a normal shell, which would show false FAILs).
#   Right-click PowerShell -> Run as administrator, then:  .\verify.ps1
param(
    [string]$SecretsDir = "C:\ProgramData\AccountabilityAgent",
    [string]$RuntimeDir = "C:\ProgramData\AccountabilityAgentRuntime"
)

$script:fail = 0; $script:warn = 0
function Say([string]$status, [string]$msg) {
    $color = switch ($status) { 'PASS' {'Green'} 'FAIL' {'Red'} 'WARN' {'Yellow'} default {'Gray'} }
    if ($status -eq 'FAIL') { $script:fail++ }; if ($status -eq 'WARN') { $script:warn++ }
    Write-Host ("[{0}] {1}" -f $status, $msg) -ForegroundColor $color
}

# 0. Elevation
$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($elevated) { Say PASS "Running elevated (can see SYSTEM tasks + SecretsDir)." }
else { Say WARN "NOT elevated - task/config checks below may false-FAIL. Re-run as administrator." }

# 1. Scheduled tasks
Write-Host "`n-- Scheduled tasks --"
foreach ($t in 'AccountabilityEnforcer','AccountabilityMonitor') {
    $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if (-not $task) { Say FAIL "$t : not registered."; continue }
    $state = "$($task.State)"
    if ($state -eq 'Running') { Say PASS "$t : $state" }
    elseif ($state -eq 'Ready') { Say WARN "$t : $state (Enforcer starts it; re-check in ~1 poll)" }
    else { Say FAIL "$t : $state" }
}
# Confirm the enforcer is actually a live process, not just a 'Running' task shell
$live = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'enforcer\.ps1' }
if ($live) { Say PASS "enforcer.ps1 process is live (PID $($live.ProcessId -join ','))." }
else { Say FAIL "No live enforcer.ps1 process found." }

# 2. Incognito / private-mode policy keys (expect value 1)
Write-Host "`n-- Incognito disabled (browser policy) --"
$browsers = @(
    @{ Key='Google\Chrome';       Name='IncognitoModeAvailability' }
    @{ Key='Microsoft\Edge';      Name='InPrivateModeAvailability' }
    @{ Key='BraveSoftware\Brave'; Name='IncognitoModeAvailability' }
    @{ Key='Chromium';            Name='IncognitoModeAvailability' }
    @{ Key='Mozilla\Firefox';     Name='DisablePrivateBrowsing' }
)
foreach ($b in $browsers) {
    $path = "HKLM:\SOFTWARE\Policies\$($b.Key)"
    $val = (Get-ItemProperty -Path $path -Name $b.Name -ErrorAction SilentlyContinue).($b.Name)
    if ($val -eq 1) { Say PASS "$($b.Key) $($b.Name)=1" }
    else { Say FAIL "$($b.Key) $($b.Name)=$val (expected 1)" }
}

# 3. Hosts file: managed block present + Tor download blocked
Write-Host "`n-- Hosts block --"
$hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"
$hosts = if (Test-Path $hostsPath) { Get-Content $hostsPath } else { @() }
if ($hosts -contains '# BEGIN AccountabilityAgent') { Say PASS "Managed hosts block present." }
else { Say FAIL "Managed hosts block (# BEGIN AccountabilityAgent) missing." }
if ($hosts -match 'torproject\.org') { Say PASS "torproject.org is hosts-blocked." }
else { Say FAIL "torproject.org NOT in hosts block (Tor download friction inactive)." }

# 4. Tor not currently running (agent should have killed any)
Write-Host "`n-- Tor Browser --"
$tor = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -eq 'tor' -or ($_.Name -eq 'firefox' -and "$($_.Path)" -match 'Tor Browser')
}
if ($tor) { Say FAIL "Tor process alive: $(( $tor | ForEach-Object Name ) -join ', ') (agent should close it within one poll)." }
else { Say PASS "No Tor process running." }

# 5. Monitor heartbeat fresh
Write-Host "`n-- Monitor heartbeat --"
$cfgPath = Join-Path $SecretsDir 'agent-config.json'
$staleSecs = 300
if (Test-Path $cfgPath) {
    try { $c = Get-Content $cfgPath -Raw | ConvertFrom-Json; if ($c.heartbeatStaleSeconds) { $staleSecs = [int]$c.heartbeatStaleSeconds } } catch {}
} else { Say WARN "agent-config.json not readable ($cfgPath) - are you elevated?" }
$hb = Join-Path $RuntimeDir 'monitor.heartbeat'
if (Test-Path $hb) {
    $raw = (Get-Content $hb -Raw).Trim()
    try {
        $beat = [datetime]::ParseExact($raw, 'o', [Globalization.CultureInfo]::InvariantCulture)
        $age = ((Get-Date) - $beat).TotalSeconds
        if ($age -le $staleSecs) { Say PASS ("Heartbeat fresh ({0:N0}s old, threshold {1}s)." -f $age, $staleSecs) }
        else { Say FAIL ("Heartbeat STALE ({0:N0}s old > {1}s) - monitor not reporting." -f $age, $staleSecs) }
    } catch { Say FAIL "Heartbeat file unparseable: '$raw'." }
} else { Say FAIL "No monitor.heartbeat file (monitor never ran)." }

# 6. Activity capture is filling
Write-Host "`n-- Activity capture --"
$hist = Join-Path $RuntimeDir 'history-spool.txt'
if (Test-Path $hist) {
    $len = (Get-Item $hist).Length
    if ($len -gt 0) { Say PASS "history-spool.txt has data ($len bytes)." }
    else { Say WARN "history-spool.txt exists but empty (browse a site, then re-check)." }
} else { Say WARN "history-spool.txt not present yet (fills after browsing + a monitor cycle)." }

# 7. Log sanity: recent activity, no DNS flapping storm
Write-Host "`n-- Agent log --"
$log = Join-Path $RuntimeDir 'agent.log'
if (Test-Path $log) {
    $tail = Get-Content $log -Tail 200 -ErrorAction SilentlyContinue
    $flap = @($tail | Where-Object { $_ -match 'unreachable|backed off|reachable again' }).Count
    Say PASS "agent.log present ($((Get-Item $log).Length) bytes)."
    if ($flap -ge 6) { Say WARN "$flap DNS reachable/unreachable lines in last 200 - possible flapping. Consider dnsManagementEnabled=false (NextDNS app owns DNS)." }
    else { Say PASS "No DNS flapping storm in recent log ($flap fail-safe lines)." }
} else { Say WARN "agent.log not found at $log." }

# Summary
Write-Host "`n=============================="
if ($script:fail -eq 0 -and $script:warn -eq 0) { Write-Host "ALL CHECKS PASSED." -ForegroundColor Green }
elseif ($script:fail -eq 0) { Write-Host "PASSED with $($script:warn) warning(s) to eyeball." -ForegroundColor Yellow }
else { Write-Host "$($script:fail) FAILURE(S), $($script:warn) warning(s). See red lines above." -ForegroundColor Red }
