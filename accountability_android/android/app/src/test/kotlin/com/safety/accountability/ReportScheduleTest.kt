package com.safety.accountability
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReportScheduleTest {
    // 1_755_216_000_000 is 2025-08-15 00:00 UTC; back off 3h to land on EAT midnight, then build
    // EAT wall-clock times from there. Only the time-of-day matters to these assertions.
    private val eatMidnight = 1_755_216_000_000L - ReportSchedule.EAT_OFFSET_MS
    private fun eat(h: Int, m: Int = 0, day: Int = 0) =
        eatMidnight + day * ReportSchedule.DAY_MS + h * 3_600_000L + m * 60_000L

    @Test fun boundaryIsTheLatestOfMidnightAndSevenThirty() {
        assertEquals(eat(0, 0), ReportSchedule.lastBoundary(eat(0, 0)))
        assertEquals(eat(0, 0), ReportSchedule.lastBoundary(eat(7, 29)))
        assertEquals(eat(7, 30), ReportSchedule.lastBoundary(eat(7, 30)))
        assertEquals(eat(7, 30), ReportSchedule.lastBoundary(eat(23, 59)))
    }

    @Test fun noDigestUntilABoundaryPasses() {
        val sentAtMidnight = eat(0, 5)
        assertFalse(ReportSchedule.isDue(eat(3, 0), sentAtMidnight))
        assertFalse(ReportSchedule.isDue(eat(7, 29), sentAtMidnight))
        assertTrue(ReportSchedule.isDue(eat(7, 30), sentAtMidnight))
    }

    @Test fun oneDigestPerBoundaryEvenIfTicksKeepComing() {
        val sentMorning = eat(7, 31)
        assertFalse(ReportSchedule.isDue(eat(7, 45), sentMorning))
        assertFalse(ReportSchedule.isDue(eat(23, 45), sentMorning))
        assertTrue(ReportSchedule.isDue(eat(0, 0, day = 1), sentMorning))   // next midnight
    }

    @Test fun aLateTickStillSendsTheMissedDigest() {
        // phone was off over 07:30 and came back at 09:10
        assertTrue(ReportSchedule.isDue(eat(9, 10), eat(0, 2)))
    }

    @Test fun minuteOfDayIsMeasuredInEatNotUtc() {
        assertEquals(0, ReportSchedule.eatMinuteOfDay(eat(0, 0)))
        assertEquals(900, ReportSchedule.eatMinuteOfDay(eat(15, 0)))    // 15:00 EAT == 12:00 UTC
        assertEquals(1439, ReportSchedule.eatMinuteOfDay(eat(23, 59)))
    }

    @Test fun clockAndRangeReadInEat() {
        assertEquals("07:30", ReportSchedule.eatClock(eat(7, 30)))
        assertEquals("00:00–07:30", ReportSchedule.range(eat(0, 0), eat(7, 30)))
    }

    @Test fun ticksAlignToQuarterHourBoundaries() {
        assertEquals(5 * 60_000L, ReportSchedule.msUntilNextTick(eat(15, 10)))
        assertEquals(15 * 60_000L, ReportSchedule.msUntilNextTick(eat(15, 15)))  // never sleeps zero
        assertEquals(60_000L, ReportSchedule.msUntilNextTick(eat(15, 44)))
    }
}
