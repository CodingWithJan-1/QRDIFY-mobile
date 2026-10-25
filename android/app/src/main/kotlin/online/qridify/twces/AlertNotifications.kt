package online.qridify.twces

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import io.flutter.plugin.common.MethodChannel

class AlertNotifications(private val activity: Activity, private val channel: MethodChannel) {
    private val manager = activity.getSystemService(NotificationManager::class.java)
    private var pending: Map<String, String>? = null

    init {
        if (Build.VERSION.SDK_INT >= 26) {
            val alerts = NotificationChannel("qrdify_alerts", "School alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Attendance and school updates"
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                enableVibration(true)
                setShowBadge(true)
            }
            manager.createNotificationChannel(alerts)
        }
        capture(activity.intent, false)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> result.success(null)
                "channelEnabled" -> result.success(manager.areNotificationsEnabled() &&
                    (Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel("qrdify_alerts")?.importance != NotificationManager.IMPORTANCE_NONE))
                "initialMessage" -> { result.success(pending); pending = null }
                "show" -> {
                    val data = call.arguments as? Map<*, *>
                    if (data != null) show(data)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun capture(intent: Intent?, notifyFlutter: Boolean = true) {
        val id = intent?.getStringExtra("qrdify_notification_id") ?: return
        val data = mapOf("notification_id" to id,
            "user_id" to (intent.getStringExtra("qrdify_user_id") ?: ""),
            "student_id" to (intent.getStringExtra("qrdify_student_id") ?: ""))
        intent.removeExtra("qrdify_notification_id")
        if (notifyFlutter) channel.invokeMethod("open", data) else pending = data
    }

    @Suppress("DEPRECATION")
    private fun show(data: Map<*, *>) {
        if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val id = data["notification_id"] as? String ?: return
        val intent = Intent(activity, MainActivity::class.java).apply {
            action = "online.qridify.twces.alert.$id"
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("qrdify_notification_id", id)
            putExtra("qrdify_user_id", data["user_id"] as? String ?: "")
            putExtra("qrdify_student_id", data["student_id"] as? String ?: "")
        }
        val open = PendingIntent.getActivity(activity, id.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(activity, "qrdify_alerts") else Notification.Builder(activity)
        val notification = builder.setSmallIcon(R.drawable.ic_stat_qrdify)
            .setContentTitle("QRDify school update").setContentText("A new alert is available. Open QRDify to view it.")
            .setContentIntent(open).setAutoCancel(true).setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_EVENT)
            .setVisibility(Notification.VISIBILITY_PRIVATE).setPriority(Notification.PRIORITY_HIGH)
            .setDefaults(Notification.DEFAULT_SOUND or Notification.DEFAULT_VIBRATE).build()
        manager.notify(id, 0, notification)
    }
}
