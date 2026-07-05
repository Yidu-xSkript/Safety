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
        $body | Should Match "2 distinct activities"
    }
    It "says so when there is no activity" {
        (Format-WitnessReport -Samples @() -Since "x") | Should Match "No activity"
    }
}

Describe "Group-ActivitySamples" {
    It "groups repeated titles under one heading with all access times" {
        $lines = @(
            "2026-07-01T10:00:15 | Research porn addiction blocker",
            "2026-07-01T10:00:30 | Research porn addiction blocker",
            "2026-07-01T10:00:45 | Research porn addiction blocker"
        )
        $out = Group-ActivitySamples -Lines $lines
        # The title must appear exactly once, followed by its three times on one 'Accessed at' line.
        (@(($out -split "`n") | Where-Object { $_ -eq "Research porn addiction blocker" }).Count) | Should Be 1
        $out | Should Match "Accessed at: 10:00:15, 10:00:30, 10:00:45"
    }
    It "de-duplicates identical timestamps within a group" {
        $lines = @("2026-07-01T10:00:15 | X", "2026-07-01T10:00:15 | X")
        (Group-ActivitySamples -Lines $lines) | Should Match "Accessed at: 10:00:15$"
    }
    It "keeps distinct activities in first-seen order" {
        $lines = @("2026-07-01T10:00:00 | Alpha", "2026-07-01T10:01:00 | Beta", "2026-07-01T10:02:00 | Alpha")
        $out = Group-ActivitySamples -Lines $lines
        $out.IndexOf("Alpha") | Should BeLessThan $out.IndexOf("Beta")
    }
    It "falls back to the raw text when a line has no timestamp separator" {
        (Group-ActivitySamples -Lines @("just a bare title")) | Should Match "just a bare title"
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
    It "labels a DNS fail-safe alert" {
        (Format-AlertEmail -Kind "DnsFailsafe" -Detail "").Subject | Should Match "NextDNS unreachable"
    }
    It "labels an approved-VPN-active alert" {
        (Format-AlertEmail -Kind "ApprovedVpnActive" -Detail "").Subject | Should Match "Approved VPN"
    }
    It "labels an agent-reinstalled alert" {
        (Format-AlertEmail -Kind "AgentReinstalled" -Detail "").Subject | Should Match "re-installed"
    }
}

Describe "Format-SupporterEmail" {
    It "reports the streak without any raw activity data" {
        $e = Format-SupporterEmail -StreakDays 7 -Milestone 7
        $e.Subject | Should Match "7 days"
        $e.Body    | Should Match "clean days"
    }
}
