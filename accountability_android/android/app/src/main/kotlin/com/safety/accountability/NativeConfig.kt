package com.safety.accountability

import android.content.Context

// Persists the enforcement config to disk so background entry points (WatchdogWorker, BootReceiver,
// a START_STICKY service restart) work in a FRESH process where the Flutter engine never ran and the
// in-memory EnforcementState statics are null. Without this, all background alerting/enforcement dies
// silently after the first process recycle (audit bug #2).
object NativeConfig {
    private const val PREFS = "aa_native_config"
    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(
        ctx: Context, dohUrl: String, witnessEmail: String,
        smtpHost: String, smtpPort: Int, smtpUser: String, smtpPass: String, smtpFrom: String,
        nextDnsApiKey: String, nextDnsProfileId: String,
    ) {
        prefs(ctx).edit()
            .putString("dohUrl", dohUrl).putString("witnessEmail", witnessEmail)
            .putString("smtpHost", smtpHost).putInt("smtpPort", smtpPort)
            .putString("smtpUser", smtpUser).putString("smtpPass", smtpPass)
            .putString("smtpFrom", smtpFrom)
            .putString("nextDnsApiKey", nextDnsApiKey).putString("nextDnsProfileId", nextDnsProfileId)
            .apply()
    }

    // Rebuild EnforcementState (incl. a fresh EmailReporter) from disk if it's empty. Safe to call
    // from any entry point; a no-op once state is populated.
    fun ensureLoaded(ctx: Context) {
        if (EnforcementState.dohUrl != null && EnforcementState.reporter != null) return
        val p = prefs(ctx)
        val doh = p.getString("dohUrl", null) ?: return
        EnforcementState.dohUrl = doh
        EnforcementState.witnessEmail = p.getString("witnessEmail", null)
        EnforcementState.nextDnsApiKey = p.getString("nextDnsApiKey", null)
        EnforcementState.nextDnsProfileId = p.getString("nextDnsProfileId", null)
        val host = p.getString("smtpHost", null)
        if (host != null && EnforcementState.reporter == null) {
            EnforcementState.reporter = EmailReporter(
                host, p.getInt("smtpPort", 587),
                p.getString("smtpUser", "") ?: "", p.getString("smtpPass", "") ?: "",
                p.getString("smtpFrom", "") ?: "")
        }
    }

    // Release-in-progress flag: an authorized PIN release removes admin + stops the VPN, which would
    // otherwise fire false tamper alerts and let the watchdog re-arm protection (audit bug #6).
    fun setReleasing(ctx: Context, v: Boolean) = prefs(ctx).edit().putBoolean("releasing", v).apply()
    fun isReleasing(ctx: Context) = prefs(ctx).getBoolean("releasing", false)

    // Tunnel liveness heartbeat: the running pump stamps this; the watchdog checks its freshness to
    // know the tunnel is REALLY up, instead of VpnService.prepare()==null which only means "consent
    // held" and stays true after the tunnel dies (audit bug #5).
    fun markTunnelAlive(ctx: Context) = prefs(ctx).edit().putLong("tunnelBeat", System.currentTimeMillis()).apply()
    fun tunnelAliveWithin(ctx: Context, withinMs: Long): Boolean {
        val t = prefs(ctx).getLong("tunnelBeat", 0L)
        return t > 0L && (System.currentTimeMillis() - t) < withinMs
    }

    // Per-domain-per-day dedup for porn-attempt alerts, so a repeat visit doesn't re-spam the witness.
    fun shouldAlertPorn(ctx: Context, domain: String): Boolean {
        val today = (System.currentTimeMillis() / 86_400_000L).toString()
        val key = "porn:$domain:$today"
        val p = prefs(ctx)
        if (p.getBoolean(key, false)) return false
        p.edit().putBoolean(key, true).apply()
        return true
    }
}
