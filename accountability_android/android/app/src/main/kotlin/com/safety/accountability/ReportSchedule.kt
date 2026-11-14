package com.safety.accountability

// When the activity report goes out. EAT (UTC+3) is BAKED IN, not read from the device clock — the
// phone's timezone is user-editable in Settings, so reading it would let the reporting windows be
// shifted out from under the witness. Pure arithmetic on epoch millis, so it's unit-testable.
object ReportSchedule {
    const val EAT_OFFSET_MS = 3 * 60 * 60 * 1000L
    const val TICK_MS = 15 * 60 * 1000L
    // A phone that was off for days shouldn't ask NextDNS for an enormous window on the next report.
    const val MAX_LOOKBACK_MS = 12 * 60 * 60 * 1000L

    // Minutes since EAT midnight, 0..1439.
    fun eatMinuteOfDay(epochMs: Long): Int = (((epochMs + EAT_OFFSET_MS) / 60_000L) % 1440L).toInt()

    // Agreed reporting windows, in EAT: 04:00–07:30 and 15:00–00:00.
    fun isReportTime(epochMs: Long): Boolean {
        val m = eatMinuteOfDay(epochMs)
        return m in 240..450 || m >= 900
    }

    // Sleep to the next :00/:15/:30/:45 boundary rather than 15 minutes from whenever the service
    // started, so ticks stay aligned to the clock across restarts. UTC+3 is a whole number of
    // quarter-hours, so a UTC boundary is an EAT boundary.
    fun msUntilNextTick(epochMs: Long): Long = TICK_MS - (epochMs % TICK_MS)

    // Label for the period a report covers: "15 min", "7h 30m".
    fun label(elapsedMs: Long): String {
        val mins = (elapsedMs / 60_000L).coerceAtLeast(1L)
        val h = mins / 60
        val m = mins % 60
        return when {
            h == 0L -> "$m min"
            m == 0L -> "${h}h"
            else -> "${h}h ${m}m"
        }
    }
}
