package com.safety.accountability

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

class WatchdogWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        val vpnUp = EnforcementState.dohUrl != null && android.net.VpnService.prepare(applicationContext) == null
        val adminActive = AdminState.isActive(applicationContext)
        val heartbeatDue = HeartbeatClock.isDue(applicationContext)
        val actions = WatchdogDecision.decide(vpnUp, adminActive, heartbeatDue)
        val to = EnforcementState.witnessEmail ?: return Result.success()
        for (a in actions) when (a) {
            WatchdogAction.RESTART_VPN -> applicationContext.startService(
                android.content.Intent(applicationContext, AccountabilityVpnService::class.java))
            WatchdogAction.ALERT_VPN_OFF -> EnforcementState.reporter?.send(to, AlertMessages.build(AlertKind.VPN_OFF, ""))
            WatchdogAction.ALERT_ADMIN -> EnforcementState.reporter?.send(to, AlertMessages.build(AlertKind.ADMIN_DISABLED, ""))
            WatchdogAction.SEND_HEARTBEAT -> {
                EnforcementState.reporter?.send(to, AlertMessages.build(AlertKind.HEARTBEAT, ""))
                HeartbeatClock.markSent(applicationContext)
            }
        }
        return Result.success()
    }
}
