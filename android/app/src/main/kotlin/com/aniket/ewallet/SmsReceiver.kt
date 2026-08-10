package com.aniket.ewallet

import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SMS_FETCH"
        private const val CHANNEL_ID = "sms_txn_overlay"
        private const val NOTIFICATION_ID_BASE = 71000
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        try {
            handleSms(context.applicationContext, intent)
        } catch (e: Exception) {
            Log.e(TAG, "ERROR Unhandled SMS receiver error: ${e.message}", e)
        } finally {
            pendingResult.finish()
        }
    }

    private fun handleSms(context: Context, intent: Intent) {
        val action = intent.action.orEmpty()
        Log.i(TAG, "========== SMS RECEIVED ==========")
        Log.i(TAG, "action=$action")

        val isDataSms = action == Telephony.Sms.Intents.DATA_SMS_RECEIVED_ACTION ||
            action == "android.provider.Telephony.DATA_SMS_RECEIVED"
        val isTextSms = action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION ||
            action == "android.provider.Telephony.SMS_RECEIVED"

        if (!isDataSms && !isTextSms) {
            Log.w(TAG, "Ignored unsupported action: $action")
            return
        }

        val messages = extractMessages(intent)
        Log.i(TAG, "pduCount=${messages.size} kind=${if (isDataSms) "data" else "text"}")
        if (messages.isEmpty()) {
            Log.e(TAG, "No SMS PDUs found — fetch failed")
            return
        }

        for ((index, smsMessage) in messages.withIndex()) {
            try {
                val messageBody = SmsPayloadDecoder.extractText(smsMessage)
                val senderNumber = smsMessage.originatingAddress.orEmpty()
                val timestamp = smsMessage.timestampMillis.takeIf { it > 0 }
                    ?: System.currentTimeMillis()

                Log.i(TAG, "---- message #${index + 1} ----")
                Log.i(TAG, "from=${senderNumber.ifEmpty { "(empty)" }}")
                Log.i(TAG, "time=$timestamp")
                Log.i(TAG, "bodyLen=${messageBody.length}")
                Log.i(TAG, "body=${messageBody.take(200)}")
                Log.i(TAG, "appForeground=${MainActivity.isInForeground}")
                Log.i(TAG, "flutterListening=${MainActivity.eventSink != null}")

                if (messageBody.isBlank()) {
                    Log.w(TAG, "Empty body after decode — skip")
                    continue
                }

                forwardToFlutter(messageBody, senderNumber, timestamp, isDataSms)

                var detection = SmsTxnDetector.detect(messageBody, senderNumber)
                if (detection == null && SmsTxnDetector.isTestSender(senderNumber)) {
                    Log.i(TAG, "TEMP TEST: accepting SMS from $senderNumber as transaction")
                    detection = SmsTxnDetection(
                        isCredit = false,
                        amount = 1.0,
                        transactionType = "debit",
                    )
                }

                // TEMP: do not skip non-txn SMS while testing — still show overlay with msg + number.
                // if (detection == null) {
                //     Log.w(TAG, "RESULT: not credit/debit+amount → NO overlay")
                //     continue
                // }

                val amount = detection?.amount ?: 0.0
                val type = detection?.transactionType ?: "debit"
                Log.i(TAG, "RESULT: type=$type amount=$amount from=$senderNumber")

                // TEMP: always show overlay (even if app is in foreground) for testing.
                // if (MainActivity.isInForeground) {
                //     Log.i(TAG, "App open → Flutter sheet handles UI (skip native overlay)")
                //     continue
                // }

                Log.i(TAG, "Showing overlay / full-screen notification")
                presentOverlayWhenBackgrounded(
                    context = context,
                    body = messageBody,
                    address = senderNumber,
                    date = timestamp,
                    amount = amount,
                    type = type,
                )
            } catch (e: Exception) {
                Log.e(TAG, "ERROR processing SMS: ${e.message}", e)
            }
        }

        Log.i(TAG, "========== SMS RECEIVER DONE ==========")
    }

    private fun forwardToFlutter(
        body: String,
        address: String,
        date: Long,
        isDataSms: Boolean,
    ) {
        val smsData = JSONObject().apply {
            put("body", body)
            put("address", address)
            put("date", date)
            put("id", System.currentTimeMillis())
            put("smsKind", if (isDataSms) "data" else "text")
        }
        val eventSink = MainActivity.eventSink
        if (eventSink != null) {
            try {
                eventSink.success(smsData.toString())
            } catch (e: Exception) {
                Log.e(TAG, "ERROR sending to eventSink: ${e.message}", e)
            }
        } else {
            Log.w(TAG, "eventSink is NULL — Flutter not listening (app may be closed)")
        }
    }

    private fun presentOverlayWhenBackgrounded(
        context: Context,
        body: String,
        address: String,
        date: Long,
        amount: Double,
        type: String,
    ) {
        wakeScreenBriefly(context)

        // 1) Always post high-priority notification with full-screen intent.
        //    This is the reliable path when the app process was closed.
        postHeadsUpAndFullscreen(
            context = context,
            body = body,
            address = address,
            date = date,
            amount = amount,
            type = type,
        )

        // 2) Best-effort direct launch (works on some OEMs / if exemptions apply).
        tryLaunchOverlayActivity(context, body, address, date, amount, type)
    }

    private fun tryLaunchOverlayActivity(
        context: Context,
        body: String,
        address: String,
        date: Long,
        amount: Double,
        type: String,
    ) {
        val canDrawOverlay = Settings.canDrawOverlays(context)
        Log.d(TAG, "tryLaunchOverlayActivity canDrawOverlays=$canDrawOverlay")

        val overlayIntent = Intent(context, SmsOverlayActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                Intent.FLAG_ACTIVITY_NO_USER_ACTION
            putExtra(SmsOverlayActivity.EXTRA_BODY, body)
            putExtra(SmsOverlayActivity.EXTRA_ADDRESS, address)
            putExtra(SmsOverlayActivity.EXTRA_DATE, date)
            putExtra(SmsOverlayActivity.EXTRA_AMOUNT, amount)
            putExtra(SmsOverlayActivity.EXTRA_TYPE, type)
        }

        try {
            context.startActivity(overlayIntent)
            Log.d(TAG, "startActivity(SmsOverlayActivity) requested")
        } catch (e: Exception) {
            Log.e(TAG, "Direct overlay launch blocked/failed: ${e.message}", e)
        }
    }

    private fun postHeadsUpAndFullscreen(
        context: Context,
        body: String,
        address: String,
        date: Long,
        amount: Double,
        type: String,
    ) {
        ensureNotificationChannel(context)

        val overlayIntent = Intent(context, SmsOverlayActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            putExtra(SmsOverlayActivity.EXTRA_BODY, body)
            putExtra(SmsOverlayActivity.EXTRA_ADDRESS, address)
            putExtra(SmsOverlayActivity.EXTRA_DATE, date)
            putExtra(SmsOverlayActivity.EXTRA_AMOUNT, amount)
            putExtra(SmsOverlayActivity.EXTRA_TYPE, type)
        }

        val contentIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(SmsOverlayActivity.EXTRA_OPEN_SYNC, true)
            putExtra(SmsOverlayActivity.EXTRA_BODY, body)
            putExtra(SmsOverlayActivity.EXTRA_ADDRESS, address)
            putExtra(SmsOverlayActivity.EXTRA_DATE, date)
            putExtra(SmsOverlayActivity.EXTRA_AMOUNT, amount)
            putExtra(SmsOverlayActivity.EXTRA_TYPE, type)
        }

        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        val requestCode = (date % Int.MAX_VALUE).toInt()
        val fullScreenPending = PendingIntent.getActivity(
            context,
            requestCode,
            overlayIntent,
            pendingFlags,
        )
        val contentPending = PendingIntent.getActivity(
            context,
            requestCode + 1,
            contentIntent,
            pendingFlags,
        )

        val title = if (type == "credit") "Credit SMS received" else "Debit SMS received"
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(title)
            .setContentText("₹${"%.2f".format(amount)} from ${address.ifEmpty { "bank" }}")
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(contentPending)
            .setFullScreenIntent(fullScreenPending, true)
            .setTimeoutAfter(60_000)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(
                NOTIFICATION_ID_BASE + (date % 1000).toInt(),
                notification,
            )
            Log.d(TAG, "Posted heads-up + full-screen intent notification")
        } catch (e: SecurityException) {
            Log.e(TAG, "Notification permission denied: ${e.message}")
        }
    }

    private fun wakeScreenBriefly(context: Context) {
        try {
            val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = power.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "ewallet:sms_overlay",
            )
            wakeLock.acquire(3_000)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                // No-op here; SmsOverlayActivity handles show-when-locked.
                Log.d(TAG, "Keyguard locked=${keyguard.isKeyguardLocked}")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Wake screen failed: ${e.message}")
        }
    }

    private fun extractMessages(intent: Intent): List<SmsMessage> {
        return try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)?.filterNotNull().orEmpty()
                .ifEmpty { extractFromPdus(intent) }
        } catch (e: Exception) {
            Log.e(TAG, "getMessagesFromIntent failed, fallback to PDUs: ${e.message}")
            extractFromPdus(intent)
        }
    }

    private fun extractFromPdus(intent: Intent): List<SmsMessage> {
        val bundle: Bundle = intent.extras ?: return emptyList()
        val pdus = bundle.get("pdus") as? Array<*> ?: return emptyList()
        val format = bundle.getString("format")
        val messages = mutableListOf<SmsMessage>()
        for (pdu in pdus) {
            if (pdu !is ByteArray) continue
            val sms = if (format != null) {
                SmsMessage.createFromPdu(pdu, format)
            } else {
                @Suppress("DEPRECATION")
                SmsMessage.createFromPdu(pdu)
            }
            if (sms != null) messages.add(sms)
        }
        return messages
    }

    private fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null && existing.importance < NotificationManager.IMPORTANCE_HIGH) {
            manager.deleteNotificationChannel(CHANNEL_ID)
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SMS Transactions",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Popup alerts for bank debit/credit SMS"
            enableVibration(true)
            setShowBadge(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }
}
