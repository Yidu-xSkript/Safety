function Get-DueMilestone {
    # Highest milestone reached (<= StreakDays) that hasn't been notified yet (> LastNotified). 0 if none.
    param([int]$StreakDays, [int[]]$Milestones = @(7,30,90), [int]$LastNotified = 0)
    $due = 0
    foreach ($m in ($Milestones | Sort-Object)) {
        if ($StreakDays -ge $m -and $m -gt $LastNotified) { $due = $m }
    }
    return $due
}

function Update-DayState {
    # Roll the streak forward when the calendar day changes. Pure: returns a new hashtable.
    # A completed clean day increments the streak; a flagged day resets streak + notified level.
    param([Parameter(Mandatory)]$State, [Parameter(Mandatory)][string]$Today)
    $day = "$($State.Day)"; $flagged = [bool]$State.Flagged
    $streak = [int]$State.StreakDays; $notified = [int]$State.LastNotified
    if ($day -ne $Today) {
        if ($day) {
            if ($flagged) { $streak = 0; $notified = 0 } else { $streak = $streak + 1 }
        }
        $day = $Today; $flagged = $false
    }
    return @{ Day = $day; Flagged = $flagged; StreakDays = $streak; LastNotified = $notified }
}

Export-ModuleMember -Function Get-DueMilestone, Update-DayState
