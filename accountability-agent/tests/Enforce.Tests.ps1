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
