Import-Module "$PSScriptRoot/../src/Policy.psm1" -Force

$policies = @(
    [pscustomobject]@{ name="Instagram"; policy="block";      domains=@("instagram.com"); titleMatch="Instagram"; dailyLimitMinutes=$null },
    [pscustomobject]@{ name="TikTok";    policy="time-box";   domains=@("tiktok.com");    titleMatch="TikTok";    dailyLimitMinutes=20 },
    [pscustomobject]@{ name="Reddit";    policy="report-only";domains=@("reddit.com");    titleMatch="Reddit";    dailyLimitMinutes=$null }
)

Describe "Get-AppForTitle" {
    It "matches an app by title substring" {
        (Get-AppForTitle -Title "TikTok - Chrome" -Policies $policies).name | Should Be "TikTok"
    }
    It "returns null when nothing matches" {
        Get-AppForTitle -Title "Visual Studio Code" -Policies $policies | Should Be $null
    }
}

Describe "Test-OverDailyLimit" {
    It "is over when accrued exceeds the limit" { Test-OverDailyLimit -AccruedMinutes 25 -LimitMinutes 20 | Should Be $true }
    It "is not over when under the limit"      { Test-OverDailyLimit -AccruedMinutes 5  -LimitMinutes 20 | Should Be $false }
    It "is never over when limit is null"      { Test-OverDailyLimit -AccruedMinutes 999 -LimitMinutes $null | Should Be $false }
}

Describe "Get-DesiredHostsEntries" {
    It "always blocks 'block' apps and adds over-limit time-box apps" {
        $entries = Get-DesiredHostsEntries -Policies $policies -OverLimitApps @("TikTok")
        # Pester 3.4 'Should Contain' is a file-content assertion, so use -contains for
        # collection membership (preserves the intent: instagram+tiktok in, reddit out).
        ($entries -contains "instagram.com") | Should Be $true
        ($entries -contains "tiktok.com")    | Should Be $true
        ($entries -contains "reddit.com")    | Should Be $false
    }
}
