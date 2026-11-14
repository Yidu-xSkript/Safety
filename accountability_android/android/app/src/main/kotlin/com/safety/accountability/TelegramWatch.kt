package com.safety.accountability

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Rect
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

// Reads the chat/channel TITLE from Telegram's toolbar so the hourly witness report can name what was
// opened. Telegram encrypts everything under its own pinned-key MTProto and multiplexes every channel
// over the same connections, so no network filter can tell which channel is open (and an MTProto proxy
// skips DNS entirely) — the on-screen title is the only signal that exists. Detection, not blocking.
//
// TITLES ONLY, enforced three ways: the OS restricts us to Telegram alone via android:packageNames in
// res/xml/telegram_watch.xml; collect() refuses to descend below the toolbar band, so the message list
// is never walked; and only node.text is read, never contentDescription. No message body is read or
// stored. Revocable by hand in Settings > Accessibility — WatchdogWorker alerts the witness if it is.
class TelegramWatch : AccessibilityService() {
    private var lastTitle: String? = null
    private var lastMs = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        markEverEnabled(this)     // lets the watchdog tell "revoked" apart from "never granted"
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) return
        val root = rootInActiveWindow ?: return
        // Status bar + a 56dp toolbar. Deliberately tight: the first message row starts just below it.
        val band = (88 * resources.displayMetrics.density).toInt()
        val title = ChatTitle.pick(collect(root, band)) ?: return
        val now = System.currentTimeMillis()
        if (!ChatTitle.shouldRecord(lastTitle, lastMs, title, now)) return
        lastTitle = title
        lastMs = now
        record(this, now, title)
    }

    override fun onInterrupt() {}

    // Text nodes inside the toolbar band only. A subtree that starts below the band is not descended
    // into, so message text is never visited. Ignoring contentDescription drops icons/buttons for free.
    private fun collect(root: AccessibilityNodeInfo, band: Int): List<ChatTitle.Node> {
        val out = mutableListOf<ChatTitle.Node>()
        val r = Rect()
        fun walk(n: AccessibilityNodeInfo?, depth: Int) {
            if (n == null || depth > 12 || out.size >= 40) return
            n.getBoundsInScreen(r)
            if (r.top > band) return
            val top = r.top
            val left = r.left
            val t = n.text?.toString()
            if (!t.isNullOrBlank()) out.add(ChatTitle.Node(t, top, left))
            for (i in 0 until n.childCount) walk(n.getChild(i), depth + 1)
        }
        walk(root, 0)
        return out
    }

    companion object {
        private const val PREFS = "aa_telegram_watch"
        private const val KEY_LOG = "visits"
        private const val KEY_EVER = "everEnabled"
        private const val MAX_LINES = 300

        private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        @Synchronized private fun record(ctx: Context, ms: Long, title: String) {
            val p = prefs(ctx)
            val clean = title.replace('\t', ' ').replace('\n', ' ')
            val lines = (p.getString(KEY_LOG, "") ?: "").split("\n").filter { it.isNotBlank() }
            p.edit().putString(KEY_LOG, (lines + "$ms\t$clean").takeLast(MAX_LINES).joinToString("\n")).apply()
        }

        fun markEverEnabled(ctx: Context) = prefs(ctx).edit().putBoolean(KEY_EVER, true).apply()
        fun wasEverEnabled(ctx: Context) = prefs(ctx).getBoolean(KEY_EVER, false)

        // Is the watch switched on right now? Reads the OS list of enabled accessibility services.
        fun isEnabled(ctx: Context): Boolean {
            val on = Settings.Secure.getString(
                ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
            return on.contains("${ctx.packageName}/${TelegramWatch::class.java.name}")
        }

        // Section for the hourly witness email. Drops (and prunes) anything older than the window, so
        // the log can't grow unbounded between reports. Empty string when the watch isn't granted.
        @Synchronized fun report(ctx: Context, windowMs: Long, windowLabel: String): String {
            if (!isEnabled(ctx)) return ""
            val p = prefs(ctx)
            val recent = ChatTitle.within(
                ChatTitle.parse((p.getString(KEY_LOG, "") ?: "").split("\n")),
                System.currentTimeMillis(), windowMs)
            p.edit().putString(KEY_LOG, recent.joinToString("\n") { "${it.first}\t${it.second}" }).apply()
            val head = "Telegram chats opened — last $windowLabel"
            if (recent.isEmpty()) return "$head\nNone."
            // EAT, to match the report schedule — NOT the device timezone, which is user-editable and
            // would otherwise make the timestamps disagree with the windows the report is sent in.
            val fmt = SimpleDateFormat("HH:mm", Locale.US)
            fmt.timeZone = TimeZone.getTimeZone("Africa/Nairobi")
            return "$head\n\n" + recent.joinToString("\n") { "${fmt.format(Date(it.first))}  ${it.second}" }
        }
    }
}
