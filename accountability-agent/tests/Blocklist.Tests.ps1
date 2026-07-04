Import-Module "$PSScriptRoot/../src/Blocklist.psm1" -Force

Describe "ConvertFrom-HostsList" {
    It "extracts domains from hosts-format lines" {
        $t = "0.0.0.0 pornhub.com`n127.0.0.1 xvideos.com"
        $d = ConvertFrom-HostsList -Text $t
        ($d -contains "pornhub.com") | Should Be $true
        ($d -contains "xvideos.com") | Should Be $true
    }
    It "accepts plain domain lines" {
        (ConvertFrom-HostsList -Text "badsite.com") | Should Be "badsite.com"
    }
    It "skips comments, blanks, localhost and bare IPs" {
        $t = "# comment`n`n127.0.0.1 localhost`n8.8.8.8`n0.0.0.0 evil.com"
        $d = @(ConvertFrom-HostsList -Text $t)
        ($d -contains "evil.com") | Should Be $true
        ($d -contains "localhost") | Should Be $false
        ($d -contains "8.8.8.8")   | Should Be $false
        $d.Count | Should Be 1
    }
    It "lower-cases and de-duplicates" {
        $d = @(ConvertFrom-HostsList -Text "0.0.0.0 Porn.com`n0.0.0.0 porn.com")
        $d.Count | Should Be 1
        $d[0] | Should Be "porn.com"
    }
}

Describe "Update-PornBlocklist (built-in, no network)" {
    It "writes the built-in curated list when no Url is given" {
        $tmp = Join-Path $env:TEMP "porn-builtin-test.txt"
        Remove-Item $tmp -ErrorAction SilentlyContinue
        (Update-PornBlocklist -Url "" -CachePath $tmp -MaxAgeHours 24) | Should Be $true
        $d = @(Get-PornBlocklist -CachePath $tmp)
        ($d -contains "pornhub.com") | Should Be $true
        ($d.Count -gt 20) | Should Be $true
        ($d.Count -lt 20000) | Should Be $true   # curated, not a giant dump
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
    It "is a no-op when the cache is fresh" {
        $tmp = Join-Path $env:TEMP "porn-fresh-test.txt"
        Update-PornBlocklist -Url "" -CachePath $tmp -MaxAgeHours 24 | Out-Null
        (Update-PornBlocklist -Url "" -CachePath $tmp -MaxAgeHours 24) | Should Be $false
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

Describe "Get-BuiltInPornDomains" {
    It "returns a curated, non-empty, bounded list" {
        $d = @(Get-BuiltInPornDomains)
        ($d.Count -gt 20) | Should Be $true
        ($d.Count -lt 1000) | Should Be $true
        ($d -contains "xvideos.com") | Should Be $true
    }
}

Describe "Get-PornBlocklist" {
    It "returns an empty array when no cache exists" {
        (Get-PornBlocklist -CachePath (Join-Path $env:TEMP "no-such-porn-cache.txt")).Count | Should Be 0
    }
    It "reads cached domains" {
        $tmp = Join-Path $env:TEMP "porn-cache-test.txt"
        "a.com`nb.com" | Set-Content -Path $tmp -Encoding ASCII
        $d = @(Get-PornBlocklist -CachePath $tmp)
        $d.Count | Should Be 2
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}
