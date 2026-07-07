Import-Module "$PSScriptRoot/../src/Common.psm1" -Force
Import-Module "$PSScriptRoot/../src/Detection.psm1" -Force

Describe "Get-AgentConfig" {
    It "parses required fields from a config file" {
        $tmp = Join-Path $env:TEMP "cfg-test.json"
        '{ "witnessEmail": "w@x.com", "approvedVpnIps": ["1.2.3.4"], "reportIntervalMinutes": 60 }' |
            Set-Content -Path $tmp -Encoding utf8
        $cfg = Get-AgentConfig -Path $tmp
        $cfg.witnessEmail | Should Be "w@x.com"
        $cfg.approvedVpnIps[0] | Should Be "1.2.3.4"
        Remove-Item $tmp
    }
}

Describe "Password hashing (uninstall password)" {
    It "verifies a correct password" {
        $s = New-PasswordHash -Password "hunter2" -Salt "abc"
        Test-PasswordHash -Password "hunter2" -Stored $s | Should Be $true
    }
    It "rejects a wrong password" {
        $s = New-PasswordHash -Password "hunter2" -Salt "abc"
        Test-PasswordHash -Password "nope" -Stored $s | Should Be $false
    }
    It "never stores the raw password and uses salt:hash form" {
        $s = New-PasswordHash -Password "hunter2" -Salt "abc"
        $s.Contains("hunter2") | Should Be $false
        ($s -split ':').Count | Should Be 2
    }
    It "rejects a malformed stored hash" {
        Test-PasswordHash -Password "x" -Stored "not-a-valid-hash" | Should Be $false
    }
}

Describe "Test-UnapprovedVpn" {
    $approved = @("198.51.100.10")

    It "returns false when no VPN adapter is present" {
        Test-UnapprovedVpn -VpnAdapterPresent $false -ActiveRemoteIps @("8.8.8.8") -ApprovedIps $approved | Should Be $false
    }
    It "returns false when the VPN connects to an approved endpoint" {
        Test-UnapprovedVpn -VpnAdapterPresent $true -ActiveRemoteIps @("198.51.100.10","1.1.1.1") -ApprovedIps $approved | Should Be $false
    }
    It "returns true when a VPN is up and no approved endpoint is in use" {
        Test-UnapprovedVpn -VpnAdapterPresent $true -ActiveRemoteIps @("203.0.113.9") -ApprovedIps $approved | Should Be $true
    }
    It "returns true when a VPN is up and there are no active connections" {
        Test-UnapprovedVpn -VpnAdapterPresent $true -ActiveRemoteIps @() -ApprovedIps $approved | Should Be $true
    }
}

Describe "Test-HeartbeatStale" {
    It "is stale when the last beat is older than the threshold" {
        Test-HeartbeatStale -LastBeat (Get-Date).AddSeconds(-600) -Now (Get-Date) -ThresholdSeconds 180 | Should Be $true
    }
    It "is fresh when the last beat is within the threshold" {
        Test-HeartbeatStale -LastBeat (Get-Date).AddSeconds(-30) -Now (Get-Date) -ThresholdSeconds 180 | Should Be $false
    }
    It "is stale when there is no last beat" {
        Test-HeartbeatStale -LastBeat $null -Now (Get-Date) -ThresholdSeconds 180 | Should Be $true
    }
}
