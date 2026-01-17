package com.example.autospend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsBroadcastReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "SmsBroadcastReceiver"
        
        // Callback to send SMS data to Flutter via MainActivity
        var onSmsReceivedCallback: ((String, String) -> Unit)? = null
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }
        
        Log.d(TAG, "📨 SMS_RECEIVED_ACTION triggered")
        
        // Extract SMS messages from intent
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        
        for (smsMessage in messages) {
            val sender = smsMessage.displayOriginatingAddress ?: continue
            val body = smsMessage.messageBody ?: continue
            
            Log.d(TAG, "📩 New SMS from: $sender")
            Log.d(TAG, "📄 Body preview: ${body.take(100)}...")
            
            // Check if it looks like a bank/UPI SMS
            if (isPotentialBankSms(sender, body)) {
                Log.d(TAG, "✅ Potential bank SMS detected, sending to Flutter...")
                onSmsReceivedCallback?.invoke(sender, body)
            } else {
                Log.d(TAG, "⏭️ Not a bank SMS, skipping")
            }
        }
    }
    
    /**
     * Quick check if SMS might be from a bank/UPI app
     * This is a preliminary filter - actual parsing happens in Flutter
     */
    private fun isPotentialBankSms(sender: String, body: String): Boolean {
        // Check sender format (bank sender IDs are typically XX-XXXXXX format)
        val senderPattern = Regex("^[A-Z]{2}-[A-Z0-9\\-\\.]+$")
        if (!senderPattern.matches(sender)) {
            return false
        }
        
        // Check for money-related keywords
        val lowerBody = body.lowercase()
        val keywords = listOf(
            "debited", "credited", "spent", "paid", "received", 
            "rs.", "rs ", "inr", "₹", "account", "upi", "transaction"
        )
        
        return keywords.any { lowerBody.contains(it) }
    }
}
