package com.safety.accountability_android

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.safety.accountability.AccountabilityVpnService
import com.safety.accountability.AdminReceiver
import com.safety.accountability.EmailReporter
import com.safety.accountability.EnforcementState
import com.safety.accountability.WatchdogWorker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "accountability/enforce")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        EnforcementState.dohUrl = call.argument("dohUrl")
                        EnforcementState.witnessEmail = call.argument("witnessEmail")
                        EnforcementState.reporter = EmailReporter(
                            call.argument("smtpHost")!!, call.argument("smtpPort")!!,
                            call.argument("smtpUser")!!, call.argument("smtpPass")!!,
                            call.argument("smtpFrom")!!)
                        result.success(true)
                    }
                    "startVpn" -> {
                        val prep = android.net.VpnService.prepare(this)
                        if (prep != null) { startActivityForResult(prep, 1); result.success(false) }
                        else { startService(Intent(this, AccountabilityVpnService::class.java)
                            .putExtra("dohUrl", EnforcementState.dohUrl)); result.success(true) }
                    }
                    "startWatchdog" -> {
                        val work = PeriodicWorkRequestBuilder<WatchdogWorker>(15, TimeUnit.MINUTES).build()
                        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
                            "watchdog", ExistingPeriodicWorkPolicy.KEEP, work)
                        result.success(true)
                    }
                    "requestAdmin" -> {
                        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                            .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                                ComponentName(this, AdminReceiver::class.java))
                        startActivity(intent); result.success(true)
                    }
                    "release" -> {
                        val dpm = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        dpm.removeActiveAdmin(ComponentName(this, AdminReceiver::class.java))
                        stopService(Intent(this, AccountabilityVpnService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
