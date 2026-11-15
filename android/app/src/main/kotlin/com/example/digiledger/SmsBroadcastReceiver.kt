package com.example.digiledger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsBroadcastReceiver : BroadcastReceiver() {
    companion object {
        @Volatile
        var onSmsReceived: ((sender: String, body: String, date: Long) -> Unit)? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNotEmpty()) {
                val fullBody = StringBuilder()
                var sender = ""
                var date = System.currentTimeMillis()
                for (sms in messages) {
                    sender = sms.displayOriginatingAddress ?: sms.originatingAddress ?: "Unknown"
                    date = sms.timestampMillis
                    fullBody.append(sms.displayMessageBody ?: sms.messageBody ?: "")
                }
                val body = fullBody.toString()

                // Save to SharedPreferences so it can be synced if app is not currently open
                try {
                    val prefs = context.getSharedPreferences("digiledger_sms", Context.MODE_PRIVATE)
                    val pendingList = prefs.getStringSet("pending_sms", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                    val encoded = "$date|$sender|${body.replace("\n", "\\n")}"
                    pendingList.add(encoded)
                    prefs.edit().putStringSet("pending_sms", pendingList).apply()
                } catch (_: Exception) {}

                // If app is currently running in foreground, notify real-time stream listener
                onSmsReceived?.invoke(sender, body, date)
            }
        }
    }
}
