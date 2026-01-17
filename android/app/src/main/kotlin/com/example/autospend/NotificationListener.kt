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
        Log.d(TAG, "🔗 NotificationListener CONNECTED at ${System.currentTimeMillis()}")
        Log.d(TAG, "✅ Service is ACTIVE and ready to receive notifications")
    }
    
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "❌❌❌ NotificationListener DISCONNECTED at ${System.currentTimeMillis()} ❌❌❌")
        Log.d(TAG, "⚠️ Service stopped - notifications will NOT be captured!")
        
        // Try to reconnect
        requestRebind(android.content.ComponentName(this, NotificationListener::class.java))
        Log.d(TAG, "🔄 Requested rebind to reconnect service")
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        val timestamp = System.currentTimeMillis()
        
        Log.d(TAG, "🔔 Notification received at $timestamp from: $packageName")
        
        // Only process UPI apps
        if (!isUpiApp(packageName)) {
            Log.d(TAG, "   ⏭️ Skipped - Not a UPI app")
            return
        }
        
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return
        
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        
        // Must contain rupee symbol
        if (!title.contains("₹") && !text.contains("₹")) {
            Log.d(TAG, "   ⏭️ Skipped - No rupee symbol found")
            return
        }
        
        Log.d(TAG, "")
        Log.d(TAG, "💰💰💰 PAYMENT NOTIFICATION DETECTED! 💰💰💰")
        Log.d(TAG, "   Package: $packageName")
        Log.d(TAG, "   Title: $title")
        Log.d(TAG, "   Text: $text")
        
        // Extract merchant name and send to Flutter via callback
        val merchantName = extractMerchantName(title, text, packageName)
        Log.d(TAG, "   📝 Extracted merchant: $merchantName")
        
        if (onNotificationCallback != null) {
            onNotificationCallback?.invoke(merchantName, title, text)
            Log.d(TAG, "   ✅ Sent to Flutter successfully")
        } else {
            Log.d(TAG, "   ❌ WARNING: Callback is NULL - data NOT sent to Flutter!")
        }
        Log.d(TAG, "")
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // Don't care about removed notifications
    }
    
    private fun extractMerchantName(title: String, text: String, packageName: String): String {
        val combined = "$title $text"
        
        // Pattern 1: "Name sent you ₹X" or "Name paid you ₹X"
        // ✅ Fixed: Now handles ALL CAPS names like "PREETHAM H M"
        val sentPattern = Regex("""([A-Z][A-Za-z\s]+?)\s+(?:sent|paid)\s+you""", RegexOption.IGNORE_CASE)
        sentPattern.find(combined)?.let { match ->
            return match.groupValues[1].trim()
        }
        
        // Pattern 2: "Received from Name" or "Payment from Name"
        val fromPattern = Regex("""(?:from|by)\s+([A-Z][A-Za-z\s]+?)(?:\s+via|\s+on|\s*₹|$)""", RegexOption.IGNORE_CASE)
        fromPattern.find(combined)?.let { match ->
            return match.groupValues[1].trim()
        }
        
        // Pattern 3: "Name: ₹X" (common in some apps)
        val colonPattern = Regex("""([A-Z][A-Za-z\s]+?)\s*:\s*₹""")
        colonPattern.find(combined)?.let { match ->
            return match.groupValues[1].trim()
        }
        
        // Pattern 4: Look for capitalized names before "via" or "on"
        val viaPattern = Regex("""([A-Z][A-Za-z\s]+?)\s+(?:via|on|using)""", RegexOption.IGNORE_CASE)
        viaPattern.find(combined)?.let { match ->
            return match.groupValues[1].trim()
        }
        
        // Fallback: Use friendly app name
        return when (packageName) {
            "net.one97.paytm" -> "Paytm Payment"
            "com.phonepe.app" -> "PhonePe Payment"
            "com.google.android.apps.nbu.paisa.user" -> "Google Pay Payment"
            "in.org.npci.upiapp" -> "BHIM Payment"
            "com.whatsapp" -> "WhatsApp Payment"
            "com.amazon.mShop.android.shopping" -> "Amazon Pay Payment"
            "com.mobikwik_new" -> "MobiKwik Payment"
            "com.freecharge.android" -> "FreeCharge Payment"
            else -> "UPI Payment"
        }
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
