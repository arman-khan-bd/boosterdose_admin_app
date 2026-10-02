package com.boosterdose.admin

import android.content.Intent
import android.os.Bundle
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.boosterdose.admin/notifications"
    private var notificationChannel: MethodChannel? = null
    private var initialNotificationPayload: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Ensure the notification channel is created as early as possible
        NotificationHelper.createNotificationChannel(applicationContext)
        // Schedule background alarm to guarantee polling even if app is closed
        NotificationAlarmReceiver.scheduleAlarm(applicationContext)
        // Capture launch intent payload if opened from notification click
        extractNotificationIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "showNotification" -> {
                        val id = (call.argument<Number>("id")?.toInt()) ?: System.currentTimeMillis().toInt()
                        val title = call.argument<String>("title") ?: "নতুন নোটিফিকেশন"
                        val body = call.argument<String>("body") ?: ""
                        val type = call.argument<String>("type") ?: "order"
                        val payload = call.argument<String>("payload")

                        NotificationHelper.showNotification(
                            context = applicationContext,
                            id = id,
                            title = title,
                            body = body,
                            type = type,
                            payload = payload
                        )
                        result.success(true)
                    }
                    "scheduleBackgroundSync" -> {
                        val intervalSeconds = call.argument<Number>("intervalSeconds")?.toLong() ?: 45L
                        NotificationAlarmReceiver.scheduleAlarm(applicationContext, intervalSeconds)
                        result.success(true)
                    }
                    "cancelAll" -> {
                        NotificationManagerCompat.from(applicationContext).cancelAll()
                        result.success(true)
                    }
                    "getInitialNotification" -> {
                        val payload = initialNotificationPayload
                        initialNotificationPayload = null
                        result.success(payload)
                    }
                    "testDropdownNotification" -> {
                        NotificationHelper.showNotification(
                            context = applicationContext,
                            id = 8888,
                            title = "🔔 টেস্ট পুশ নোটিফিকেশন",
                            body = "অ্যান্ড্রয়েড ড্রপডাউন ইভেন্ট নোটিফিকেশন সফলভাবে সক্রিয় আছে!",
                            type = "test",
                            payload = "test_event"
                        )
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractNotificationIntent(intent)
        initialNotificationPayload?.let { payload ->
            notificationChannel?.invokeMethod("onNotificationTapped", payload)
        }
    }

    private fun extractNotificationIntent(intent: Intent?) {
        if (intent != null && intent.getBooleanExtra("from_notification", false)) {
            val type = intent.getStringExtra("type")
            val payload = intent.getStringExtra("payload")
            initialNotificationPayload = mapOf(
                "type" to type,
                "payload" to payload
            )
        }
    }
}
