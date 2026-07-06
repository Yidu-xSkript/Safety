package com.safety.accountability

import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

// Phone-side porn-ATTEMPT detection without touching DNS: poll the NextDNS query-log API and match
// each requested domain against the porn list. NextDNS logs every query (blocked or not) from every
// device on the profile, so this catches attempts the (now DNS-less) VPN can't see — the Android twin
// of the Windows agent's NextDNS attempt alert. Needs the profile's API key.
object NextDnsPoller {
    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    // Recent queried domains (lower-cased). Empty on any error (fail-quiet). This runs over the normal
    // network + Private DNS (the VPN no longer captures DNS), so there is no bootstrap loop.
    fun fetchDomains(apiKey: String, profileId: String, limit: Int = 100): List<String> {
        return try {
            val req = Request.Builder()
                .url("https://api.nextdns.io/profiles/$profileId/logs?limit=$limit")
                .header("X-Api-Key", apiKey)
                .build()
            http.newCall(req).execute().use { resp ->
                val body = resp.body?.string() ?: return emptyList()
                val arr = JSONObject(body).optJSONArray("data") ?: return emptyList()
                (0 until arr.length()).mapNotNull { i ->
                    val d = arr.optJSONObject(i)?.optString("domain")?.lowercase()
                    if (d.isNullOrBlank()) null else d
                }
            }
        } catch (e: Throwable) { emptyList() }
    }
}
