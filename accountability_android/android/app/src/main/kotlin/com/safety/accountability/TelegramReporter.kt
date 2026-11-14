package com.safety.accountability

import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.util.concurrent.TimeUnit

// Delivers alerts and reports to a Telegram channel through a bot (the bot must be an ADMIN of the
// channel). chatId is "@channelname" for a public channel or "-100…" for a private one. Blocking
// network I/O — same rule as before: never call from the main thread.
class TelegramReporter(private val botToken: String, private val chatId: String) : Reporter {
    override fun send(email: AlertEmail) {
        for (part in chunk("${email.subject}\n\n${email.body}")) {
            val req = Request.Builder().url("https://api.telegram.org/bot$botToken/sendMessage")
                .post(FormBody.Builder().add("chat_id", chatId).add("text", part).build()).build()
            http.newCall(req).execute().use { r ->
                // Telegram's body names the real problem ("chat not found", "bot is not a member…").
                if (!r.isSuccessful) throw IOException("Telegram ${r.code}: ${r.body?.string()}")
            }
        }
    }

    companion object {
        private val http = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS).readTimeout(15, TimeUnit.SECONDS).build()
        const val MAX = 4000   // Telegram rejects a message over 4096 chars; a long report goes as several

        // Split on line breaks where possible so a report row is never cut in half.
        fun chunk(text: String): List<String> {
            val out = mutableListOf<String>()
            val cur = StringBuilder()
            for (line in text.lines().flatMap { it.chunked(MAX) }) {
                if (cur.isNotEmpty() && cur.length + 1 + line.length > MAX) { out += cur.toString(); cur.clear() }
                if (cur.isNotEmpty()) cur.append('\n')
                cur.append(line)
            }
            if (cur.isNotEmpty()) out += cur.toString()
            return out
        }
    }
}
