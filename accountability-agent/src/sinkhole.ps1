param([string]$RuntimeDir = "C:\ProgramData\AccountabilityAgentRuntime")

# Local sinkhole listener. Blocked domains (porn + app-block) are pointed at 127.0.0.1 by the hosts
# file; when a browser tries to load one it connects here. We read only the first bytes to recover
# the INTENDED hostname (TLS SNI on 443, Host header on 80), append it to a spool the enforcer reads
# for attempt alerts, then drop the connection (so the site stays blocked). This works on a VPN,
# where NextDNS is blind -- the whole point of this component. Runs as SYSTEM (binds ports < 1024).

Import-Module "$PSScriptRoot/Sinkhole.psm1" -Force

$spool = Join-Path $RuntimeDir "sinkhole-spool.txt"
New-Item -ItemType Directory -Path $RuntimeDir -Force -ErrorAction SilentlyContinue | Out-Null

# Bind loopback :443 and :80. A port already in use (e.g. a local dev server) is skipped, not fatal —
# blocked domains on that port still fail to load, we just can't log the hostname for them.
$listeners = @()
foreach ($port in 443, 80) {
    try {
        $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
        $l.Start()
        $listeners += $l
    } catch { }
}
if ($listeners.Count -eq 0) { return }   # nothing to do; ports occupied

while ($true) {
    try {
        $idle = $true
        foreach ($l in $listeners) {
            $isTls = ($l.LocalEndpoint.Port -eq 443)
            while ($l.Pending()) {
                $idle = $false
                $client = $l.AcceptTcpClient()
                try {
                    $client.ReceiveTimeout = 500
                    $ns  = $client.GetStream()
                    $buf = New-Object byte[] 4096
                    $n   = $ns.Read($buf, 0, $buf.Length)
                    $name = if ($isTls) { Get-TlsSni -Bytes $buf -Length $n } else { Get-HttpHost -Bytes $buf -Length $n }
                    if ($name) { Add-Content -Path $spool -Value ("{0} | {1}" -f (Get-Date -Format "s"), $name) -ErrorAction SilentlyContinue }
                } catch { }
                finally { $client.Close() }
            }
        }
        if ($idle) { Start-Sleep -Milliseconds 200 }   # nothing pending: don't spin the CPU
    } catch { Start-Sleep -Milliseconds 500 }
}
