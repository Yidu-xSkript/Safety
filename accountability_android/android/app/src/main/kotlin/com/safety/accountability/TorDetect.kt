package com.safety.accountability

import android.content.Context

// Detects Tor apps on the phone. Tor routes traffic outside NextDNS (straight to relay IPs, no DNS),
// so it bypasses the whole DNS-based block and can't be filtered — and a sandboxed app can't kill or
// block it. All we can do is DETECT it and email the witness (accountability, not prevention). The
// packages are declared in <queries> so this works without the restricted QUERY_ALL_PACKAGES.
object TorDetect {
    private val TOR_PACKAGES = listOf(
        "org.torproject.torbrowser",        // Tor Browser
        "org.torproject.torbrowser_alpha",  // Tor Browser (alpha)
        "org.torproject.android",           // Orbot
        "org.torproject.vpn"                // Tor VPN
    )

    fun installed(ctx: Context): List<String> {
        val pm = ctx.packageManager
        return TOR_PACKAGES.filter { pkg ->
            try { pm.getPackageInfo(pkg, 0); true } catch (e: Exception) { false }
        }
    }
}
