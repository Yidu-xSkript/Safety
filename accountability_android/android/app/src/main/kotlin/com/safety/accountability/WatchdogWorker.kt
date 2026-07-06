package com.safety.accountability

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.work.Worker
import androidx.work.WorkerParameters

class WatchdogWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        val ctx = applicationContext
        NativeConfig.ensureLoaded(ctx)                                  // fresh process: reload config (#2)
        if (NativeConfig.isReleasing(ctx)) return Result.success()      // authorized release, stand down (#6)

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
}
