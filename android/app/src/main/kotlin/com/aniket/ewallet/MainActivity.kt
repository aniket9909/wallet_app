package com.aniket.ewallet

import android.Manifest
import android.content.ContentResolver
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.provider.Telephony
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aniket.ewallet/sms"
    private val EVENT_CHANNEL = "com.aniket.ewallet/sms_events"
    private val SMS_PERMISSION_CODE = 100
    private val TAG = "MainActivity"

    private var methodChannel: MethodChannel? = null
    private var pendingSyncPayload: Map<String, Any?>? = null

    companion object {
        @Volatile
        var eventSink: EventChannel.EventSink? = null
            private set

        @Volatile
        var isInForeground: Boolean = false
            private set

        fun setEventSink(sink: EventChannel.EventSink?) {
            val TAG = "MainActivity"
            Log.d(TAG, "Setting eventSink: ${sink != null}")
            eventSink = sink
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureSyncIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureSyncIntent(intent)
        deliverPendingSyncIfReady()
    }

    override fun onResume() {
        super.onResume()
        isInForeground = true
        deliverPendingSyncIfReady()
    }

    override fun onPause() {
        isInForeground = false
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "Configuring Flutter engine")

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "readSms" -> {
                    if (checkSmsPermission()) {
                        result.success(readSmsMessages())
                    } else {
                        requestSmsPermission()
                        result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                    }
                }
                "checkPermission" -> {
                    result.success(checkSmsPermission())
                }
                "canDrawOverlays" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                "getPendingSmsSync" -> {
                    val payload = pendingSyncPayload
                    pendingSyncPayload = null
                    result.success(payload)
                }
                "cacheOverlayData" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as? Map<String, Any?>
                    val accountsJson = args?.get("accountsJson") as? String ?: "[]"
                    val categoriesJson = args?.get("categoriesJson") as? String ?: "[]"
                    val plannerSubtypesJson = args?.get("plannerSubtypesJson") as? String
                    val uid = args?.get("uid") as? String
                    val idToken = args?.get("idToken") as? String
                    val dbUrl = args?.get("dbUrl") as? String
                    OverlayFirebaseRepository.saveCache(
                        this,
                        accountsJson,
                        categoriesJson,
                        plannerSubtypesJson,
                        uid,
                        idToken,
                        dbUrl,
                    )
                    result.success(true)
                }
                "showTestSmsOverlay" -> {
                    showTestSmsOverlay()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    setEventSink(null)
                }
            },
        )
    }

    private fun captureSyncIntent(intent: Intent?) {
        if (intent == null) return
        if (!intent.getBooleanExtra(SmsOverlayActivity.EXTRA_OPEN_SYNC, false)) return

        pendingSyncPayload = mapOf(
            "body" to intent.getStringExtra(SmsOverlayActivity.EXTRA_BODY),
            "address" to intent.getStringExtra(SmsOverlayActivity.EXTRA_ADDRESS),
            "date" to intent.getLongExtra(SmsOverlayActivity.EXTRA_DATE, System.currentTimeMillis()),
            "amount" to intent.getDoubleExtra(SmsOverlayActivity.EXTRA_AMOUNT, 0.0),
            "type" to intent.getStringExtra(SmsOverlayActivity.EXTRA_TYPE),
            "account" to intent.getStringExtra(SmsOverlayActivity.EXTRA_ACCOUNT),
            "category" to intent.getStringExtra(SmsOverlayActivity.EXTRA_CATEGORY),
            "plannerSection" to intent.getStringExtra(SmsOverlayActivity.EXTRA_PLANNER_SECTION),
            "openSync" to true,
        )

        // Clear so we don't re-process on configuration changes alone.
        intent.removeExtra(SmsOverlayActivity.EXTRA_OPEN_SYNC)
    }

    private fun deliverPendingSyncIfReady() {
        val payload = pendingSyncPayload ?: return
        val channel = methodChannel ?: return
        try {
            channel.invokeMethod(
                "onSmsSyncRequest",
                payload,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        // Cleared only after Dart acknowledges.
                        if (pendingSyncPayload == payload) {
                            pendingSyncPayload = null
                        }
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.w(TAG, "onSmsSyncRequest error: $errorCode $errorMessage")
                    }

                    override fun notImplemented() {
                        Log.w(TAG, "onSmsSyncRequest not implemented on Dart side")
                    }
                },
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to deliver sync payload: ${e.message}", e)
        }
    }

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName"),
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun showTestSmsOverlay() {
        val sampleBody =
            "Dear Customer, Your A/c XX1234 is debited for INR 1,250.00 on 09-08-2026. " +
                "Info: UPI/merchant@okaxis. Avl Bal INR 24,380.50 - Axis Bank"
        val overlayIntent = Intent(this, SmsOverlayActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            putExtra(SmsOverlayActivity.EXTRA_BODY, sampleBody)
            putExtra(SmsOverlayActivity.EXTRA_ADDRESS, "AX-AIBK-S")
            putExtra(SmsOverlayActivity.EXTRA_DATE, System.currentTimeMillis())
            putExtra(SmsOverlayActivity.EXTRA_AMOUNT, 1250.0)
            putExtra(SmsOverlayActivity.EXTRA_TYPE, "debit")
        }
        try {
            startActivity(overlayIntent)
            Log.d(TAG, "Launched test SmsOverlayActivity")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch test overlay: ${e.message}", e)
        }
    }

    private fun checkSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_SMS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission() {
        val permissions = mutableListOf(Manifest.permission.READ_SMS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        ActivityCompat.requestPermissions(
            this,
            permissions.toTypedArray(),
            SMS_PERMISSION_CODE,
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
                Telephony.Sms.ADDRESS,
            ),
            null,
            null,
            "${Telephony.Sms.DATE} DESC",
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
