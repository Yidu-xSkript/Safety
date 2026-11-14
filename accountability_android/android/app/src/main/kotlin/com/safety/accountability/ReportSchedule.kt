package com.safety.accountability

// When the digest goes out. EAT (UTC+3) is BAKED IN, not read from the device clock — the phone's
// timezone is user-editable in Settings, so reading it would let the digest times be shifted out from
// under the witness. Pure arithmetic on epoch millis, so it's unit-testable.
//
// Two digests a day, at 07:30 and 00:00 EAT. Each covers everything since the previous one.
object ReportSchedule {
    const val EAT_OFFSET_MS = 3 * 60 * 60 * 1000L
    const val DAY_MS = 24 * 60 * 60 * 1000L
    const val TICK_MS = 15 * 60 * 1000L
    private const val MORNING_MIN = 7 * 60 + 30
    // A phone that was off for days shouldn't ask NextDNS/usage stats for an enormous window.
    const val MAX_LOOKBACK_MS = 24 * 60 * 60 * 1000L

    // Minutes since EAT midnight, 0..1439.
    fun eatMinuteOfDay(epochMs: Long): Int = (((epochMs + EAT_OFFSET_MS) / 60_000L) % 1440L).toInt()

    fun eatClock(epochMs: Long): String {
        val m = eatMinuteOfDay(epochMs)
        return "${(m / 60).toString().padStart(2, '0')}:${(m % 60).toString().padStart(2, '0')}"
    }

    fun range(fromMs: Long, toMs: Long) = "${eatClock(fromMs)}–${eatClock(toMs)}"

    // The most recent digest time (07:30 or 00:00 EAT) at or before now.
    fun lastBoundary(nowMs: Long): Long {
        val eat = nowMs + EAT_OFFSET_MS
        val dayStart = eat - eat % DAY_MS
        val b = if (eatMinuteOfDay(nowMs) >= MORNING_MIN) dayStart + MORNING_MIN * 60_000L else dayStart
        return b - EAT_OFFSET_MS
    }

    // Due once a boundary has passed since the last digest. Comparing against the last SEND (not
    // "is it exactly 07:30 right now") means a delayed tick or a phone that was off still sends late
    // rather than skipping a digest.
    fun isDue(nowMs: Long, lastSentMs: Long): Boolean = lastBoundary(nowMs) > lastSentMs

    // Sleep to the next :00/:15/:30/:45 boundary rather than 15 minutes from whenever the service
    // started, so ticks stay aligned to the clock across restarts. UTC+3 is a whole number of
    // quarter-hours, so a UTC boundary is an EAT boundary.
    fun msUntilNextTick(epochMs: Long): Long = TICK_MS - (epochMs % TICK_MS)
}
