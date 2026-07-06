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

    // Queried names (lower-cased) from the log. `from` is an optional relative window ("-1h") and
    // `field` picks "domain" (exact query, for porn matching) or "root" (registrable domain, for a
    // readable digest). Empty on any error (fail-quiet). Runs over the normal network + Private DNS
    // (the VPN no longer captures DNS), so there is no bootstrap loop.
    fun fetch(apiKey: String, profileId: String, from: String? = null, limit: Int = 100, field: String = "domain"): List<String> {
        return try {
            val url = buildString {
                append("https://api.nextdns.io/profiles/$profileId/logs?limit=$limit")
                if (!from.isNullOrBlank()) append("&from=$from")
            }
            val req = Request.Builder().url(url).header("X-Api-Key", apiKey).build()
            http.newCall(req).execute().use { resp ->
                val body = resp.body?.string() ?: return emptyList()
                val arr = JSONObject(body).optJSONArray("data") ?: return emptyList()
                (0 until arr.length()).mapNotNull { i ->
                    val o = arr.optJSONObject(i) ?: return@mapNotNull null
                    val v = o.optString(field).ifBlank { o.optString("domain") }.lowercase()
                    if (v.isBlank()) null else v
                }
            }
        } catch (e: Throwable) { emptyList() }
    }
}
