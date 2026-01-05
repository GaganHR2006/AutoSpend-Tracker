package com.example.autospend

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class NotificationListener : NotificationListenerService() {
    
    companion object {
        private const val TAG = "NotificationListener"
        var instance: NotificationListener? = null
        
        // Callback to send data to Flutter
        var onNotificationCallback: ((String, String, String) -> Unit)? = null
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "✅ NotificationListener service created")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "❌ NotificationListener service destroyed")
    }
    
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "🔗 NotificationListener connected!")
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        
        // Only process UPI apps
        if (!isUpiApp(packageName)) return
        
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return
        
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        
        // Must contain rupee symbol
        if (!title.contains("₹") && !text.contains("₹")) return
        
        Log.d(TAG, "💰 Payment notification detected!")
        Log.d(TAG, "Package: $packageName")
        Log.d(TAG, "Title: $title")
        Log.d(TAG, "Text: $text")
        
        // Send to Flutter via callback
        onNotificationCallback?.invoke(packageName, title, text)
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // Don't care about removed notifications
    }
    
    private fun isUpiApp(packageName: String): Boolean {
        return when (packageName) {
            "net.one97.paytm" -> true           // Paytm
            "com.phonepe.app" -> true           // PhonePe
            "com.google.android.apps.nbu.paisa.user" -> true  // Google Pay
            "in.org.npci.upiapp" -> true        // BHIM
            "com.whatsapp" -> true              // WhatsApp Pay
            "com.amazon.mShop.android.shopping" -> true  // Amazon Pay
            "com.mobikwik_new" -> true          // MobiKwik
            "com.freecharge.android" -> true    // FreeCharge
            else -> false
        }
    }
}
