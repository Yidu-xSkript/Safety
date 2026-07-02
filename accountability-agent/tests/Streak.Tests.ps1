Import-Module "$PSScriptRoot/../src/Streak.psm1" -Force

Describe "Get-DueMilestone" {
    It "returns the first milestone when reached and not notified" {
        Get-DueMilestone -StreakDays 7 -Milestones @(7,30,90) -LastNotified 0 | Should Be 7
    }
    It "returns 0 when already notified for the current level" {
        Get-DueMilestone -StreakDays 8 -Milestones @(7,30,90) -LastNotified 7 | Should Be 0
    }
    It "jumps to a higher milestone once reached" {
        Get-DueMilestone -StreakDays 30 -Milestones @(7,30,90) -LastNotified 7 | Should Be 30
    }
    It "returns 0 before any milestone" {
        Get-DueMilestone -StreakDays 5 -Milestones @(7,30,90) -LastNotified 0 | Should Be 0
    }
}

Describe "Update-DayState" {
    It "increments streak on a clean completed day" {
        $s = @{ Day="20260701"; Flagged=$false; StreakDays=3; LastNotified=0 }
        $r = Update-DayState -State $s -Today "20260702"
        $r.StreakDays | Should Be 4
        $r.Day        | Should Be "20260702"
        $r.Flagged    | Should Be $false
    }
    It "resets streak and notified level after a flagged day" {
        $s = @{ Day="20260701"; Flagged=$true; StreakDays=9; LastNotified=7 }
        $r = Update-DayState -State $s -Today "20260702"
        $r.StreakDays   | Should Be 0
        $r.LastNotified | Should Be 0
    }
    It "does nothing within the same day" {
        $s = @{ Day="20260702"; Flagged=$true; StreakDays=4; LastNotified=0 }
        $r = Update-DayState -State $s -Today "20260702"
        $r.StreakDays | Should Be 4
        $r.Flagged    | Should Be $true
    }
    It "initializes the day without incrementing when there is no prior day" {
        $s = @{ Day=""; Flagged=$false; StreakDays=0; LastNotified=0 }
        $r = Update-DayState -State $s -Today "20260702"
        $r.Day        | Should Be "20260702"
        $r.StreakDays | Should Be 0
    }
}
