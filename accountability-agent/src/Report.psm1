function Group-ActivitySamples {
    # Collapse raw "<timestamp> | <text>" lines (window titles are sampled every 15s, so the same
    # title repeats dozens of times) into one readable block per distinct activity:
    #     <text>
    #         Accessed at: HH:mm:ss, HH:mm:ss, ...
    # Groups keep first-seen order; timestamps are de-duplicated within a group and shown as
    # HH:mm:ss (unparseable timestamps fall back to the raw token). Pure -> unit-testable.
    param([string[]]$Lines = @())
    $order  = @()          # distinct texts, in first-seen order
    $byText = @{}          # text -> ordered unique time strings
    foreach ($line in $Lines) {
        if (-not $line) { continue }
        $parts = $line -split '\s*\|\s*', 2
        if ($parts.Count -eq 2) { $ts = $parts[0].Trim(); $text = $parts[1].Trim() }
        else { $ts = ''; $text = $line.Trim() }
        if (-not $text) { continue }
        $time = ''
        if ($ts) { $dt = [datetime]::MinValue; $time = if ([datetime]::TryParse($ts, [ref]$dt)) { $dt.ToString('HH:mm') } else { $ts } }
        if (-not $byText.ContainsKey($text)) { $order += $text; $byText[$text] = New-Object System.Collections.Generic.List[string] }
        if ($time -and -not $byText[$text].Contains($time)) { [void]$byText[$text].Add($time) }
    }
    $blocks = foreach ($text in $order) {
        $times = $byText[$text]
        if ($times.Count -gt 0) { "$text`n        Accessed at: $($times -join ', ')" } else { $text }
    }
    return ($blocks -join ("`n" + ('-' * 50) + "`n"))
}

function Format-WitnessReport {
    param([string[]]$Samples = @(), [string]$Since)
    $distinct = @(@($Samples | ForEach-Object { (($_ -split '\s*\|\s*', 2)[-1]).Trim() } | Where-Object { $_ }) | Select-Object -Unique).Count
    $header = "Accountability report (since $Since) - $distinct distinct activities`n`n"
    if ($Samples.Count -eq 0) { return $header + "No activity captured in this window." }
    return $header + (Group-ActivitySamples -Lines $Samples)
}

function Format-AlertEmail {
    param([Parameter(Mandatory)][string]$Kind, [string]$Detail)
    switch ($Kind) {
        "UnapprovedVPN" { return @{ Subject = "[Accountability] Unapproved VPN killed"; Body = "An unapproved VPN was detected and disabled. Endpoint(s): $Detail" } }
        "Tamper"        { return @{ Subject = "[Accountability] Tamper / silence detected"; Body = "The monitor stopped reporting. Detail: $Detail" } }
        "HostsTamper"   { return @{ Subject = "[Accountability] Tamper: block list edited"; Body = "The hosts block file was modified externally and has been restored. $Detail" } }
        "DnsTamper"     { return @{ Subject = "[Accountability] Tamper: DNS changed"; Body = "DNS was changed away from NextDNS and has been restored. $Detail" } }
        "IncognitoTamper" { return @{ Subject = "[Accountability] Tamper: incognito re-enabled"; Body = "A browser's incognito/private-mode policy was changed back on and has been re-disabled. Private browsing hides pages from the history report, so review recent NextDNS logs. $Detail" } }
        "TorBlocked"    { return @{ Subject = "[Accountability] Tor Browser detected and closed"; Body = "Tor Browser was launched and has been closed. Tor bypasses NextDNS filtering AND the history report entirely, so this is a deliberate circumvention attempt. Closed process(es): $Detail" } }
        "PornAccess"    { return @{ Subject = "[Accountability] Adult site accessed"; Body = "An adult/porn site was just loaded in a browser (seen in on-disk history, so this happened even if the hosts/NextDNS block was bypassed via VPN or a brand-new domain). This is an immediate alert, not the hourly report. Detail: $Detail" } }
        "PornAttempt"   { return @{ Subject = "[Accountability] Adult site ATTEMPTED"; Body = "An adult/porn domain was requested (seen in the NextDNS query log). This fires on the ATTEMPT whether or not it was blocked, so a successful block still notifies you. Domain: $Detail" } }
        "ConfigTamper"  { return @{ Subject = "[Accountability] Tamper: config altered"; Body = "The agent configuration file was modified. The agent keeps running on its original settings. $Detail" } }
        "UninstallAttempt" { return @{ Subject = "[Accountability] Uninstall attempt (wrong password)"; Body = "Someone ran the uninstaller with the wrong password. Uninstall was refused. $Detail" } }
        "DnsFailsafe"   { return @{ Subject = "[Accountability] NextDNS unreachable - DNS lock backed off"; Body = "NextDNS did not answer, so the agent removed the DNS lock to keep the machine online. Filtering via NextDNS is currently NOT active; hosts-file blocking (porn/SafeSearch/apps) still applies. Check the NextDNS config/IPs. $Detail" } }
        "ApprovedVpnActive" { return @{ Subject = "[Accountability] Approved VPN in use"; Body = "The approved VPN is active. NextDNS site logging is blind while it is on, so review the activity report (window titles). Porn/SafeSearch block is enforced through the VPN. $Detail" } }
        "AgentReinstalled" { return @{ Subject = "[Accountability] Agent re-installed / uninstall password changed"; Body = "The installer (install.ps1) was run again. This re-registers the agent and may have changed the uninstall password. If you (the witness) did not do this, the protected user did. $Detail" } }
        "TimeBox"       { return @{ Subject = "[Accountability] Time-box limit reached: $Detail"; Body = "Daily time limit exceeded for: $Detail. The app is now blocked for the rest of the day." } }
        default         { return @{ Subject = "[Accountability] Alert: $Kind"; Body = $Detail } }
    }
}

function Format-SupporterEmail {
    # Encouragement-only, for the partner (Supporter). NO raw data — a milestone + current streak.
    param([Parameter(Mandatory)][int]$StreakDays, [int]$Milestone)
    return @{
        Subject = "Encouragement update: $StreakDays days strong"
        Body = "Good news to share: a milestone of $Milestone consecutive clean days has been reached (currently at $StreakDays). No activity details are included here — just the progress. Thank you for being in their corner."
    }
}

Export-ModuleMember -Function Format-WitnessReport, Group-ActivitySamples, Format-AlertEmail, Format-SupporterEmail