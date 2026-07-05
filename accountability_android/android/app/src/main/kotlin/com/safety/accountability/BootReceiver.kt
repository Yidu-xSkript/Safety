package com.safety.accountability

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        NativeConfig.ensureLoaded(context)                 // fresh boot process: reload config (#2)
        if (NativeConfig.isReleasing(context)) return       // released for uninstall — don't re-arm
        if (EnforcementState.dohUrl == null) return         // never configured
        if (android.net.VpnService.prepare(context) == null) {   // consent already granted
            context.startForegroundService(                 // background startService is illegal on 8+ (#3)
                Intent(context, AccountabilityVpnService::class.java)
                    .putExtra("dohUrl", EnforcementState.dohUrl))
        }
        // else: needs user re-consent on next app open (handled by UI)
    }
}
