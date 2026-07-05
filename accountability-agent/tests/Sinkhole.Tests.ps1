Import-Module "$PSScriptRoot/../src/Sinkhole.psm1" -Force

# Build a minimal but valid TLS ClientHello carrying a given SNI, so we test the real parser path.
function New-ClientHelloWithSni([string]$Sni) {
    $name = [System.Text.Encoding]::ASCII.GetBytes($Sni)
    $nl = $name.Length
    # server_name extension body: list_len(2) name_type(1)=0 name_len(2) name
    $sniBody = @(0x00, ($nl + 3), 0x00, ([byte](($nl -shr 8) -band 0xff)), ([byte]($nl -band 0xff))) + $name
    # NOTE list_len above is name_type(1)+name_len(2)+name = nl+3; high byte assumed 0 for short names.
    $ext = @(0x00, 0x00, ([byte]((($sniBody.Length) -shr 8) -band 0xff)), ([byte](($sniBody.Length) -band 0xff))) + $sniBody
    $extLen = $ext.Length
    $body = @()
    $body += @(0x03, 0x03)                              # client version
    $body += ,0 * 32                                    # random
    $body += 0x00                                       # session id len = 0
    $body += @(0x00, 0x02, 0x00, 0x2f)                  # cipher suites: len 2 + one suite
    $body += @(0x01, 0x00)                              # compression: len 1 + null
    $body += @(([byte](($extLen -shr 8) -band 0xff)), ([byte]($extLen -band 0xff))) + $ext
    $hs = @(0x01, 0x00, ([byte]((($body.Length) -shr 8) -band 0xff)), ([byte](($body.Length) -band 0xff))) + $body
    $rec = @(0x16, 0x03, 0x01, ([byte]((($hs.Length) -shr 8) -band 0xff)), ([byte](($hs.Length) -band 0xff))) + $hs
    return [byte[]]$rec
}

Describe "Get-TlsSni" {
    It "extracts the SNI hostname from a ClientHello" {
        $bytes = New-ClientHelloWithSni "www.xhamster.com"
        (Get-TlsSni -Bytes $bytes) | Should Be "www.xhamster.com"
    }
    It "returns empty for non-TLS bytes" {
        (Get-TlsSni -Bytes ([byte[]]@(0x47,0x45,0x54,0x20))) | Should Be ""
    }
    It "returns empty (does not throw) on a truncated record" {
        $bytes = New-ClientHelloWithSni "pornhub.com"
        (Get-TlsSni -Bytes $bytes -Length 20) | Should Be ""
    }
}

Describe "Get-HttpHost" {
    It "extracts the host from an HTTP request" {
        $req = "GET / HTTP/1.1`r`nHost: xhamster.com`r`nUser-Agent: x`r`n`r`n"
        (Get-HttpHost -Bytes ([System.Text.Encoding]::ASCII.GetBytes($req))) | Should Be "xhamster.com"
    }
    It "strips a port from the Host header" {
        $req = "GET / HTTP/1.1`r`nHost: pornhub.com:443`r`n`r`n"
        (Get-HttpHost -Bytes ([System.Text.Encoding]::ASCII.GetBytes($req))) | Should Be "pornhub.com"
    }
    It "returns empty when there is no Host header" {
        (Get-HttpHost -Bytes ([System.Text.Encoding]::ASCII.GetBytes("GET / HTTP/1.1`r`n`r`n"))) | Should Be ""
    }
}
