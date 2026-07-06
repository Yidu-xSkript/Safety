package com.safety.accountability

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.provider.Settings
import androidx.work.Worker
import androidx.work.WorkerParameters

class WatchdogWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        val ctx = applicationContext
        NativeConfig.ensureLoaded(ctx)                                  // fresh process: reload config (#2)
        if (NativeConfig.isReleasing(ctx)) return Result.success()      // authorized release, stand down (#6)

        // Hourly ONE activity email: app usage (if Usage Access granted) + domain digest (if a NextDNS
        // API key is set), combined. Once per ~hour (watchdog runs every 15 min). Skips whichever half
        // isn't available; sends nothing if neither is.
        if (NativeConfig.shouldAlertWithin(ctx, "hourlyreport", 60 * 60 * 1000L)) {
            val to = EnforcementState.witnessEmail
            val reporter = EnforcementState.reporter
            if (to != null && reporter != null) {
                val sb = StringBuilder()
                if (AppUsage.hasAccess(ctx)) sb.append(AppUsage.report(ctx, 60 * 60 * 1000L, "hour"))
                val apiKey = EnforcementState.nextDnsApiKey
                val profileId = EnforcementState.nextDnsProfileId
                if (!apiKey.isNullOrBlank() && !profileId.isNullOrBlank()) {
                    if (sb.isNotEmpty()) sb.append("\n\n")
                    val roots = NextDnsPoller.fetch(apiKey, profileId, from = "-1h", limit = 1000, field = "root")
                    sb.append(NextDnsReport.format(roots, "hour"))
                }
                if (sb.isNotEmpty()) {
                    try { reporter.send(to, AlertEmail("[Accountability] Phone activity (hourly)", sb.toString())) }
                    catch (e: Throwable) { }
                }
            }
        }

        // NextDNS on the phone = Private DNS pointed at nextdns.io. If it's off/changed, the block is
        // gone — alert. (A sandboxed app can't re-set it; WRITE_SECURE_SETTINGS isn't grantable.)
        if (nextDnsPrivateDnsMissing(ctx) && NativeConfig.shouldAlertOncePerDay(ctx, "dns_off")) {
            Alerts.notifyBlocking(ctx, AlertKind.DNS_OFF, "")
        }

        // Tor apps bypass NextDNS entirely and can't be blocked/killed on Android — detect + alert.
        for (pkg in TorDetect.installed(ctx)) {
            if (NativeConfig.shouldAlertOncePerDay(ctx, "tor:$pkg")) {
                Alerts.notifyBlocking(ctx, AlertKind.TOR_DETECTED, pkg)
            }
        }

        val vpnUp = isVpnActive(ctx)
        val adminActive = AdminState.isActive(ctx)
        val heartbeatDue = HeartbeatClock.isDue(ctx)
        val actions = WatchdogDecision.decide(vpnUp, adminActive, heartbeatDue)
        for (a in actions) when (a) {
            WatchdogAction.RESTART_VPN -> {
                val doh = EnforcementState.dohUrl ?: continue
                ctx.startForegroundService(                             // background startService is illegal (#3)
                    Intent(ctx, AccountabilityVpnService::class.java).putExtra("dohUrl", doh))
            }
            // Workers run off the main thread, so send synchronously to stay alive until it's sent.
            WatchdogAction.ALERT_VPN_OFF -> Alerts.notifyBlocking(ctx, AlertKind.VPN_OFF, "")
            WatchdogAction.ALERT_ADMIN -> Alerts.notifyBlocking(ctx, AlertKind.ADMIN_DISABLED, "")
            WatchdogAction.SEND_HEARTBEAT -> {
                Alerts.notifyBlocking(ctx, AlertKind.HEARTBEAT, "")
                HeartbeatClock.markSent(ctx)
            }
        }
        return Result.success()
    }

    // Real liveness: is a VPN transport actually up? We hold the single VPN slot, so a live VPN
    // transport is ours. Traffic-independent, unlike VpnService.prepare()==null which only means
    // "consent held" and stays true after the tunnel dies (audit #5).
    private fun isVpnActive(ctx: Context): Boolean {
        val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        for (n in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(n) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return true
        }
        return false
    }

    // Is Private DNS NOT set to NextDNS? Reads the global Private DNS mode/host. Returns true only when
    // we can read the setting AND it isn't hostname-mode pointed at nextdns.io (so an unreadable
    // setting never false-alarms). Blocking on the phone depends entirely on this being on.
    private fun nextDnsPrivateDnsMissing(ctx: Context): Boolean {
        val cr = ctx.contentResolver
        val mode = Settings.Global.getString(cr, "private_dns_mode") ?: return false  // unknown → don't alert
        if (mode != "hostname") return true                                           // off or automatic
        val host = Settings.Global.getString(cr, "private_dns_specifier")
        return host == null || !host.contains("nextdns.io")
    }
}
