package com.aniket.ewallet

import android.Manifest
import android.content.ContentResolver
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.aniket.ewallet/sms"
    private val SMS_PERMISSION_CODE = 100

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "readSms" -> {
                    if (checkSmsPermission()) {
                        val smsList = readSmsMessages()
                        result.success(smsList)
                    } else {
                        requestSmsPermission()
                        result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                    }
                }
                "checkPermission" -> {
                    result.success(checkSmsPermission())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
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
