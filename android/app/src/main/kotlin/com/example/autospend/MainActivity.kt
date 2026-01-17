
package com.example.autospend

import android.content.Context
import android.provider.Settings
import android.content.Intent
import android.content.ActivityNotFoundException
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val NOTIF_CHANNEL = "com.example.autospend/notifications"
    private val QUICK_ACTION_CHANNEL = "com.example.autospend/quick_actions"
    private val SMS_CHANNEL = "com.example.autospend/sms"
    private val SETTINGS_CHANNEL = "com.example.autospend/settings"
    private val TAG = "MainActivity"
    
    private val NOTIFICATION_PERMISSION_REQUEST = 1001
    
    private var flutterEngine: FlutterEngine? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Store engine reference for later use
        this.flutterEngine = flutterEngine

        // 1. Notification Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val granted = isNotificationPermissionGranted()
                    Log.d(TAG, "📋 Permission check: $granted")
                    result.success(granted)
                }
                "requestPermission" -> {
                    Log.d(TAG, "🔔 Opening notification settings from Activity context")
                    pendingPermissionResult = result
                    openNotificationSettingsFromActivity()
                }
                "onNotification" -> {
                    // Handle notification callback if needed
                    result.notImplemented()
                }
                "requestAccessibility" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to open accessibility settings", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Set up Notification Callback with thread safety
        NotificationListener.onNotificationCallback = { merchantName, title, text ->
            runOnUiThread {
                try {
                    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL).invokeMethod(
                        "onNotification",
                        mapOf(
                            "merchantName" to merchantName,
                            "title" to title,
                            "text" to text,
                            "timestamp" to System.currentTimeMillis()
                        )
                    )
                    Log.d(TAG, "✅ Notification data sent to Flutter")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to send notification: ${e.message}")
                }
            }
        }

        // 2. Quick Action Channel (Robust Hybrid)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QUICK_ACTION_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkAndConsumeQuickAction") {
                // 1. Flutter asks: "Is there a saved action?"
                // ✅ Use Flutter's SharedPreferences format
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val shouldOpen = prefs.getBoolean("flutter.quick_add_pending", false)

                if (shouldOpen) {
                    // 2. Clear the flag so it doesn't open again next time
                    prefs.edit().remove("flutter.quick_add_pending").apply()
                    result.success("QUICK_ADD_EXPENSE")
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        // 3. SMS Channel (for real-time incoming SMS)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            result.notImplemented()
        }

        // Set up SMS BroadcastReceiver callback with thread safety
        SmsBroadcastReceiver.onSmsReceivedCallback = { sender, body ->
            runOnUiThread {
                try {
                    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).invokeMethod(
                        "onSmsReceived",
                        mapOf(
                            "sender" to sender,
                            "body" to body,
                            "timestamp" to System.currentTimeMillis()
                        )
                    )
                    Log.d(TAG, "✅ SMS data sent to Flutter")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to send SMS: ${e.message}")
                }
            }
        }
        
        // 4. Settings Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAppSettings" -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = android.net.Uri.parse("package:$packageName")
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Check intent immediately upon engine config
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.action == "QUICK_ADD_EXPENSE") {
            // Check if we should skip biometric
            val skipBiometric = intent.getBooleanExtra("skip_biometric", false)
            
            // 3. Save the flag to Flutter's SharedPreferences storage
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean("flutter.quick_add_pending", true)
                .putBoolean("flutter.skip_biometric", skipBiometric)
                .apply()
            
            Log.d(TAG, "🚀 Quick action - Skip biometric: $skipBiometric | Flag saved to flutter.quick_add_pending")
            
            // 4. Try to notify Flutter immediately (if app is already running)
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, QUICK_ACTION_CHANNEL).invokeMethod("onQuickActionReceived", "QUICK_ADD_EXPENSE")
            }
        }
    }
    
    // ✅ Handle return from settings
    override fun onResume() {
        super.onResume()
        
        // Check if we were waiting for permission
        if (pendingPermissionResult != null) {
            Log.d(TAG, "🔄 Returned from settings - checking permission status")
            
            // Small delay to ensure permission change is registered
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                val isGranted = isNotificationPermissionGranted()
                Log.d(TAG, "📋 Permission after returning: $isGranted")
                
                // Don't complete the result yet - let Flutter dialog button handle it
                pendingPermissionResult = null
            }, 500)
        }
    }

    private fun isNotificationPermissionGranted(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        )
        val isGranted = enabledListeners?.contains(packageName) == true
        Log.d(TAG, "🔍 Checking permission - Enabled listeners: $enabledListeners")
        Log.d(TAG, "🔍 Our package: $packageName | Granted: $isGranted")
        return isGranted
    }
    
    // ✅ CRITICAL: Launch from Activity context using startActivityForResult
    private fun openNotificationSettingsFromActivity() {
        try {
            Log.d(TAG, "🚀 Launching settings from ACTIVITY context (Android 14 compatible)")
            
            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            
            // ✅ CRITICAL: Do NOT use FLAG_ACTIVITY_NEW_TASK
            // Using startActivityForResult tells Android we're launching from foreground Activity
            
            startActivityForResult(intent, NOTIFICATION_PERMISSION_REQUEST)
            Log.d(TAG, "✅ Settings launched successfully via startActivityForResult")
            
            // Return success to Flutter immediately
            pendingPermissionResult?.success(null)
            
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ SecurityException: ${e.message}", e)
            pendingPermissionResult?.error("SECURITY_ERROR", e.message, null)
            pendingPermissionResult = null
            
        } catch (e: ActivityNotFoundException) {
            Log.e(TAG, "❌ Activity not found", e)
            
            // Fallback: Try general settings
            try {
                val fallback = Intent(Settings.ACTION_SETTINGS)
                startActivityForResult(fallback, NOTIFICATION_PERMISSION_REQUEST)
                pendingPermissionResult?.success(null)
            } catch (ex: Exception) {
                Log.e(TAG, "❌ Fallback also failed: ${ex.message}", ex)
                pendingPermissionResult?.error("ERROR", ex.message, null)
                pendingPermissionResult = null
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Unexpected error: ${e.message}", e)
            pendingPermissionResult?.error("ERROR", e.message, null)
            pendingPermissionResult = null
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            Log.d(TAG, "📱 User returned from settings (resultCode: $resultCode)")
            // Permission check will happen in onResume
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        NotificationListener.onNotificationCallback = null
        SmsBroadcastReceiver.onSmsReceivedCallback = null
        pendingPermissionResult = null
    }
}
