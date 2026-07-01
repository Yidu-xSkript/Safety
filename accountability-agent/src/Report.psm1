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
        "TimeBox"       { return @{ Subject = "[Accountability] Time-box limit reached: $Detail"; Body = "Daily time limit exceeded for: $Detail. The app is now blocked for the rest of the day." } }
        default         { return @{ Subject = "[Accountability] Alert: $Kind"; Body = $Detail } }
    }
}

Export-ModuleMember -Function Format-WitnessReport, Format-AlertEmail