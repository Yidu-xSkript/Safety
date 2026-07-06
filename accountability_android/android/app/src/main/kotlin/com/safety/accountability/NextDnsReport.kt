package com.safety.accountability

// Formats a batch of queried domains into a readable activity digest — the phone twin of the Windows
// agent's grouped report. Domain-level (NextDNS sees domains, not full URLs/titles): each domain with
// its query count, most-frequent first. Pure -> unit-testable.
object NextDnsReport {
    fun format(domains: List<String>, windowLabel: String): String {
        if (domains.isEmpty()) return "Phone activity — last $windowLabel\nNo domains resolved in this window."
        val counts = domains.groupingBy { it }.eachCount()
        val lines = counts.entries
            .sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key })
            .joinToString("\n") { "${it.key}  x${it.value}" }
        return "Phone activity — last $windowLabel\n" +
            "${counts.size} distinct domains, ${domains.size} queries\n\n$lines"
    }
}
