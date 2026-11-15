package com.example.digiledger

import android.content.Context
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_METHOD_CHANNEL = "com.example.digiledger/sms"
    private val SMS_EVENT_CHANNEL = "com.example.digiledger/sms_stream"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel for querying inbox and queued pending SMS
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInboxSms" -> {
                    try {
                        val limit = (call.argument<Any>("limit") as? Number)?.toInt() ?: 1000
                        val sinceTimestamp = (call.argument<Any>("sinceTimestamp") as? Number)?.toLong() ?: 0L
                        val smsList = queryInboxSms(limit, sinceTimestamp)
                        result.success(smsList)
                    } catch (e: Exception) {
                        result.error("QUERY_ERROR", e.message, null)
                    }
                }
                "getPendingSms" -> {
                    try {
                        val prefs = getSharedPreferences("digiledger_sms", Context.MODE_PRIVATE)
                        val pendingSet = prefs.getStringSet("pending_sms", emptySet()) ?: emptySet()
                        val list = mutableListOf<Map<String, Any>>()
                        for (item in pendingSet) {
                            val parts = item.split("|", limit = 3)
                            if (parts.size == 3) {
                                val timestamp = parts[0].toLongOrNull() ?: System.currentTimeMillis()
                                val sender = parts[1]
                                val body = parts[2].replace("\\n", "\n")
                                list.add(mapOf(
                                    "address" to sender,
                                    "body" to body,
                                    "date" to timestamp
                                ))
                            }
                        }
                        // Clear pending after reading
                        prefs.edit().remove("pending_sms").apply()
                        result.success(list)
                    } catch (e: Exception) {
                        result.error("PREFS_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel for real-time incoming SMS stream
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    SmsBroadcastReceiver.onSmsReceived = { sender, body, date ->
                        runOnUiThread {
                            eventSink?.success(mapOf(
                                "address" to sender,
                                "body" to body,
                                "date" to date
                            ))
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    SmsBroadcastReceiver.onSmsReceived = null
                }
            }
        )
    }

    private fun queryInboxSms(limit: Int, sinceTimestamp: Long): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")
        val projection = arrayOf("_id", "address", "body", "date")

        val selection = if (sinceTimestamp > 0) "date > ?" else null
        val selectionArgs = if (sinceTimestamp > 0) arrayOf(sinceTimestamp.toString()) else null
        val sortOrder = "date DESC"

        contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)?.use { cursor ->
            val idIndex = cursor.getColumnIndex("_id")
            val addressIndex = cursor.getColumnIndex("address")
            val bodyIndex = cursor.getColumnIndex("body")
            val dateIndex = cursor.getColumnIndex("date")

            while (cursor.moveToNext() && list.size < limit) {
                val id = if (idIndex >= 0) cursor.getString(idIndex) ?: "" else ""
                val address = if (addressIndex >= 0) cursor.getString(addressIndex) ?: "Unknown" else "Unknown"
                val body = if (bodyIndex >= 0) cursor.getString(bodyIndex) ?: "" else ""
                val date = if (dateIndex >= 0) cursor.getLong(dateIndex) else 0L

                list.add(mapOf(
                    "id" to id,
                    "address" to address,
                    "body" to body,
                    "date" to date
                ))
            }
        }
        return list
    }
}
