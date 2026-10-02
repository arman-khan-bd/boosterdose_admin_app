package com.boosterdose.admin

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class NotificationAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_POLL = "com.boosterdose.admin.ACTION_POLL_NOTIFICATIONS"
        const val ALARM_REQUEST_CODE = 4401
        const val DEFAULT_INTERVAL_SECONDS = 45L

        fun scheduleAlarm(context: Context, intervalSeconds: Long = DEFAULT_INTERVAL_SECONDS) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
                val intent = Intent(context, NotificationAlarmReceiver::class.java).apply {
                    action = ACTION_POLL
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    ALARM_REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                )

                val triggerAtMillis = SystemClock.elapsedRealtime() + (intervalSeconds * 1000L)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAtMillis,
                            pendingIntent
                        )
                    } catch (_: SecurityException) {
                        // Fallback if SCHEDULE_EXACT_ALARM is restricted
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAtMillis,
                            pendingIntent
                        )
                    }
                } else {
                    alarmManager.set(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun cancelAlarm(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
                val intent = Intent(context, NotificationAlarmReceiver::class.java).apply {
                    action = ACTION_POLL
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    ALARM_REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                )
                alarmManager.cancel(pendingIntent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        // Reschedule next background poll to ensure non-stop reliability
        scheduleAlarm(context, DEFAULT_INTERVAL_SECONDS)

        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                checkAndNotifyNewEvents(context)
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun checkAndNotifyNewEvents(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.auth_token", null) ?: return
        if (token.isBlank()) return

        val customBaseUrl = prefs.getString("flutter.custom_base_url", null)
        val baseUrl = (customBaseUrl ?: "https://boosterdose.shop").trimEnd('/')

        val urlString = "$baseUrl/api/admin/notifications/feed"
        val url = URL(urlString)
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "GET"
        conn.setRequestProperty("Authorization", "Bearer $token")
        conn.setRequestProperty("Accept", "application/json")
        conn.connectTimeout = 12000
        conn.readTimeout = 12000

        val responseCode = conn.responseCode
        if (responseCode != 200) {
            conn.disconnect()
            return
        }

        val reader = BufferedReader(InputStreamReader(conn.inputStream))
        val sb = StringBuilder()
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            sb.append(line)
        }
        reader.close()
        conn.disconnect()

        val json = JSONObject(sb.toString())
        if (!json.optBoolean("success", false)) return

        val items = json.optJSONArray("items") ?: return
        if (items.length() == 0) return

        var lastOrderId = prefs.getLong("flutter.last_notified_order_id", 0L)
        var lastAbandonedId = prefs.getLong("flutter.last_notified_abandoned_id", 0L)
        var lastReviewId = prefs.getLong("flutter.last_notified_review_id", 0L)

        val isInitialized = prefs.getBoolean("flutter.bg_notifications_initialized", false)

        var maxOrderId = lastOrderId
        var maxAbandonedId = lastAbandonedId
        var maxReviewId = lastReviewId

        // On very first run, just memorize latest IDs to prevent spamming old items
        if (!isInitialized) {
            for (i in 0 until items.length()) {
                val item = items.optJSONObject(i) ?: continue
                when (item.optString("type")) {
                    "order" -> {
                        val oid = item.optLong("order_id", 0L)
                        if (oid > maxOrderId) maxOrderId = oid
                    }
                    "abandoned_order" -> {
                        val aid = item.optLong("abandoned_order_id", 0L)
                        if (aid > maxAbandonedId) maxAbandonedId = aid
                    }
                    "review" -> {
                        val rid = item.optLong("review_id", 0L)
                        if (rid > maxReviewId) maxReviewId = rid
                    }
                }
            }
            prefs.edit()
                .putLong("flutter.last_notified_order_id", maxOrderId)
                .putLong("flutter.last_notified_abandoned_id", maxAbandonedId)
                .putLong("flutter.last_notified_review_id", maxReviewId)
                .putBoolean("flutter.bg_notifications_initialized", true)
                .apply()
            return
        }

        // Iterate incoming events and alert for new ones
        for (i in 0 until items.length()) {
            val item = items.optJSONObject(i) ?: continue
            val type = item.optString("type")

            when (type) {
                "order" -> {
                    val orderId = item.optLong("order_id", 0L)
                    if (orderId > lastOrderId) {
                        val orderNum = item.optString("order_number", orderId.toString())
                        val customerName = item.optString("customer_name", "গ্রাহক")
                        val customerPhone = item.optString("customer_phone", "")
                        val amount = item.optDouble("amount", 0.0).toInt()
                        val bookTitle = item.optString("book_title", "বই")

                        val title = "🔔 নতুন অর্ডার: #$orderNum"
                        val body = "$customerName ($customerPhone) • ৳$amount - $bookTitle"

                        NotificationHelper.showNotification(
                            context = context,
                            id = orderId.toInt(),
                            title = title,
                            body = body,
                            type = "order",
                            payload = orderId.toString()
                        )

                        if (orderId > maxOrderId) maxOrderId = orderId
                    }
                }
                "abandoned_order" -> {
                    val abandonedId = item.optLong("abandoned_order_id", 0L)
                    if (abandonedId > lastAbandonedId) {
                        val customerName = item.optString("customer_name", "নামহীন লিড")
                        val customerPhone = item.optString("customer_phone", "")
                        val amount = item.optDouble("amount", 0.0).toInt()

                        val title = "🛒 নতুন পরিত্যক্ত কার্ট লিড"
                        val body = "$customerName ($customerPhone) • ৳$amount"

                        NotificationHelper.showNotification(
                            context = context,
                            id = (abandonedId + 100000).toInt(),
                            title = title,
                            body = body,
                            type = "abandoned_order",
                            payload = abandonedId.toString()
                        )

                        if (abandonedId > maxAbandonedId) maxAbandonedId = abandonedId
                    }
                }
                "review" -> {
                    val reviewId = item.optLong("review_id", 0L)
                    if (reviewId > lastReviewId) {
                        val reviewerName = item.optString("reviewer_name", "শিক্ষার্থী")
                        val rating = item.optInt("rating", 5)
                        val comment = item.optString("comment", "")

                        val title = "⭐ নতুন রিভিউ ($rating★)"
                        val body = "$reviewerName - \"$comment\""

                        NotificationHelper.showNotification(
                            context = context,
                            id = (reviewId + 200000).toInt(),
                            title = title,
                            body = body,
                            type = "review",
                            payload = reviewId.toString()
                        )

                        if (reviewId > maxReviewId) maxReviewId = reviewId
                    }
                }
            }
        }

        prefs.edit()
            .putLong("flutter.last_notified_order_id", maxOrderId)
            .putLong("flutter.last_notified_abandoned_id", maxAbandonedId)
            .putLong("flutter.last_notified_review_id", maxReviewId)
            .apply()
    }
}
