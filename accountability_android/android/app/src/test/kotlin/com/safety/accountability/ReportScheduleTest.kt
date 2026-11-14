package com.safety.accountability
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReportScheduleTest {
    // 1_755_216_000_000 is 2025-08-15 00:00 UTC; back off 3h to land on EAT midnight, then build
    // EAT wall-clock times from there. Only the time-of-day matters to these assertions.
    private val eatMidnight = 1_755_216_000_000L - ReportSchedule.EAT_OFFSET_MS
    private fun eat(h: Int, m: Int = 0) = eatMidnight + h * 3_600_000L + m * 60_000L

    @Test fun morningWindowIsInclusiveOfBothEnds() {
        assertTrue(ReportSchedule.isReportTime(eat(4, 0)))     // 04:00 opens it
        assertTrue(ReportSchedule.isReportTime(eat(6, 15)))
        assertTrue(ReportSchedule.isReportTime(eat(7, 30)))    // 07:30 still in
    }

    @Test fun eveningWindowRunsFromThreePmToMidnight() {
        assertTrue(ReportSchedule.isReportTime(eat(15, 0)))
        assertTrue(ReportSchedule.isReportTime(eat(21, 45)))
        assertTrue(ReportSchedule.isReportTime(eat(23, 45)))   // last tick before midnight
    }

    @Test fun quietHoursSendNothing() {
        assertFalse(ReportSchedule.isReportTime(eat(0, 0)))    // midnight closes the evening window
        assertFalse(ReportSchedule.isReportTime(eat(3, 45)))   // just before the morning window
        assertFalse(ReportSchedule.isReportTime(eat(7, 45)))   // just after it
        assertFalse(ReportSchedule.isReportTime(eat(12, 0)))
        assertFalse(ReportSchedule.isReportTime(eat(14, 45)))  // just before the evening window
    }

    @Test fun minuteOfDayIsMeasuredInEatNotUtc() {
        assertEquals(0, ReportSchedule.eatMinuteOfDay(eat(0, 0)))
        assertEquals(900, ReportSchedule.eatMinuteOfDay(eat(15, 0)))    // 15:00 EAT == 12:00 UTC
        assertEquals(1439, ReportSchedule.eatMinuteOfDay(eat(23, 59)))
    }

    @Test fun ticksAlignToQuarterHourBoundaries() {
        assertEquals(5 * 60_000L, ReportSchedule.msUntilNextTick(eat(15, 10)))
        assertEquals(15 * 60_000L, ReportSchedule.msUntilNextTick(eat(15, 15)))  // never sleeps zero
        assertEquals(60_000L, ReportSchedule.msUntilNextTick(eat(15, 44)))
    }

    @Test fun labelReadsAsAPeriod() {
        assertEquals("15 min", ReportSchedule.label(ReportSchedule.TICK_MS))
        assertEquals("7h 30m", ReportSchedule.label(7 * 3_600_000L + 30 * 60_000L))
        assertEquals("8h", ReportSchedule.label(8 * 3_600_000L))
        assertEquals("1 min", ReportSchedule.label(0L))         // never "0 min"
    }
}
