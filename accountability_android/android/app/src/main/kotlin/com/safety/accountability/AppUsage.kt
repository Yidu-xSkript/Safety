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

    // (app label, foreground ms) for apps used for more than 30s in the last windowMs. Empty without access.
    fun usage(ctx: Context, windowMs: Long): List<Pair<String, Long>> {
        if (!hasAccess(ctx)) return emptyList()
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val pm = ctx.packageManager
        return usm.queryAndAggregateUsageStats(end - windowMs, end).values
            .filter { it.totalTimeInForeground > 30_000L }        // ignore <30s blips / background
            .map { u ->
                val label = try { pm.getApplicationLabel(pm.getApplicationInfo(u.packageName, 0)).toString() }
                            catch (e: Exception) { u.packageName }
                label to u.totalTimeInForeground
            }
    }
}
