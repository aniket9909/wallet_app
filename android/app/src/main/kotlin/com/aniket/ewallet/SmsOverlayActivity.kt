package com.aniket.ewallet

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import java.util.Locale

class SmsOverlayActivity : Activity() {
    companion object {
        const val EXTRA_BODY = "sms_body"
        const val EXTRA_ADDRESS = "sms_address"
        const val EXTRA_DATE = "sms_date"
        const val EXTRA_AMOUNT = "sms_amount"
        const val EXTRA_TYPE = "sms_type"
        const val EXTRA_OPEN_SYNC = "sms_open_sync"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }

        setContentView(R.layout.activity_sms_overlay)

        val body = intent.getStringExtra(EXTRA_BODY).orEmpty()
        val address = intent.getStringExtra(EXTRA_ADDRESS).orEmpty()
        val date = intent.getLongExtra(EXTRA_DATE, System.currentTimeMillis())
        val amount = intent.getDoubleExtra(EXTRA_AMOUNT, 0.0)
        val type = intent.getStringExtra(EXTRA_TYPE) ?: "debit"
        val isCredit = type.equals("credit", ignoreCase = true)

        val amountText = findViewById<TextView>(R.id.amountText)
        val fromText = findViewById<TextView>(R.id.fromText)
        val bodyPreview = findViewById<TextView>(R.id.bodyPreview)
        val typeChip = findViewById<TextView>(R.id.typeChip)
        val dismissButton = findViewById<Button>(R.id.dismissButton)
        val syncButton = findViewById<Button>(R.id.syncButton)

        amountText.text = String.format(Locale.US, "₹%.2f", amount)
        fromText.text = if (address.isNotEmpty()) "From: $address" else "From: —"
        bodyPreview.text = body
        typeChip.text = if (isCredit) "Credit" else "Debit"
        typeChip.setBackgroundResource(
            if (isCredit) R.drawable.sms_overlay_chip_credit
            else R.drawable.sms_overlay_chip_debit,
        )
        amountText.setTextColor(
            if (isCredit) Color.parseColor("#2E7D32") else Color.parseColor("#C62828"),
        )

        dismissButton.setOnClickListener { finish() }
        syncButton.setOnClickListener {
            val launch = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_OPEN_SYNC, true)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_ADDRESS, address)
                putExtra(EXTRA_DATE, date)
                putExtra(EXTRA_AMOUNT, amount)
                putExtra(EXTRA_TYPE, type)
            }
            startActivity(launch)
            finish()
        }
    }
}
