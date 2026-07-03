package com.safety.accountability

enum class WatchdogAction { RESTART_VPN, ALERT_VPN_OFF, ALERT_ADMIN, SEND_HEARTBEAT }

object WatchdogDecision {
    // Pure: given observed state, return the actions the worker should perform.
    fun decide(vpnUp: Boolean, adminActive: Boolean, heartbeatDue: Boolean): List<WatchdogAction> {
        val out = mutableListOf<WatchdogAction>()
        if (!vpnUp) { out.add(WatchdogAction.RESTART_VPN); out.add(WatchdogAction.ALERT_VPN_OFF) }
        if (!adminActive) out.add(WatchdogAction.ALERT_ADMIN)
        if (heartbeatDue) out.add(WatchdogAction.SEND_HEARTBEAT)
        return out
    }
}
