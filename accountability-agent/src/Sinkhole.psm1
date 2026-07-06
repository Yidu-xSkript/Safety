# Pure parsers for the sinkhole listener: pull the intended hostname out of the first bytes a
# browser sends when it connects to a blocked domain (which the hosts file points at 127.0.0.1).
# The connection is going to 127.0.0.1, but the ORIGINAL hostname survives in the TLS SNI (HTTPS)
# or the HTTP Host header (HTTP) -- that's what lets us log WHICH blocked site was attempted, even
# on a VPN where NextDNS can't see it. Kept pure (byte[] in, string out) so they are unit-testable.

function Get-TlsSni {
    # Extract the SNI hostname from a TLS ClientHello. Returns "" if the bytes aren't a ClientHello
    # or carry no server_name extension. Bounds-checked throughout: a malformed/truncated record
    # returns "" rather than throwing (a browser or scanner can send anything at a listening port).
    param([Parameter(Mandatory)][byte[]]$Bytes, [int]$Length = -1)
    if ($Length -lt 0) { $Length = $Bytes.Length }
    try {
        if ($Length -lt 43 -or $Bytes[0] -ne 0x16) { return "" }   # 0x16 = TLS handshake record
        # Fixed prefix: record hdr(5) + handshake hdr(4) + client version(2) + random(32) = 43 bytes.
        $i = 43
        $sidLen = $Bytes[$i]; $i += 1 + $sidLen                     # session id
        if ($i + 2 -gt $Length) { return "" }
        $csLen = ($Bytes[$i] -shl 8) -bor $Bytes[$i + 1]; $i += 2 + $csLen   # cipher suites
        if ($i + 1 -gt $Length) { return "" }
        $cmLen = $Bytes[$i]; $i += 1 + $cmLen                       # compression methods
        if ($i + 2 -gt $Length) { return "" }
        $extLen = ($Bytes[$i] -shl 8) -bor $Bytes[$i + 1]; $i += 2  # extensions block
        $end = [Math]::Min($Length, $i + $extLen)
        while ($i + 4 -le $end) {
            $etype = ($Bytes[$i] -shl 8) -bor $Bytes[$i + 1]
            $elen  = ($Bytes[$i + 2] -shl 8) -bor $Bytes[$i + 3]
            $i += 4
            if ($etype -eq 0) {                                     # 0x0000 = server_name
                # server_name_list: list_len(2) name_type(1) name_len(2) name
                if ($i + 5 -gt $Length) { return "" }
                $nameLen = ($Bytes[$i + 3] -shl 8) -bor $Bytes[$i + 4]
                $start = $i + 5
                if ($nameLen -le 0 -or $start + $nameLen -gt $Length) { return "" }
                return [System.Text.Encoding]::ASCII.GetString($Bytes, $start, $nameLen)
            }
            $i += $elen
        }
        return ""
    } catch { return "" }
}

function Get-HttpHost {
    # Extract the hostname from a plain-HTTP request's Host: header (port 80 fallback). Returns ""
    # if there is no Host header. Strips any :port suffix.
    param([Parameter(Mandatory)][byte[]]$Bytes, [int]$Length = -1)
    if ($Length -lt 0) { $Length = $Bytes.Length }
    if ($Length -le 0) { return "" }
    $text = [System.Text.Encoding]::ASCII.GetString($Bytes, 0, $Length)
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^(?i)Host:\s*(.+?)\s*$') { return (($Matches[1] -split ':')[0]).Trim() }
    }
    return ""
}

Export-ModuleMember -Function Get-TlsSni, Get-HttpHost
