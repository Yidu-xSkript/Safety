package com.safety.accountability

import android.content.Context

// Central alert dispatch. The Telegram send (TelegramReporter) does blocking network I/O and MUST NOT
// run on the main thread (NetworkOnMainThreadException crashes onRevoke / onDisabled — audit bug #4).
// This loads any persisted config, then sends off the main thread with one retry so a transient
// failure isn't lost.
object Alerts {
    fun notifyAsync(ctx: Context, kind: AlertKind, detail: String) {
        Thread {
            NativeConfig.ensureLoaded(ctx)
            val reporter = EnforcementState.reporter ?: return@Thread
            val msg = AlertMessages.build(kind, detail)
            try { reporter.send(msg) } catch (e: Exception) {
                try { Thread.sleep(3000); reporter.send(msg) } catch (e2: Exception) { }
            }
        }.start()
    }

    // Synchronous variant for callers that are ALREADY off the main thread and must stay alive until
    // the send completes (a WorkManager Worker, or a BroadcastReceiver holding goAsync()).
    fun notifyBlocking(ctx: Context, kind: AlertKind, detail: String) {
        NativeConfig.ensureLoaded(ctx)
        val reporter = EnforcementState.reporter ?: return
        val msg = AlertMessages.build(kind, detail)
        try { reporter.send(msg) } catch (e: Exception) {
            try { Thread.sleep(3000); reporter.send(msg) } catch (e2: Exception) { }
        }
    }
}
