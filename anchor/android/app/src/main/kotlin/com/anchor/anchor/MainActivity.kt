package com.anchor.anchor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity): the biometric prompt of the app lock (local_auth) needs it.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    // "Hide in app switcher": FLAG_SECURE blanks the recents thumbnail and blocks screenshots and screen recording.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.anchor/privacy").setMethodCallHandler { call, result ->
            if (call.method == "setSecure") {
                val on = call.arguments as? Boolean ?: true
                runOnUiThread {
                    if (on) window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    // FCM names a channel in each message (see supabase/functions/notify/logic.ts); it must already exist.
    // Names are what a bystander could read in system settings, so they say nothing about what the app is for.
    // "urge" is the one high-importance channel; none of them bypass Do Not Disturb.
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        fun channel(id: String, name: Int, importance: Int) =
            NotificationChannel(id, getString(name), importance).apply {
                // The text is already generic, so it may show on the lock screen.
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        nm.createNotificationChannel(channel("urge", R.string.channel_urge, NotificationManager.IMPORTANCE_HIGH))
        nm.createNotificationChannel(channel("pod", R.string.channel_pod, NotificationManager.IMPORTANCE_DEFAULT))
        nm.createNotificationChannel(channel("reminders", R.string.channel_reminders, NotificationManager.IMPORTANCE_LOW))
    }
}
