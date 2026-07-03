package com.safety.accountability
import org.junit.Assert.assertTrue
import org.junit.Test

class AlertMessagesTest {
    @Test fun vpnOffAlertMentionsProtectionOff() {
        val m = AlertMessages.build(AlertKind.VPN_OFF, "")
        assertTrue(m.subject.contains("protection off", ignoreCase = true))
    }
    @Test fun tamperAlertMentionsAdmin() {
        val m = AlertMessages.build(AlertKind.ADMIN_DISABLED, "")
        assertTrue(m.body.contains("admin", ignoreCase = true))
    }
    @Test fun heartbeatMentionsStillProtected() {
        val m = AlertMessages.build(AlertKind.HEARTBEAT, "")
        assertTrue(m.subject.contains("protected", ignoreCase = true))
    }
}
