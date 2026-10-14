package online.qridify.twces

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build

class MainActivity : FlutterActivity() {
    private var notificationResult: MethodChannel.Result? = null
    private val notificationRequestCode = 7019

    private fun notificationsEnabled(): Boolean {
        val manager = getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Channel ID from the locked geolocator_android 5.0.3 source.
            // Verify this integration when upgrading the location plugin.
            val channel = manager.getNotificationChannel("geolocator_channel_01")
            if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "online.qridify.twces/security")
            .setMethodCallHandler { call, result ->
                val preferences = getSharedPreferences("session_security", MODE_PRIVATE)
                when (call.method) {
                    "trackingNotificationsEnabled" -> result.success(notificationsEnabled())
                    "requestTrackingNotifications" -> {
                        if (notificationsEnabled()) {
                            result.success(true)
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            if (notificationResult != null) {
                                result.error("permission_pending", "A permission request is already pending.", null)
                            } else {
                                notificationResult = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationRequestCode)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "isSessionRevoked" -> result.success(preferences.getBoolean("revoked", false))
                    "setSessionRevoked" -> {
                        val revoked = call.arguments as? Boolean
                        if (revoked == null) {
                            result.error("invalid_argument", "A boolean is required.", null)
                        } else if (preferences.edit().putBoolean("revoked", revoked).commit()) {
                            result.success(null)
                        } else {
                            result.error("storage_failed", "Unable to save the session state.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationRequestCode) {
            notificationResult?.success(notificationsEnabled())
            notificationResult = null
        }
    }

    override fun onDestroy() {
        notificationResult?.error("activity_destroyed", "Permission request was interrupted.", null)
        notificationResult = null
        super.onDestroy()
    }
}
