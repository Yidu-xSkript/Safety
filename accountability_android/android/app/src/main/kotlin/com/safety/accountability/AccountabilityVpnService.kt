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
        startAttemptPoller()
        startReports()
        return START_STICKY
    }

    // Twice a day (07:30 and 00:00 EAT; see ReportSchedule) send ONE short digest covering everything
    // since the previous one. Runs from the always-on foreground service — reliable, unlike WorkManager
    // which Android throttles/kills under Doze. Wakes every 15 minutes just to check if one is due; the
    // last-sent time is persisted, so a failed send retries on the next tick and a restart loses nothing.
    private fun startReports() {
        Thread {
            while (running) {
                try { Thread.sleep(ReportSchedule.msUntilNextTick(System.currentTimeMillis())) }
                catch (e: InterruptedException) { break }
                if (!running) break
                val now = System.currentTimeMillis()
                val last = NativeConfig.lastDigestMs(this)
                if (!ReportSchedule.isDue(now, last)) continue
                val from = maxOf(last, now - ReportSchedule.MAX_LOOKBACK_MS)
                try { if (sendDigest(from, now)) NativeConfig.markDigestSent(this, now) }
                catch (e: Throwable) { }
            }
        }.start()
    }

    // Returns true only if a message actually went out.
    private fun sendDigest(from: Long, to: Long): Boolean {
        val reporter = EnforcementState.reporter ?: return false
        val span = to - from
        val apiKey = EnforcementState.nextDnsApiKey
        val profileId = EnforcementState.nextDnsProfileId
        val domains = if (apiKey.isNullOrBlank() || profileId.isNullOrBlank()) emptyList()
            else NextDnsPoller.fetch(apiKey, profileId, limit = 1000, field = "root")
        val text = Digest.build(
            ReportSchedule.range(from, to),
            AppUsage.usage(this, span),
            TelegramWatch.visits(this, span),
            TelegramWatch.wasEverEnabled(this) && !TelegramWatch.isEnabled(this),
            domains)
        reporter.send(AlertEmail("[Accountability] Phone digest", text))
        return true
    }

    // Poll the NextDNS log for porn attempts and email the witness — the DNS-less way to get phone-side
    // attempt alerts. No-op unless an API key + profile id are configured. One email per domain/day.
    private fun startAttemptPoller() {
        val apiKey = EnforcementState.nextDnsApiKey
        val profileId = EnforcementState.nextDnsProfileId
        if (apiKey.isNullOrBlank() || profileId.isNullOrBlank()) return
        Thread {
            while (running) {
                try {
                    // Most-recent 200 log rows, matched by ROOT domain so subdomain variants of one site
                    // collapse to a single per-site alert. Per-domain 5-min dedup (shouldAlertPorn) — not a
                    // time-window param — is what stops old queries re-firing.
                    for (d in NextDnsPoller.fetch(apiKey, profileId, limit = 200, field = "root")) {
                        if (PornList.isPorn(d) && NativeConfig.shouldAlertPorn(this, d)) {
                            Alerts.notifyAsync(this, AlertKind.PORN_ATTEMPT, d)
                        }
                    }
                } catch (e: Throwable) { }
                try { Thread.sleep(60_000) } catch (e: InterruptedException) { break }
            }
        }.start()
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
        // DNS is NOT handled here. Routing DNS through our own DoH pump caused a fatal bootstrap loop
        // (resolving the DoH host dns.nextdns.io needs DNS = us → every lookup failed, DNS_PROBE_
        // FINISHED_BAD_CONFIG). NextDNS Private DNS (set on the phone) already filters ALL DNS natively
        // and reliably, so this tunnel does NOT set a DNS server or capture DNS — it only occupies the
        // single Android VPN slot so a bypass VPN can't start. It routes just its own /32 (nothing
        // real), leaving all traffic + DNS to flow normally through Private DNS.
        val b = Builder()
            .setSession("Accountability")
            .addAddress("10.111.222.1", 32)
            .addRoute("10.111.222.1", 32)
            .setBlocking(true)
        tunnel = b.establish() ?: run { stopSelf(); return }
        running = true
        // No pump / no DoH: nothing real is routed to us, so there is nothing to read or forward.
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
