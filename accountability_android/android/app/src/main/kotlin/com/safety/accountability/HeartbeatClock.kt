package com.safety.accountability
import android.content.Context
object HeartbeatClock {
    private const val KEY = "lastHeartbeatDay"
    private fun today(): Long = System.currentTimeMillis() / 86_400_000L
    fun isDue(ctx: Context): Boolean {
        val p = ctx.getSharedPreferences("aa_hb", Context.MODE_PRIVATE)
        return p.getLong(KEY, 0) != today()
    }
    fun markSent(ctx: Context) {
        ctx.getSharedPreferences("aa_hb", Context.MODE_PRIVATE).edit().putLong(KEY, today()).apply()
    }
}
