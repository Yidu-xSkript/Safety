package com.safety.accountability

enum class AlertKind { VPN_OFF, ADMIN_DISABLED, RELEASE_ATTEMPT, HEARTBEAT }
data class AlertEmail(val subject: String, val body: String)

object AlertMessages {
    fun build(kind: AlertKind, detail: String): AlertEmail = when (kind) {
        AlertKind.VPN_OFF -> AlertEmail(
            "[Accountability] Protection off (VPN)",
            "The VPN protection was turned off or replaced. $detail")
        AlertKind.ADMIN_DISABLED -> AlertEmail(
            "[Accountability] Tamper: device admin disabled",
            "The device admin was disabled — uninstall protection is off. $detail")
        AlertKind.RELEASE_ATTEMPT -> AlertEmail(
            "[Accountability] Repeated wrong PIN on release",
            "Someone entered the wrong witness PIN trying to release the app. $detail")
        AlertKind.HEARTBEAT -> AlertEmail(
            "[Accountability] Daily heartbeat: still protected",
            "Protection is active. $detail")
    }
}
