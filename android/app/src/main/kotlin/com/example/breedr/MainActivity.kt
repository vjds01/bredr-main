package com.example.breedr

import android.content.Intent
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationChannelName = "breedr/notification_tap"
    private var notificationChannel: MethodChannel? = null
    private var pendingNotificationPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        pendingNotificationPayload = notificationPayload(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationChannelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getInitialNotificationPayload") {
                    result.success(pendingNotificationPayload)
                    pendingNotificationPayload = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = notificationPayload(intent) ?: return
        val channel = notificationChannel
        if (channel == null) {
            pendingNotificationPayload = payload
        } else {
            channel.invokeMethod("notificationTapped", payload)
        }
    }

    private fun notificationPayload(intent: Intent?): String? {
        return intent?.getStringExtra("payload")?.takeIf { it.isNotBlank() }
    }
}
