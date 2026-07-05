Import-Module "$PSScriptRoot/../src/Enforce.psm1" -Force

Describe "Set-HostsBlock" {
    $tmp = Join-Path $env:TEMP "hosts-test.txt"

    It "adds a managed block with the given domains" {
        "127.0.0.1 localhost" | Set-Content -Path $tmp -Encoding ASCII
        Set-HostsBlock -Domains @("instagram.com","tiktok.com") -HostsPath $tmp
        $c = Get-Content $tmp
        ($c -contains "127.0.0.1 instagram.com") | Should Be $true
        ($c -contains "127.0.0.1 tiktok.com")    | Should Be $true
        ($c -contains "127.0.0.1 localhost")      | Should Be $true
    }
    It "replaces the previous managed block instead of duplicating it" {
        Set-HostsBlock -Domains @("reddit.com") -HostsPath $tmp
        $c = Get-Content $tmp
        ($c -contains "127.0.0.1 reddit.com")   | Should Be $true
        ($c -contains "127.0.0.1 instagram.com")| Should Be $false
        (@($c | Where-Object { $_ -eq "# BEGIN AccountabilityAgent" }).Count) | Should Be 1
    }
    It "clears all managed entries when given no domains" {
        Set-HostsBlock -Domains @() -HostsPath $tmp
        $c = Get-Content $tmp
        ($c -contains "127.0.0.1 reddit.com") | Should Be $false
        ($c -contains "127.0.0.1 localhost")  | Should Be $true
    }
    It "returns true when it changes the file and false when already in sync" {
        "127.0.0.1 localhost" | Set-Content -Path $tmp -Encoding ASCII
        (Set-HostsBlock -Domains @("a.com") -HostsPath $tmp) | Should Be $true   # first write
        (Set-HostsBlock -Domains @("a.com") -HostsPath $tmp) | Should Be $false  # idempotent, no change
        # Simulate external tampering: strip the block, then it must rewrite (return true).
        "127.0.0.1 localhost" | Set-Content -Path $tmp -Encoding ASCII
        (Set-HostsBlock -Domains @("a.com") -HostsPath $tmp) | Should Be $true
    }
    It "writes SafeSearch redirect entries as '<ip> <domain>'" {
        "127.0.0.1 localhost" | Set-Content -Path $tmp -Encoding ASCII
        Set-HostsBlock -Domains @("porn.com") -Redirects @{ "www.google.com" = "216.239.38.120" } -HostsPath $tmp
        $c = Get-Content $tmp
        ($c -contains "127.0.0.1 porn.com")            | Should Be $true
        ($c -contains "216.239.38.120 www.google.com") | Should Be $true
    }
    It "produces deterministic output for the same redirects (stable for hash checks)" {
        "127.0.0.1 localhost" | Set-Content -Path $tmp -Encoding ASCII
        Set-HostsBlock -Domains @("a.com") -Redirects @{ "www.bing.com"="1.1.1.1"; "www.google.com"="2.2.2.2" } -HostsPath $tmp
        $first = (Get-Content $tmp) -join "`n"
        (Set-HostsBlock -Domains @("a.com") -Redirects @{ "www.bing.com"="1.1.1.1"; "www.google.com"="2.2.2.2" } -HostsPath $tmp) | Should Be $false
        ((Get-Content $tmp) -join "`n") | Should Be $first
    }
    It "does not swallow the file when a BEGIN marker has no matching END" {
        @("127.0.0.1 localhost", "# BEGIN AccountabilityAgent", "127.0.0.1 orphan.com", "10.0.0.1 keepme") |
            Set-Content -Path $tmp -Encoding ASCII
        Set-HostsBlock -Domains @("x.com") -HostsPath $tmp
        $c = Get-Content $tmp
        ($c -contains "10.0.0.1 keepme")  | Should Be $true   # survived the orphan BEGIN
        ($c -contains "127.0.0.1 localhost") | Should Be $true
        ($c -contains "127.0.0.1 x.com")  | Should Be $true
        (@($c | Where-Object { $_ -eq "# BEGIN AccountabilityAgent" }).Count) | Should Be 1
    }

    Remove-Item $tmp -ErrorAction SilentlyContinue
}

Describe "Set-IncognitoDisabled" {
    # Target a writable user hive so the test needs no admin and never touches real HKLM policy.
    $root = "HKCU:\Software\AA-IncognitoTest"
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue

    It "writes the disable value (1) for every browser family" {
        Set-IncognitoDisabled -PolicyRoot $root
        (Get-ItemProperty "$root\Google\Chrome").IncognitoModeAvailability      | Should Be 1
        (Get-ItemProperty "$root\Microsoft\Edge").InPrivateModeAvailability      | Should Be 1
        (Get-ItemProperty "$root\BraveSoftware\Brave").IncognitoModeAvailability | Should Be 1
        (Get-ItemProperty "$root\Chromium").IncognitoModeAvailability            | Should Be 1
        (Get-ItemProperty "$root\Mozilla\Firefox").DisablePrivateBrowsing        | Should Be 1
    }
    It "returns true when it must fix a key and false when already in sync (drives tamper alert)" {
        Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
        (Set-IncognitoDisabled -PolicyRoot $root) | Should Be $true    # first write
        (Set-IncognitoDisabled -PolicyRoot $root) | Should Be $false   # idempotent, nothing to fix
        # Simulate a user re-enabling incognito: it must re-disable and report the change.
        Set-ItemProperty -Path "$root\Google\Chrome" -Name IncognitoModeAvailability -Value 0 -Type DWord
        (Set-IncognitoDisabled -PolicyRoot $root) | Should Be $true
        (Get-ItemProperty "$root\Google\Chrome").IncognitoModeAvailability | Should Be 1
    }

    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "Select-TorProcess" {
    It "picks the tor daemon and Tor's firefox, sparing a normal Firefox and other browsers" {
        $procs = @(
            [pscustomobject]@{ Name='tor';     Id=1; Path='C:\Users\x\Tor Browser\Browser\TorBrowser\Tor\tor.exe' }
            [pscustomobject]@{ Name='firefox'; Id=2; Path='C:\Users\x\Tor Browser\Browser\firefox.exe' }
            [pscustomobject]@{ Name='firefox'; Id=3; Path='C:\Program Files\Mozilla Firefox\firefox.exe' }
            [pscustomobject]@{ Name='chrome';  Id=4; Path='C:\Program Files\Google\Chrome\Application\chrome.exe' }
        )
        $hit = Select-TorProcess -Processes $procs
        @($hit).Count            | Should Be 2
        ($hit.Id -contains 1)    | Should Be $true    # tor daemon
        ($hit.Id -contains 2)    | Should Be $true    # Tor's firefox
        ($hit.Id -contains 3)    | Should Be $false   # normal Firefox spared
        ($hit.Id -contains 4)    | Should Be $false   # Chrome untouched
    }
    It "spares a firefox with an unreadable (empty) path - only kills what it can confirm is Tor" {
        $procs = @([pscustomobject]@{ Name='firefox'; Id=5; Path=$null })
        @(Select-TorProcess -Processes $procs).Count | Should Be 0
    }
    It "returns nothing when no Tor process is present" {
        $procs = @([pscustomobject]@{ Name='chrome'; Id=6; Path='C:\chrome.exe' })
        @(Select-TorProcess -Processes $procs).Count | Should Be 0
    }
}
