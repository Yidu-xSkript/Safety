package com.safety.accountability

// The twice-daily witness digest: one short message, verdict first. Pure -> unit-testable.
// Instant alerts (tamper, each porn attempt) are separate and unchanged; this is only the summary.
object Digest {
    private const val MAX_CHATS = 8
    private const val MAX_APPS = 5

    fun dur(ms: Long): String {
        val m = ms / 60_000L
        return if (m >= 60) "${m / 60}h ${(m % 60).toString().padStart(2, '0')}m" else "${m}m"
    }

    // apps: (label, foreground ms). chats: (epoch ms, title) visits. domains: one entry per query.
    // ponytail: porn counts come from the NextDNS log's most recent 1000 rows, so a very busy profile
    // can undercount here — the per-attempt alerts (polled every minute) are what guarantee detection.
    fun build(
        range: String, apps: List<Pair<String, Long>>, chats: List<Pair<Long, String>>,
        watchRevoked: Boolean, domains: List<String>,
    ): String {
        val shown = apps.filter { it.second >= 60_000L }.sortedByDescending { it.second }
        val porn = domains.filter { PornList.isPorn(it) }.groupingBy { it }.eachCount()
            .entries.sortedByDescending { it.value }
        val flags = listOfNotNull(
            if (porn.isNotEmpty()) "⚠️ ${porn.sumOf { it.value }} adult-site attempt(s)" else null,
            if (watchRevoked) "⚠️ Telegram watch off" else null)
        var head = (if (flags.isEmpty()) "✅ Clean" else flags.joinToString(" · ")) + " · $range"
        if (shown.isNotEmpty()) head += " · ${dur(shown.sumOf { it.second })} screen time"

        val out = mutableListOf(head)
        if (porn.isNotEmpty()) out += "Adult sites: " + porn.joinToString(", ") { "${it.key} ×${it.value}" }
        if (chats.isNotEmpty()) {
            val byTitle = chats.groupBy({ it.second }, { it.first })
                .entries.sortedByDescending { it.value.size }
            out += "Telegram:"
            for ((title, times) in byTitle.take(MAX_CHATS)) {
                out += "• $title · ${times.size}x · " +
                    "${ReportSchedule.eatClock(times.minOf { it })}–${ReportSchedule.eatClock(times.maxOf { it })}"
            }
            if (byTitle.size > MAX_CHATS) out += "+${byTitle.size - MAX_CHATS} more"
        }
        if (shown.isNotEmpty()) {
            out += "Apps: " + shown.take(MAX_APPS).joinToString(" · ") { "${it.first} ${dur(it.second)}" }
        }
        val other = domains.filterNot { PornList.isPorn(it) }.toSet().size
        if (other > 0) out += "Other domains: $other"
        return out.joinToString("\n")
    }
}
