package com.aniket.ewallet

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import java.util.Locale
import java.util.concurrent.Executors

class SmsOverlayActivity : Activity() {
    companion object {
        const val EXTRA_BODY = "sms_body"
        const val EXTRA_ADDRESS = "sms_address"
        const val EXTRA_DATE = "sms_date"
        const val EXTRA_AMOUNT = "sms_amount"
        const val EXTRA_TYPE = "sms_type"
        const val EXTRA_OPEN_SYNC = "sms_open_sync"
        const val EXTRA_ACCOUNT = "sms_account"
        const val EXTRA_CATEGORY = "sms_category"
        const val EXTRA_PLANNER_SECTION = "sms_planner_section"
    }

    private val io = Executors.newSingleThreadExecutor()

    private var accounts: List<OverlayAccount> = emptyList()
    private var categories: List<String> = emptyList()

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

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        try {
            val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
            nm.cancelAll()
        } catch (_: Exception) {
        }

        setContentView(R.layout.activity_sms_overlay)

        val body = intent.getStringExtra(EXTRA_BODY).orEmpty()
        val address = intent.getStringExtra(EXTRA_ADDRESS).orEmpty()
        val date = intent.getLongExtra(EXTRA_DATE, System.currentTimeMillis())
        val amount = intent.getDoubleExtra(EXTRA_AMOUNT, 0.0)
        val type = intent.getStringExtra(EXTRA_TYPE) ?: "debit"
        val isCredit = type.equals("credit", ignoreCase = true)
        val plannerSection = if (isCredit) "Income" else "Essentials"

        val amountText = findViewById<TextView>(R.id.amountText)
        val fromText = findViewById<TextView>(R.id.fromText)
        val bodyPreview = findViewById<TextView>(R.id.bodyPreview)
        val typeChip = findViewById<TextView>(R.id.typeChip)
        val statusText = findViewById<TextView>(R.id.statusText)
        val accountSpinner = findViewById<Spinner>(R.id.accountSpinner)
        val categorySpinner = findViewById<Spinner>(R.id.categorySpinner)
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

        dismissButton.setOnClickListener { finish() }
        syncButton.setOnClickListener {
            val account = selectedAccount(accountSpinner)
            val category = selectedCategory(categorySpinner)
            if (account.isNullOrBlank()) {
                Toast.makeText(this, "Select a bank account", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            if (category.isNullOrBlank()) {
                Toast.makeText(this, "Select a category", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

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
                putExtra(EXTRA_ACCOUNT, account)
                putExtra(EXTRA_CATEGORY, category)
                putExtra(EXTRA_PLANNER_SECTION, plannerSection)
            }
            startActivity(launch)
            finish()
        }

        syncButton.isEnabled = false
        loadFirebaseOptions(
            transactionType = type,
            smsBody = body,
            address = address,
            accountSpinner = accountSpinner,
            categorySpinner = categorySpinner,
            statusText = statusText,
            syncButton = syncButton,
        )
    }

    private fun loadFirebaseOptions(
        transactionType: String,
        smsBody: String,
        address: String,
        accountSpinner: Spinner,
        categorySpinner: Spinner,
        statusText: TextView,
        syncButton: Button,
    ) {
        io.execute {
            val data = OverlayFirebaseRepository.fetch(this@SmsOverlayActivity, transactionType)
            runOnUiThread {
                if (isFinishing) return@runOnUiThread
                accounts = data.accounts
                categories = data.categories

                val accountLabels = if (accounts.isEmpty()) {
                    listOf("No accounts — open app & add one")
                } else {
                    accounts.map { account ->
                        val digits = account.lastDigits
                        if (!digits.isNullOrBlank()) "${account.name} (···$digits)"
                        else account.name
                    }
                }
                accountSpinner.adapter = ArrayAdapter(
                    this,
                    android.R.layout.simple_spinner_dropdown_item,
                    accountLabels,
                )

                categorySpinner.adapter = ArrayAdapter(
                    this,
                    android.R.layout.simple_spinner_dropdown_item,
                    if (categories.isEmpty()) listOf("Other") else categories,
                )

                val guessed = OverlayFirebaseRepository.guessAccount(accounts, smsBody, address)
                if (guessed != null) {
                    val idx = accounts.indexOfFirst { it.id == guessed.id }
                    if (idx >= 0) accountSpinner.setSelection(idx)
                }

                statusText.text = when {
                    !data.loggedIn && accounts.isEmpty() ->
                        "Sign in & open app once so overlay can load Firebase data"
                    accounts.isEmpty() -> "No bank accounts found"
                    else ->
                        "Loaded ${accounts.size} account(s) · ${categories.size} categor" +
                            "${if (categories.size == 1) "y" else "ies"} (${data.source})"
                }
                statusText.setTextColor(
                    if (accounts.isEmpty()) Color.parseColor("#C2410C")
                    else Color.parseColor("#64748B"),
                )
                syncButton.isEnabled = accounts.isNotEmpty()
            }
        }
    }

    private fun selectedAccount(spinner: Spinner): String? {
        if (accounts.isEmpty()) return null
        val index = spinner.selectedItemPosition
        if (index < 0 || index >= accounts.size) return null
        return accounts[index].name
    }

    private fun selectedCategory(spinner: Spinner): String? {
        val item = spinner.selectedItem as? String ?: return null
        if (item.isBlank() || item.startsWith("No ")) return null
        return item
    }

    override fun onDestroy() {
        io.shutdownNow()
        super.onDestroy()
    }
}
