package com.safety.accountability
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
object AdminState {
    fun isActive(ctx: Context): Boolean {
        val dpm = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isAdminActive(ComponentName(ctx, AdminReceiver::class.java))
    }
}
