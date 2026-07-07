package com.safety.accountability_android

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import com.safety.accountability.AccountabilityVpnService
import com.safety.accountability.AdminReceiver
import com.safety.accountability.AdminState
import com.safety.accountability.AlertEmail
import com.safety.accountability.AlertKind
import com.safety.accountability.Alerts
import com.safety.accountability.EmailReporter
import com.safety.accountability.EnforcementState
import com.safety.accountability.NativeConfig
import com.safety.accountability.WatchdogWorker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    // Held between the VPN-consent dialog and its result so we can start the service and report the
    // REAL outcome back to Dart (audit #1: consent was granted but nothing started the service).
    private var pendingVpnResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "accountability/enforce")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        val dohUrl: String = call.argument("dohUrl")!!
                        val witnessEmail: String = call.argument("witnessEmail")!!
                        val smtpHost: String = call.argument("smtpHost")!!
                        val smtpPort: Int = call.argument("smtpPort")!!
                        val smtpUser: String = call.argument("smtpUser")!!
                        val smtpPass: String = call.argument("smtpPass")!!
                        val smtpFrom: String = call.argument("smtpFrom")!!
                        val apiKey: String = call.argument<String>("nextDnsApiKey") ?: ""
                        val profileId: String = call.argument<String>("nextDnsProfileId") ?: ""
                        EnforcementState.dohUrl = dohUrl
                        EnforcementState.witnessEmail = witnessEmail
                        EnforcementState.nextDnsApiKey = apiKey
                        EnforcementState.nextDnsProfileId = profileId
                        EnforcementState.reporter = EmailReporter(smtpHost, smtpPort, smtpUser, smtpPass, smtpFrom)
                        // Persist so background entry points work in a fresh process (audit #2).
                        NativeConfig.save(this, dohUrl, witnessEmail, smtpHost, smtpPort, smtpUser, smtpPass, smtpFrom, apiKey, profileId)
                        NativeConfig.setReleasing(this, false)   // (re)configuring means we're protecting again
                        result.success(true)
                    }
                    "startVpn" -> {
                        val prep = android.net.VpnService.prepare(this)
                        if (prep != null) { pendingVpnResult = result; startActivityForResult(prep, REQ_VPN) }
                        else { startVpnService(); result.success(true) }
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
                    "alertReleaseAttempt" -> {   // repeated wrong witness PIN (audit #7)
                        Alerts.notifyAsync(this, AlertKind.RELEASE_ATTEMPT, "")
                        result.success(true)
                    }
                    "testEmail" -> {   // setup self-test: send a real email so a bad SMTP config can't slip through
                        val to = (call.argument<String>("to") ?: EnforcementState.witnessEmail).orEmpty()
                        val reporter = EnforcementState.reporter
                        if (reporter == null || to.isBlank()) {
                            result.success("Email is not configured yet — fill in the witness email and SMTP fields.")
                        } else {
                            Thread {
                                // Catch Throwable (not just Exception) so a NoClassDefFoundError from a
                                // stripped mail class also surfaces. Report the exception type + root
                                // cause so the real problem (auth vs provider vs TLS vs DNS) is visible.
                                val err = try {
                                    reporter.send(to, AlertEmail(
                                        "[Accountability] Setup test",
                                        "Success — alerting works. The witness will be emailed on tamper and porn attempts."))
                                    null   // null == success
                                } catch (e: Throwable) {
                                    val root = generateSequence(e as Throwable) { it.cause }.last()
                                    "${e.javaClass.simpleName}: ${e.message ?: ""} | root ${root.javaClass.simpleName}: ${root.message ?: ""}"
                                }
                                runOnUiThread { result.success(err) }
                            }.start()
                        }
                    }
                    "requestUsageAccess" -> {   // opens the system Usage-access screen for the app-usage report
                        try { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)) } catch (e: Exception) {}
                        result.success(true)
                    }
                    "requestBatteryExemption" -> {   // keep the service alive under Doze
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            try {
                                @android.annotation.SuppressLint("BatteryLife")
                                val i = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                    .setData(Uri.parse("package:$packageName"))
                                startActivity(i)
                            } catch (e: Exception) {}
                        }
                        result.success(true)
                    }
                    "status" -> {   // REAL protection state so the status screen can't show a false "active" (#12)
                        result.success(mapOf(
                            "vpn" to isVpnActive(),
                            "admin" to AdminState.isActive(this),
                            "watchdog" to isWatchdogScheduled()))
                    }
                    "release" -> {
                        // Authorized release: flag it FIRST so onDisabled/watchdog don't fire false
                        // tamper alerts or re-arm the VPN, and cancel the watchdog before teardown (#6).
                        NativeConfig.setReleasing(this, true)
                        WorkManager.getInstance(this).cancelUniqueWork("watchdog")
                        val dpm = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        dpm.removeActiveAdmin(ComponentName(this, AdminReceiver::class.java))
                        stopService(Intent(this, AccountabilityVpnService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startVpnService() {
        startForegroundService(Intent(this, AccountabilityVpnService::class.java)
            .putExtra("dohUrl", EnforcementState.dohUrl))
    }

    // Is a VPN transport actually up? We hold the single VPN slot, so a live VPN transport is ours.
    private fun isVpnActive(): Boolean {
        val cm = getSystemService(ConnectivityManager::class.java)
        for (n in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(n) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return true
        }
        return false
    }

    private fun isWatchdogScheduled(): Boolean = try {
        WorkManager.getInstance(this).getWorkInfosForUniqueWork("watchdog").get()
            .any { !it.state.isFinished }
    } catch (e: Exception) { false }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_VPN) {
            if (resultCode == Activity.RESULT_OK) { startVpnService(); pendingVpnResult?.success(true) }
            else pendingVpnResult?.success(false)
            pendingVpnResult = null
        }
    }

    companion object { private const val REQ_VPN = 1 }
}
