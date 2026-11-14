package com.anchor.anchor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
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
