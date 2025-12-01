package com.aniket.ewallet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.telephony.SmsMessage
import android.util.Log
import org.json.JSONObject

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========== SMS RECEIVER CALLED ==========")
        Log.d(TAG, "Intent action: ${intent.action}")
        Log.d(TAG, "Intent extras: ${intent.extras != null}")
        
        val bundle: Bundle? = intent.extras
        if (bundle == null) {
            Log.e(TAG, "Bundle is null!")
            return
        }
        
        Log.d(TAG, "Bundle is not null, checking for pdus...")
        val pdus = bundle.get("pdus") as? Array<*>
        val format = bundle.getString("format")
        
        Log.d(TAG, "PDUs: ${pdus != null}, Count: ${pdus?.size ?: 0}")
        Log.d(TAG, "Format: $format")
        
        if (pdus == null) {
            Log.e(TAG, "PDUs array is null!")
            return
        }
        
        Log.d(TAG, "Processing ${pdus.size} SMS message(s)...")
        
        for ((index, pdu) in pdus.withIndex()) {
            Log.d(TAG, "Processing PDU $index of ${pdus.size}")
            
            try {
                val smsMessage = if (format != null) {
                    Log.d(TAG, "Creating SMS message with format: $format")
                    SmsMessage.createFromPdu(pdu as ByteArray, format)
                } else {
                    Log.d(TAG, "Creating SMS message without format")
                    SmsMessage.createFromPdu(pdu as ByteArray)
                }
                
                val messageBody = smsMessage?.messageBody ?: ""
                val senderNumber = smsMessage?.originatingAddress ?: ""
                val timestamp = smsMessage?.timestampMillis ?: System.currentTimeMillis()
                
                Log.d(TAG, "SMS Details:")
                Log.d(TAG, "  From: $senderNumber")
                Log.d(TAG, "  Body: $messageBody")
                Log.d(TAG, "  Timestamp: $timestamp")
                
                // Create JSON object with SMS data
                val smsData = JSONObject().apply {
                    put("body", messageBody)
                    put("address", senderNumber)
                    put("date", timestamp)
                    put("id", System.currentTimeMillis())
                }
                
                val jsonString = smsData.toString()
                Log.d(TAG, "JSON data: $jsonString")
                
                // Check if eventSink is available
                val eventSink = MainActivity.eventSink
                if (eventSink == null) {
                    Log.e(TAG, "ERROR: eventSink is NULL! Cannot send SMS to Flutter")
                } else {
                    Log.d(TAG, "eventSink is available, sending data to Flutter...")
                    try {
                        eventSink.success(jsonString)
                        Log.d(TAG, "Successfully sent SMS data to Flutter via EventChannel")
                    } catch (e: Exception) {
                        Log.e(TAG, "ERROR sending to eventSink: ${e.message}", e)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "ERROR processing SMS PDU: ${e.message}", e)
            }
        }
        
        Log.d(TAG, "========== SMS RECEIVER FINISHED ==========")
    }
}

