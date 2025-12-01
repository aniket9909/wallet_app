package com.aniket.ewallet

import android.Manifest
import android.content.ContentResolver
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.provider.Telephony
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.aniket.ewallet/sms"
    private val EVENT_CHANNEL = "com.aniket.ewallet/sms_events"
    private val SMS_PERMISSION_CODE = 100
    private val TAG = "MainActivity"
    
    companion object {
        @Volatile
        var eventSink: EventChannel.EventSink? = null
            private set
        
        fun setEventSink(sink: EventChannel.EventSink?) {
            val TAG = "MainActivity"
            Log.d(TAG, "========== SETTING EVENT SINK ==========")
            Log.d(TAG, "Previous eventSink: ${eventSink != null}")
            Log.d(TAG, "New eventSink: ${sink != null}")
            eventSink = sink
            Log.d(TAG, "EventSink set successfully: ${eventSink != null}")
            Log.d(TAG, "========================================")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "========== CONFIGURING FLUTTER ENGINE ==========")
        
        // MethodChannel for reading SMS
        Log.d(TAG, "Setting up MethodChannel: $CHANNEL")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "MethodChannel called: ${call.method}")
            when (call.method) {
                "readSms" -> {
                    Log.d(TAG, "readSms method called")
                    if (checkSmsPermission()) {
                        Log.d(TAG, "SMS permission granted, reading SMS...")
                        val smsList = readSmsMessages()
                        result.success(smsList)
                    } else {
                        Log.d(TAG, "SMS permission not granted, requesting...")
                        requestSmsPermission()
                        result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                    }
                }
                "checkPermission" -> {
                    Log.d(TAG, "checkPermission method called")
                    val hasPermission = checkSmsPermission()
                    Log.d(TAG, "Permission check result: $hasPermission")
                    result.success(hasPermission)
                }
                else -> {
                    Log.d(TAG, "Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
        
        // EventChannel for real-time SMS events
        Log.d(TAG, "Setting up EventChannel: $EVENT_CHANNEL")
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.d(TAG, "========== EVENT CHANNEL ON LISTEN ==========")
                    Log.d(TAG, "Arguments: $arguments")
                    Log.d(TAG, "Events sink: ${events != null}")
                    setEventSink(events)
                    Log.d(TAG, "EventChannel listener registered successfully")
                    Log.d(TAG, "==============================================")
                }

                override fun onCancel(arguments: Any?) {
                    Log.d(TAG, "========== EVENT CHANNEL ON CANCEL ==========")
                    Log.d(TAG, "Arguments: $arguments")
                    setEventSink(null)
                    Log.d(TAG, "EventChannel listener cancelled")
                    Log.d(TAG, "============================================")
                }
            }
        )
        
        Log.d(TAG, "Flutter engine configuration completed")
        Log.d(TAG, "==========================================")
    }

    private fun checkSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_SMS),
            SMS_PERMISSION_CODE
        )
    }

    private fun readSmsMessages(): String {
        val smsList = JSONArray()
        val contentResolver: ContentResolver = contentResolver
        val uri: Uri = Telephony.Sms.Inbox.CONTENT_URI
        val cursor: Cursor? = contentResolver.query(
            uri,
            arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.ADDRESS
            ),
            null,
            null,
            "${Telephony.Sms.DATE} DESC"
        )

        cursor?.use {
            val idIndex = it.getColumnIndex(Telephony.Sms._ID)
            val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
            val dateIndex = it.getColumnIndex(Telephony.Sms.DATE)
            val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)

            var count = 0
            val maxCount = 200
            while (it.moveToNext() && count < maxCount) {
                val sms = JSONObject()
                sms.put("id", if (idIndex >= 0) it.getLong(idIndex) else 0)
                sms.put("body", if (bodyIndex >= 0) it.getString(bodyIndex) else "")
                sms.put("date", if (dateIndex >= 0) it.getLong(dateIndex) else System.currentTimeMillis())
                sms.put("address", if (addressIndex >= 0) it.getString(addressIndex) else "")
                smsList.put(sms)
                count++
            }
        }

        return smsList.toString()
    }
}
