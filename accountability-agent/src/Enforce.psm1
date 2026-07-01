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

Export-ModuleMember -Function Set-NextDnsLock, Set-DohFirewallBlock, Disable-VpnAdapter, Set-HostsBlock
