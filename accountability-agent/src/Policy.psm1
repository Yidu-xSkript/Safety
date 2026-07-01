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
