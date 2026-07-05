function Set-NextDnsLock {
    # Re-apply NextDNS on every active NON-VPN interface if it has drifted.
    # VPN adapters (incl. the approved work VPN) are left untouched so we never
    # break the tunnel's own name resolution.
    # Returns $true if any adapter's DNS had to be corrected (i.e. it had drifted) — the
    # caller treats a post-startup correction as tampering.
    param([Parameter(Mandatory)][string[]]$NextDnsIps)
    $vpnPattern = 'VPN|TAP|TUN|WireGuard|Wintun|OpenVPN|WAN Miniport \((IKEv2|L2TP|PPTP|SSTP|Network Monitor)\)'
    $changed = $false
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch $vpnPattern }
    foreach ($a in $adapters) {
        $cur = (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
        if (($cur -join ',') -ne ($NextDnsIps -join ',')) {
            Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $NextDnsIps -ErrorAction SilentlyContinue
            $changed = $true
        }
    }
    return $changed
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

function Test-NextDnsReachable {
    # Verify at least one NextDNS IP actually answers DNS over UDP:53 (the real DNS path). Sends a
    # raw DNS query for example.com and waits for any reply. This deliberately avoids
    # Resolve-DnsName (which falls back to the DNS cache and can't tell a dead server from a live
    # one). Gates the DNS firewall lock so we never strangle all DNS when NextDNS is unreachable.
    param([Parameter(Mandatory)][string[]]$NextDnsIps, [int]$TimeoutMs = 2000)
    # Minimal DNS query packet: header (id 0x1234, RD flag, qdcount=1) + question example.com A IN.
    $q = New-Object System.Collections.Generic.List[byte]
    $q.AddRange([byte[]](0x12,0x34, 0x01,0x00, 0x00,0x01, 0x00,0x00, 0x00,0x00, 0x00,0x00))
    foreach ($label in @('example','com')) {
        $q.Add([byte]$label.Length)
        $q.AddRange([System.Text.Encoding]::ASCII.GetBytes($label))
    }
    $q.Add(0)
    $q.AddRange([byte[]](0x00,0x01, 0x00,0x01))   # QTYPE A, QCLASS IN
    $bytes = $q.ToArray()

    foreach ($ip in $NextDnsIps) {
        $udp = $null
        try {
            $udp = New-Object System.Net.Sockets.UdpClient
            $udp.Client.ReceiveTimeout = $TimeoutMs
            $udp.Connect($ip, 53)
            [void]$udp.Send($bytes, $bytes.Length)
            $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
            $resp = $udp.Receive([ref]$remote)
            if ($resp.Length -gt 0) { $udp.Close(); return $true }
        } catch { }
        finally { if ($udp) { $udp.Close() } }
    }
    return $false
}

function Remove-DohFirewallBlock {
    # Remove the DNS-lock firewall rules (used to back off when NextDNS is unreachable).
    Get-NetFirewallRule -DisplayName "AA-Block-DoH", "AA-Block-Plain-DNS", "AA-Allow-NextDNS" `
        -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
}

function Reset-DnsToAuto {
    # Reset DNS to DHCP/automatic on every up adapter (recover connectivity on back-off).
    Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | ForEach-Object {
        Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
    }
}

function Disable-VpnAdapter {
    param([Parameter(Mandatory)]$Adapters)
    foreach ($a in $Adapters) {
        Disable-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction SilentlyContinue
    }
}

function Set-IncognitoDisabled {
    # Pre-seed browser enterprise policies so private/incognito browsing is unavailable —
    # including for browsers not yet installed, which read their policy key on first launch.
    # This restores the history reader's visibility (incognito never wrote to history; it was
    # never hidden from NextDNS). Value 1 = incognito DISABLED. NOT 2, which would FORCE
    # incognito and hide history — the opposite of what we want.
    # Idempotent, and rewritten every loop by SYSTEM, so a user deleting a key just gets it
    # back (friction, not lock — the protected user is a local admin).
    # $PolicyRoot is overridable so tests can target a writable hive instead of HKLM.
    # Returns $true if any key was missing/wrong and had to be (re)written — the caller treats a
    # post-startup correction as tampering (a user turning incognito back on).
    param([string]$PolicyRoot = "HKLM:\SOFTWARE\Policies")
    # vendor subkey -> value name. Chromium forks (Vivaldi and most others) honor the Chromium key.
    $browsers = @(
        @{ Key = "Google\Chrome";       Name = "IncognitoModeAvailability" }   # Chrome
        @{ Key = "Microsoft\Edge";      Name = "InPrivateModeAvailability" }   # Edge
        @{ Key = "BraveSoftware\Brave"; Name = "IncognitoModeAvailability" }   # Brave
        @{ Key = "Chromium";            Name = "IncognitoModeAvailability" }   # Chromium & forks
        @{ Key = "Mozilla\Firefox";     Name = "DisablePrivateBrowsing" }      # Firefox
    )
    $changed = $false
    foreach ($b in $browsers) {
        $path = Join-Path $PolicyRoot $b.Key
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        $cur = (Get-ItemProperty -Path $path -Name $b.Name -ErrorAction SilentlyContinue).($b.Name)
        if ($cur -ne 1) {
            Set-ItemProperty -Path $path -Name $b.Name -Value 1 -Type DWord
            $changed = $true
        }
    }
    return $changed
}

function Select-TorProcess {
    # Pure selection (no side effects, injectable list -> unit-testable without killing anything):
    # pick Tor's processes = the tor.exe daemon (a normal browser never spawns one) OR a firefox.exe
    # whose path is inside a "Tor Browser" folder — so a normal standalone Firefox is left alone.
    # A firefox with an unreadable path (empty) won't match, so we only kill firefox we can confirm.
    param([Parameter(Mandatory)]$Processes)
    return @($Processes | Where-Object {
        $_.Name -eq 'tor' -or ($_.Name -eq 'firefox' -and "$($_.Path)" -match 'Tor Browser')
    })
}

function Stop-TorBrowser {
    # Close Tor Browser when detected. Tor bypasses NextDNS (its DNS runs through the circuit) AND
    # ignores the incognito policy (it is permanently private), so neither logging nor policy can
    # touch it — killing the process is the only lever. Runs as SYSTEM so it can end user processes.
    # ponytail: poll-interval detection lag (Tor can be open up to one loop before it's killed); the
    # monitor's window-title capture still records that Tor was opened, so the attempt isn't invisible.
    # Returns the unique process names it stopped (for the witness alert), empty array if none.
    $tor = Select-TorProcess -Processes (Get-Process -ErrorAction SilentlyContinue)
    foreach ($p in $tor) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    return @($tor | ForEach-Object { $_.Name } | Select-Object -Unique | Sort-Object)
}

function Set-HostsBlock {
    # Idempotently maintain a managed block section in the hosts file.
    # $Domains   -> "127.0.0.1 <domain>" block entries.
    # $Redirects -> hashtable of <domain> = <ip>, written as "<ip> <domain>" (e.g. SafeSearch
    #               redirects that point a search hostname at its force-safe IP). Sorted by domain
    #               so the output is deterministic (stable for the hash-based tamper check).
    # Rewrites the file only when content actually changes (avoids ~per-poll churn/races).
    param(
        [string[]]$Domains = @(),
        [hashtable]$Redirects = @{},
        [string]$HostsPath = "$env:WINDIR\System32\drivers\etc\hosts"
    )
    $begin = "# BEGIN AccountabilityAgent"; $end = "# END AccountabilityAgent"
    $content = if (Test-Path $HostsPath) { @(Get-Content $HostsPath) } else { @() }
    # Strip a previous managed block. If a BEGIN has no matching END (corruption/partial
    # write), only the stray BEGIN marker is dropped so we never swallow the rest of the file.
    $hasEnd = $content -contains $end
    $kept = @(); $inBlock = $false
    foreach ($line in $content) {
        if ($line -eq $begin) { if ($hasEnd) { $inBlock = $true }; continue }
        if ($line -eq $end)   { $inBlock = $false; continue }
        if (-not $inBlock)    { $kept += $line }
    }
    $redirectLines = @($Redirects.Keys | Sort-Object | ForEach-Object { "$($Redirects[$_]) $_" })
    $block = @($begin) + ($Domains | ForEach-Object { "127.0.0.1 $_" }) + $redirectLines + @($end)
    $new = @($kept + $block)
    if (($new -join "`n") -ne ($content -join "`n")) {
        # The hosts file is frequently locked for a moment (Defender/AV scanning it right after a
        # write, or another tool touching it). Retry so a transient lock doesn't (a) throw a loop
        # error and (b) leave the file un-rewritten, which the enforcer then misreads as external
        # tampering and alerts the witness about. ~1.5s of retries clears the common transient lock.
        for ($try = 1; $try -le 6; $try++) {
            try { Set-Content -Path $HostsPath -Value $new -Encoding ASCII -ErrorAction Stop; return $true }
            catch { if ($try -eq 6) { throw }; Start-Sleep -Milliseconds 250 }
        }
    }
    return $false    # already in sync, nothing to write
}

Export-ModuleMember -Function Set-NextDnsLock, Set-DohFirewallBlock, Disable-VpnAdapter, Set-HostsBlock, Set-IncognitoDisabled, Select-TorProcess, Stop-TorBrowser, Test-NextDnsReachable, Remove-DohFirewallBlock, Reset-DnsToAuto
