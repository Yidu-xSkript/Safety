Import-Module "$PSScriptRoot/../src/Common.psm1" -Force

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
