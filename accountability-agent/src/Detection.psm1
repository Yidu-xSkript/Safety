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

function Get-VpnAdapterState {
    # Returns @{ Present = <bool>; Adapters = <adapter objects> }
    # ponytail: heuristic VPN detection by adapter description — extend the regex as new clients show up.
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

function Test-HeartbeatStale {
    param(
        [AllowNull()][Nullable[datetime]]$LastBeat,
        [Parameter(Mandatory)][datetime]$Now,
        [Parameter(Mandatory)][int]$ThresholdSeconds
    )
    if ($null -eq $LastBeat) { return $true }
    return (($Now - $LastBeat).TotalSeconds -gt $ThresholdSeconds)
}

Export-ModuleMember -Function Test-UnapprovedVpn, Get-VpnAdapterState, Get-ActiveRemoteIp, Test-HeartbeatStale
