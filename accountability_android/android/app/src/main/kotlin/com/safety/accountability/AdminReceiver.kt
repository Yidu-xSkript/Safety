package com.safety.accountability

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class AdminReceiver : DeviceAdminReceiver() {
    override fun onDisabled(context: Context, intent: Intent) {
        // Fires when the witness-controlled admin is deactivated — alert before we lose privileges.
        EnforcementState.reporter?.send(
            EnforcementState.witnessEmail ?: "",
            AlertMessages.build(AlertKind.ADMIN_DISABLED, "")
        )
        super.onDisabled(context, intent)
    }
}
