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
        "HostsTamper"   { return @{ Subject = "[Accountability] Tamper: block list edited"; Body = "The hosts block file was modified externally and has been restored. $Detail" } }
        "DnsTamper"     { return @{ Subject = "[Accountability] Tamper: DNS changed"; Body = "DNS was changed away from NextDNS and has been restored. $Detail" } }
        "ConfigTamper"  { return @{ Subject = "[Accountability] Tamper: config altered"; Body = "The agent configuration file was modified. The agent keeps running on its original settings. $Detail" } }
        "UninstallAttempt" { return @{ Subject = "[Accountability] Uninstall attempt (wrong password)"; Body = "Someone ran the uninstaller with the wrong password. Uninstall was refused. $Detail" } }
        "DnsFailsafe"   { return @{ Subject = "[Accountability] NextDNS unreachable - DNS lock backed off"; Body = "NextDNS did not answer, so the agent removed the DNS lock to keep the machine online. Filtering via NextDNS is currently NOT active; hosts-file blocking (porn/SafeSearch/apps) still applies. Check the NextDNS config/IPs. $Detail" } }
        "ApprovedVpnActive" { return @{ Subject = "[Accountability] Approved VPN in use"; Body = "The approved VPN is active. NextDNS site logging is blind while it is on, so review the activity report (window titles). The hosts-file porn/SafeSearch block is enforced through the VPN. $Detail" } }
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

Export-ModuleMember -Function Format-WitnessReport, Format-AlertEmail, Format-SupporterEmail