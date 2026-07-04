Import-Module "$PSScriptRoot/../src/Report.psm1" -Force

Describe "Format-WitnessReport" {
    It "includes each window-title sample line" {
        $samples = @(
            "2026-07-01T10:00:00 | Google Chrome - news",
            "2026-07-01T10:05:00 | Notepad"
        )
        $body = Format-WitnessReport -Samples $samples -Since "2026-07-01T09:00:00"
        $body | Should Match "news"
        $body | Should Match "Notepad"
        $body | Should Match "2 activity samples"
    }
    It "says so when there is no activity" {
        (Format-WitnessReport -Samples @() -Since "x") | Should Match "No activity"
    }
}

Describe "Format-AlertEmail" {
    It "labels an unapproved-VPN alert" {
        (Format-AlertEmail -Kind "UnapprovedVPN" -Detail "203.0.113.9").Subject | Should Match "Unapproved VPN"
    }
    It "labels a time-box alert" {
        (Format-AlertEmail -Kind "TimeBox" -Detail "TikTok").Subject | Should Match "Time-box"
    }
    It "labels a hosts-tamper alert" {
        (Format-AlertEmail -Kind "HostsTamper" -Detail "").Subject | Should Match "block list"
    }
    It "labels a DNS-tamper alert" {
        (Format-AlertEmail -Kind "DnsTamper" -Detail "").Subject | Should Match "DNS"
    }
    It "labels a config-tamper alert" {
        (Format-AlertEmail -Kind "ConfigTamper" -Detail "").Subject | Should Match "config"
    }
}

Describe "Format-SupporterEmail" {
    It "reports the streak without any raw activity data" {
        $e = Format-SupporterEmail -StreakDays 7 -Milestone 7
        $e.Subject | Should Match "7 days"
        $e.Body    | Should Match "clean days"
    }
}
