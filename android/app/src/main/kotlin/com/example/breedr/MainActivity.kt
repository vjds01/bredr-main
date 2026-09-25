package com.example.breedr

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
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

        // Protect every Breedr screen from screenshots, screen recordings, and
        // previews in Android's recent-apps view. Android displays its own
        // security-policy warning when the user attempts to capture the screen.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
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
