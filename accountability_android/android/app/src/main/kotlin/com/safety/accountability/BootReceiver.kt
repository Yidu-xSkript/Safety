package com.safety.accountability

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val prepare = android.net.VpnService.prepare(context)
        if (prepare == null) {  // already authorized
            context.startService(Intent(context, AccountabilityVpnService::class.java))
        }
        // else: needs user re-consent on next app open (handled by UI)
    }
}
