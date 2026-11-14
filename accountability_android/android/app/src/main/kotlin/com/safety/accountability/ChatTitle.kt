package com.safety.accountability

// Pure logic behind the Telegram watch: pick the chat/channel title out of the toolbar's text nodes,
// decide when a visit is worth logging, and read the stored log back. Split out from TelegramWatch so
// it's unit-testable without a device (same pattern as WatchdogDecision).
object ChatTitle {
    // One on-screen text node: what it says and where it sits (screen pixels).
    data class Node(val text: String, val top: Int, val left: Int)

    // Toolbar titles that aren't a chat — the chat list, settings, search. Never logged.
    private val NOT_A_CHAT = setOf(
        "telegram", "telegram x", "plus messenger", "chats", "settings",
        "contacts", "calls", "search", "new message", "edit"
    )

    // The chat/channel name is the TOPMOST text in the toolbar band. Telegram draws custom views whose
    // resource ids differ across versions and forks, so screen position is the only stable signal; the
    // subtitle ("1 234 subscribers", "last seen recently") always sits below the title, so topmost wins.
    // Ties break left-to-right, since the title follows the back arrow.
    // ponytail: positional heuristic tuned on stock Telegram. If a fork puts its title elsewhere, widen
    // the band or match that fork's toolbar view id here — don't build a general view-tree parser.
    fun pick(nodes: List<Node>): String? {
        val best = nodes.filter { it.text.isNotBlank() }
            .minWithOrNull(compareBy({ it.top }, { it.left })) ?: return null
        val t = best.text.trim()
        if (t.length > 64) return null                 // a message that bled into the band, not a title
        if (t.lowercase() in NOT_A_CHAT) return null
        return t
    }

    // Telegram fires window events constantly while you scroll, so re-log the same title only after a
    // real gap. Keeps a 40-minute session at a couple of lines instead of a few hundred.
    fun shouldRecord(prevTitle: String?, prevMs: Long, title: String, nowMs: Long): Boolean =
        title != prevTitle || nowMs - prevMs >= REPEAT_MS

    // Stored form is one "<epochMillis>\t<title>" per line; anything malformed is dropped.
    fun parse(lines: List<String>): List<Pair<Long, String>> = lines.mapNotNull { line ->
        val i = line.indexOf('\t')
        if (i <= 0) return@mapNotNull null
        val ts = line.substring(0, i).toLongOrNull() ?: return@mapNotNull null
        val title = line.substring(i + 1)
        if (title.isBlank()) null else ts to title
    }

    fun within(entries: List<Pair<Long, String>>, nowMs: Long, windowMs: Long): List<Pair<Long, String>> =
        entries.filter { nowMs - it.first in 0..windowMs }

    const val REPEAT_MS = 5 * 60 * 1000L
}
