package com.safety.accountability

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer

class AccountabilityVpnService : VpnService() {
    private var tunnel: ParcelFileDescriptor? = null
    @Volatile private var running = false
    private val http = OkHttpClient()
    private lateinit var dohUrl: String

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        dohUrl = intent?.getStringExtra("dohUrl") ?: EnforcementState.dohUrl ?: return START_NOT_STICKY
        EnforcementState.dohUrl = dohUrl
        startTunnel()
        return START_STICKY
    }

    private fun startTunnel() {
        if (running) return
        val b = Builder()
            .setSession("Accountability")
            .addAddress("10.111.222.1", 32)
            .addDnsServer("10.111.222.2")
            .addRoute("10.111.222.2", 32)
            .setBlocking(true)
        tunnel = b.establish() ?: return
        running = true
        Thread { pump(tunnel!!) }.start()
    }

    private fun pump(pfd: ParcelFileDescriptor) {
        val input = FileInputStream(pfd.fileDescriptor)
        val output = FileOutputStream(pfd.fileDescriptor)
        val buf = ByteBuffer.allocate(32767)
        while (running) {
            val n = try { input.read(buf.array()) } catch (e: Exception) { break }
            if (n <= 0) continue
            val query = DnsPacket.extract(buf.array(), n) ?: continue
            val answer = resolveOverDoh(query) ?: continue
            val packet = DnsPacket.wrapResponse(buf.array(), n, answer) ?: continue
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
        EnforcementState.reporter?.send(EnforcementState.witnessEmail ?: "", AlertMessages.build(AlertKind.VPN_OFF, ""))
        super.onRevoke()
    }

    override fun onDestroy() { running = false; tunnel?.close(); super.onDestroy() }
}
