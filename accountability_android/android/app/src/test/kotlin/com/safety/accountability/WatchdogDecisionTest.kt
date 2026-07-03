package com.safety.accountability
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WatchdogDecisionTest {
    @Test fun healthyStateAsksForNothingButHeartbeat() {
        val a = WatchdogDecision.decide(vpnUp = true, adminActive = true, heartbeatDue = false)
        assertTrue(a.isEmpty())
    }
    @Test fun vpnDownRequestsRestartAndAlert() {
        val a = WatchdogDecision.decide(vpnUp = false, adminActive = true, heartbeatDue = false)
        assertTrue(a.contains(WatchdogAction.RESTART_VPN))
        assertTrue(a.contains(WatchdogAction.ALERT_VPN_OFF))
    }
    @Test fun adminDownRequestsAlert() {
        val a = WatchdogDecision.decide(vpnUp = true, adminActive = false, heartbeatDue = false)
        assertTrue(a.contains(WatchdogAction.ALERT_ADMIN))
    }
    @Test fun heartbeatDueEmitsHeartbeat() {
        val a = WatchdogDecision.decide(vpnUp = true, adminActive = true, heartbeatDue = true)
        assertEquals(listOf(WatchdogAction.SEND_HEARTBEAT), a)
    }
}
