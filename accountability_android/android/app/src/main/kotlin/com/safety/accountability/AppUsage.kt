package com.safety.accountability

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Process

// Which apps were used and for how long, from Android's Usage Access (the data screen-time apps use).
// Tells you the app + foreground time — NOT what was done inside it (Android exposes no more than that
// without accessibility/root). Needs the one-time "Usage access" grant; reports empty otherwise.
object AppUsage {
    fun hasAccess(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        @Suppress("DEPRECATION")
        val mode = ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // "App label  Nm" lines for apps with meaningful foreground time in the last windowMs, most first.
    fun report(ctx: Context, windowMs: Long, windowLabel: String): String {
        if (!hasAccess(ctx)) return "App usage — needs the 'Usage access' permission (grant it in the app)."
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val stats = usm.queryAndAggregateUsageStats(end - windowMs, end)
        val pm = ctx.packageManager
        val rows = stats.values
            .filter { it.totalTimeInForeground > 30_000L }        // ignore <30s blips / background
            .sortedByDescending { it.totalTimeInForeground }
            .map { u ->
                val label = try { pm.getApplicationLabel(pm.getApplicationInfo(u.packageName, 0)).toString() }
                            catch (e: Exception) { u.packageName }
                val mins = u.totalTimeInForeground / 60_000L
                val secs = (u.totalTimeInForeground / 1000L) % 60
                "$label  ${if (mins > 0) "${mins}m" else "${secs}s"}"
            }
        return if (rows.isEmpty()) "App usage — last $windowLabel\nNo app activity."
               else "App usage — last $windowLabel\n\n" + rows.joinToString("\n")
    }
}
