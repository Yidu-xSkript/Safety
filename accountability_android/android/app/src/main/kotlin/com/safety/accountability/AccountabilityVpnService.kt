package com.safety.accountability

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit

class AccountabilityVpnService : VpnService() {
    private var tunnel: ParcelFileDescriptor? = null
    @Volatile private var running = false
    // Short timeouts so one hung DoH lookup can't stall all DNS on the device (audit #11).
    private val http = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(5, TimeUnit.SECONDS)
        .callTimeout(8, TimeUnit.SECONDS)
        .build()
    private lateinit var dohUrl: String

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        NativeConfig.ensureLoaded(this)   // fresh process (START_STICKY/boot restart): reload config
        dohUrl = intent?.getStringExtra("dohUrl") ?: EnforcementState.dohUrl ?: run {
            stopSelf(); return START_NOT_STICKY
        }
        EnforcementState.dohUrl = dohUrl
        // MUST run as a foreground service — a background service is illegal to start on Android 8+
        // and gets reaped quickly, so "always-on" fails without this (audit #3).
        startForeground(NOTIF_ID, buildNotification())
        startTunnel()
        return START_STICKY
    }

    private fun buildNotification(): Notification {
        val mgr = getSystemService(NotificationManager::class.java)
        if (mgr.getNotificationChannel(CHANNEL) == null) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL, "Accountability protection", NotificationManager.IMPORTANCE_LOW))
        }
        return Notification.Builder(this, CHANNEL)
            .setContentTitle("Accountability protection active")
            .setContentText("Filtering DNS through NextDNS.")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()
    }

    private fun startTunnel() {
        if (running) return
        // Capture DNS on BOTH IPv4 and IPv6 so DNS can't bypass NextDNS over IPv6 on a dual-stack
        // network (audit #9). We route only the virtual DNS servers into the tunnel (not all traffic),
        // so normal browsing still flows directly — only DNS is forced through us.
        val b = Builder()
            .setSession("Accountability")
            .addAddress("10.111.222.1", 32)
            .addAddress("fd00:acc0:acc0::1", 128)
            .addDnsServer("10.111.222.2")
            .addDnsServer("fd00:acc0:acc0::2")
            .addRoute("10.111.222.2", 32)
            .addRoute("fd00:acc0:acc0::2", 128)
            .setBlocking(true)
        tunnel = b.establish() ?: run { stopSelf(); return }
        running = true
        Thread { pump(tunnel!!) }.start()
    }

    private fun pump(pfd: ParcelFileDescriptor) {
        val input = FileInputStream(pfd.fileDescriptor)
        val output = FileOutputStream(pfd.fileDescriptor)
        val buf = ByteArray(32767)
        while (running) {
            val n = try { input.read(buf) } catch (e: Exception) { break }
            if (n <= 0) continue
            NativeConfig.markTunnelAlive(this)   // liveness heartbeat the watchdog checks (audit #5)
            val query = DnsPacket.extract(buf, n) ?: continue
            // ATTEMPT ALERT: if the queried domain is a known porn site, email the witness (blocked or
            // not). Off-thread + per-day dedup so it never stalls DNS or spams. This is the Android
            // twin of the Windows sinkhole/NextDNS-attempt alert.
            val name = DnsPacket.queryName(query)
            if (name != null && PornList.isPorn(name) && NativeConfig.shouldAlertPorn(this, name)) {
                Alerts.notifyAsync(this, AlertKind.PORN_ATTEMPT, name)
            }
            val answer = resolveOverDoh(query) ?: continue
            val packet = DnsPacket.wrapResponse(buf, n, answer) ?: continue
            try { output.write(packet) } catch (e: Exception) { break }
        }
    }

    private fun resolveOverDoh(query: ByteArray): ByteArray? = try {
        val req = Request.Builder().url(dohUrl)
            .header("accept", "application/dns-message")
            .post(query.toRequestBody("application/dns-message".toMediaType())).build()
        http.newCall(req).execute().use { it.body?.bytes() }
    } catch (e: Exception) { null }

    override fun onRevoke() {
        running = false
        // Send off the main thread (SMTP on main = NetworkOnMainThreadException, audit #4). Suppress
        // during an authorized PIN release so we don't fire a false "protection off" alert (audit #6).
        if (!NativeConfig.isReleasing(this)) {
            Alerts.notifyAsync(this, AlertKind.VPN_OFF, "")
        }
        super.onRevoke()
    }

    override fun onDestroy() { running = false; tunnel?.close(); super.onDestroy() }

    companion object {
        private const val CHANNEL = "aa_protection"
        private const val NOTIF_ID = 42
    }
}
