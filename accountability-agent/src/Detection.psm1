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
    $pattern = 'VPN|TAP|TUN|WireGuard|Wintun|OpenVPN|NordLynx|Mullvad|Proton|Private Internet Access|PIA|WAN Miniport \((IKEv2|L2TP|PPTP|SSTP|Network Monitor)\)'
    $vpn = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -match $pattern }
    return @{ Present = [bool]$vpn; Adapters = $vpn }
}

function Get-ActiveRemoteIp {
    # Remote endpoints indicating a live connection/tunnel to a server. Includes:
    #  - established TCP peers
    #  - /32 host routes: a VPN client installs a host route to its tunnel server so
    #    tunnel packets don't loop, which reveals UDP tunnels (IKEv2/IPsec/WireGuard)
    #    that never show up as TCP connections
    #  - ServerAddress of any Connected built-in Windows VPN connection (resolved to IP)
    # This lets the approved (often UDP) work VPN be recognized, not just TCP tunnels.
    $ips = @()
    $ips += (Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty RemoteAddress)
    $ips += (Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.DestinationPrefix -like '*/32' } |
        ForEach-Object { ($_.DestinationPrefix -split '/')[0] })
    $ips += (Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue |
        Where-Object { $_.ConnectionStatus -eq 'Connected' } |
        ForEach-Object {
            if ($_.ServerAddress -as [ipaddress]) { $_.ServerAddress }
            else {
                try { Resolve-DnsName $_.ServerAddress -Type A -ErrorAction Stop |
                    Select-Object -First 1 -ExpandProperty IPAddress } catch { }
            }
        })
    return ($ips | Where-Object { $_ } | Select-Object -Unique)
}

function Test-VpnActive {
    # Robust "is a VPN tunnel up?" check that does NOT depend on the adapter-description regex
    # (which misses many clients). Uses three signals, any of which means a VPN is active:
    #  1. a Connected built-in Windows VPN connection,
    #  2. a /32 host route to an approved VPN endpoint (the OS adds this when the tunnel connects),
    #  3. an up adapter whose description matches a known VPN pattern.
    param([string[]]$ApprovedVpnIps = @())
    try {
        if (Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue |
            Where-Object { $_.ConnectionStatus -eq 'Connected' }) { return $true }
    } catch { }
    foreach ($ip in $ApprovedVpnIps) {
        if (Get-NetRoute -DestinationPrefix "$ip/32" -ErrorAction SilentlyContinue) { return $true }
    }
    $pattern = 'VPN|TAP|TUN|WireGuard|Wintun|OpenVPN|NordLynx|Mullvad|Proton|Private Internet Access|PIA|WAN Miniport \((IKEv2|L2TP|PPTP|SSTP)\)'
    if (Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -match $pattern }) { return $true }
    return $false
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

Export-ModuleMember -Function Test-UnapprovedVpn, Get-VpnAdapterState, Get-ActiveRemoteIp, Test-HeartbeatStale, Test-VpnActive
