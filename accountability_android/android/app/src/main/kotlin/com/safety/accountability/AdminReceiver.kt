package com.safety.accountability

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class AdminReceiver : DeviceAdminReceiver() {
    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        // An authorized PIN release removes admin too — don't cry tamper for that (audit #6).
        if (NativeConfig.isReleasing(context)) return
        // onDisabled runs on the MAIN thread; SMTP there throws NetworkOnMainThreadException (audit #4).
        // goAsync() keeps the receiver alive while a background thread sends the tamper alert.
        val pending = goAsync()
        Thread {
            try { Alerts.notifyBlocking(context, AlertKind.ADMIN_DISABLED, "") }
            finally { pending.finish() }
        }.start()
    }
}
