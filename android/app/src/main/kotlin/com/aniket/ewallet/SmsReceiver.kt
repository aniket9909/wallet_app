package com.aniket.ewallet

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telephony.SmsMessage
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
        private const val CHANNEL_ID = "sms_txn_overlay"
        private const val NOTIFICATION_ID_BASE = 71000
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========== SMS RECEIVER CALLED ==========")

        val bundle: Bundle? = intent.extras
        if (bundle == null) {
            Log.e(TAG, "Bundle is null!")
            return
        }

        val pdus = bundle.get("pdus") as? Array<*>
        val format = bundle.getString("format")
        if (pdus == null) {
            Log.e(TAG, "PDUs array is null!")
            return
        }

        for (pdu in pdus) {
            try {
                val smsMessage = if (format != null) {
                    SmsMessage.createFromPdu(pdu as ByteArray, format)
                } else {
                    SmsMessage.createFromPdu(pdu as ByteArray)
                }

                val messageBody = smsMessage?.messageBody ?: ""
                val senderNumber = smsMessage?.originatingAddress ?: ""
                val timestamp = smsMessage?.timestampMillis ?: System.currentTimeMillis()

                val smsData = JSONObject().apply {
                    put("body", messageBody)
                    put("address", senderNumber)
                    put("date", timestamp)
                    put("id", System.currentTimeMillis())
                }

                val eventSink = MainActivity.eventSink
                if (eventSink != null) {
                    try {
                        eventSink.success(smsData.toString())
                    } catch (e: Exception) {
                        Log.e(TAG, "ERROR sending to eventSink: ${e.message}", e)
                    }
                } else {
                    Log.w(TAG, "eventSink is NULL — Flutter not listening")
                }

                val detection = SmsTxnDetector.detect(messageBody) ?: continue

                // Avoid double UI when the in-app sync sheet will show.
                if (MainActivity.isInForeground) {
                    Log.d(TAG, "App in foreground — skip native overlay")
                    continue
                }

                showOverlayOrNotification(
                    context = context,
                    body = messageBody,
                    address = senderNumber,
                    date = timestamp,
                    amount = detection.amount,
                    type = detection.transactionType,
                )
            } catch (e: Exception) {
                Log.e(TAG, "ERROR processing SMS PDU: ${e.message}", e)
            }
        }

        Log.d(TAG, "========== SMS RECEIVER FINISHED ==========")
    }

    private fun showOverlayOrNotification(
        context: Context,
        body: String,
        address: String,
        date: Long,
        amount: Double,
        type: String,
    ) {
        val canDrawOverlay = Settings.canDrawOverlays(context)
        if (canDrawOverlay) {
            val overlayIntent = Intent(context, SmsOverlayActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                putExtra(SmsOverlayActivity.EXTRA_BODY, body)
                putExtra(SmsOverlayActivity.EXTRA_ADDRESS, address)
                putExtra(SmsOverlayActivity.EXTRA_DATE, date)
                putExtra(SmsOverlayActivity.EXTRA_AMOUNT, amount)
                putExtra(SmsOverlayActivity.EXTRA_TYPE, type)
            }
            try {
                context.startActivity(overlayIntent)
                Log.d(TAG, "Launched SmsOverlayActivity")
                return
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch overlay: ${e.message}", e)
            }
        } else {
            Log.w(TAG, "Overlay permission not granted — using notification")
        }

        postSyncNotification(context, body, address, date, amount, type)
    }

    private fun postSyncNotification(
        context: Context,
        body: String,
        address: String,
        date: Long,
        amount: Double,
        type: String,
    ) {
        ensureNotificationChannel(context)

        val launch = Intent(context, MainActivity::class.java).apply {
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

        val pendingIntent = PendingIntent.getActivity(
            context,
            (date % Int.MAX_VALUE).toInt(),
            launch,
            pendingFlags,
        )

        val title = if (type == "credit") "Credit SMS received" else "Debit SMS received"
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(title)
            .setContentText("₹${"%.2f".format(amount)} from ${address.ifEmpty { "bank" }} — tap to sync")
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(
                NOTIFICATION_ID_BASE + (date % 1000).toInt(),
                notification,
            )
        } catch (e: SecurityException) {
            Log.e(TAG, "Notification permission denied: ${e.message}")
        }
    }

    private fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SMS Transactions",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alerts for bank debit/credit SMS"
        }
        manager.createNotificationChannel(channel)
    }
}
