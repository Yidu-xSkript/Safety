package com.safety.accountability

import android.content.Context

// Central alert dispatch. SMTP (EmailReporter) does blocking network I/O and MUST NOT run on the main
// thread (NetworkOnMainThreadException crashes onRevoke / onDisabled — audit bug #4). This loads any
// persisted config, then sends off the main thread with one retry so a transient failure isn't lost.
object Alerts {
    fun notifyAsync(ctx: Context, kind: AlertKind, detail: String) {
        Thread {
            NativeConfig.ensureLoaded(ctx)
            val to = EnforcementState.witnessEmail ?: return@Thread
            val reporter = EnforcementState.reporter ?: return@Thread
            val email = AlertMessages.build(kind, detail)
            try { reporter.send(to, email) } catch (e: Exception) {
                try { Thread.sleep(3000); reporter.send(to, email) } catch (e2: Exception) { }
            }
        }.start()
    }

    // Synchronous variant for callers that are ALREADY off the main thread and must stay alive until
    // the send completes (a WorkManager Worker, or a BroadcastReceiver holding goAsync()).
    fun notifyBlocking(ctx: Context, kind: AlertKind, detail: String) {
        NativeConfig.ensureLoaded(ctx)
        val to = EnforcementState.witnessEmail ?: return
        val reporter = EnforcementState.reporter ?: return
        val email = AlertMessages.build(kind, detail)
        try { reporter.send(to, email) } catch (e: Exception) {
            try { Thread.sleep(3000); reporter.send(to, email) } catch (e2: Exception) { }
        }
    }
}
