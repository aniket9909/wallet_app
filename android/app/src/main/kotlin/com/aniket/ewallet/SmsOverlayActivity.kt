package com.aniket.ewallet

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.view.View
import android.view.WindowManager
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
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
        const val EXTRA_MANUAL = "sms_manual"
    }

    private val io = Executors.newSingleThreadExecutor()

    private var accounts: List<OverlayAccount> = emptyList()
    private var plannerSections: List<String> = emptyList()
    private var subtypesBySection: Map<String, List<String>> = emptyMap()

    private lateinit var smsBody: String
    private lateinit var smsAddress: String
    private var smsDate: Long = 0
    private var smsAmount: Double = 0.0
    private lateinit var smsType: String
    private var isManual: Boolean = false

    private lateinit var formPanel: ScrollView
    private lateinit var successPanel: LinearLayout
    private lateinit var failurePanel: LinearLayout
    private lateinit var accountSpinner: Spinner
    private lateinit var sectionSpinner: Spinner
    private lateinit var subtypeSpinner: Spinner
    private lateinit var statusText: TextView
    private lateinit var amountInput: EditText
    private lateinit var noteInput: EditText
    private lateinit var typeChip: TextView
    private lateinit var syncButton: Button
    private lateinit var successDetailText: TextView
    private lateinit var failureDetailText: TextView

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
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

        isManual = intent.getBooleanExtra(EXTRA_MANUAL, false)
        if (!isManual) {
            try {
                val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                nm.cancelAll()
            } catch (_: Exception) {
            }
        }

        setContentView(R.layout.activity_sms_overlay)

        smsBody = intent.getStringExtra(EXTRA_BODY).orEmpty()
        smsAddress = intent.getStringExtra(EXTRA_ADDRESS).orEmpty()
        smsDate = intent.getLongExtra(EXTRA_DATE, System.currentTimeMillis())
        smsAmount = intent.getDoubleExtra(EXTRA_AMOUNT, 0.0)
        smsType = intent.getStringExtra(EXTRA_TYPE) ?: "debit"

        formPanel = findViewById(R.id.formPanel)
        successPanel = findViewById(R.id.successPanel)
        failurePanel = findViewById(R.id.failurePanel)
        accountSpinner = findViewById(R.id.accountSpinner)
        sectionSpinner = findViewById(R.id.sectionSpinner)
        subtypeSpinner = findViewById(R.id.subtypeSpinner)
        statusText = findViewById(R.id.statusText)
        amountInput = findViewById(R.id.amountInput)
        noteInput = findViewById(R.id.noteInput)
        typeChip = findViewById(R.id.typeChip)
        syncButton = findViewById(R.id.syncButton)
        successDetailText = findViewById(R.id.successDetailText)
        failureDetailText = findViewById(R.id.failureDetailText)

        if (smsAmount <= 0.0) {
            smsAmount = SmsTxnDetector.extractAmount(smsBody) ?: 0.0
        }
        bindAmountField(smsAmount)
        amountInput.setOnFocusChangeListener { _, hasFocus ->
            if (hasFocus && amountInput.text.isNotEmpty()) {
                amountInput.selectAll()
            }
        }
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN)

        val titleText = findViewById<TextView>(R.id.titleText)
        val amountHint = findViewById<TextView>(R.id.amountHintText)
        val fromText = findViewById<TextView>(R.id.fromText)
        val bodyPreview = findViewById<TextView>(R.id.bodyPreview)

        if (isManual) {
            titleText.text = "Quick add"
            amountHint.text = "Enter amount · tap Credit/Debit to switch"
            fromText.text = "No SMS needed — fill amount, account & category"
            bodyPreview.visibility = View.GONE
            noteInput.visibility = View.VISIBLE
            bindAmountField(0.0)
        } else {
            fromText.text =
                if (smsAddress.isNotEmpty()) "From: $smsAddress" else "From: —"
            bodyPreview.text = smsBody
            bodyPreview.visibility = if (smsBody.isBlank()) View.GONE else View.VISIBLE
            noteInput.visibility = View.GONE
        }

        bindTypeChip()
        typeChip.setOnClickListener {
            smsType = if (smsType.equals("credit", true)) "debit" else "credit"
            bindTypeChip()
            applyDefaultSectionForType()
        }

        findViewById<Button>(R.id.dismissButton).setOnClickListener { finish() }
        findViewById<Button>(R.id.successDismissButton).setOnClickListener { finish() }
        findViewById<Button>(R.id.failureDismissButton).setOnClickListener { finish() }
        findViewById<Button>(R.id.retryButton).setOnClickListener { showForm() }

        sectionSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(
                parent: AdapterView<*>?,
                view: View?,
                position: Int,
                id: Long,
            ) {
                refreshSubtypeSpinner()
            }

            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }

        syncButton.setOnClickListener { performSync() }
        syncButton.isEnabled = false
        loadFirebaseOptions()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        recreate()
    }

    private fun loadFirebaseOptions() {
        io.execute {
            val data = OverlayFirebaseRepository.fetch(this@SmsOverlayActivity, smsType)
            runOnUiThread {
                if (isFinishing) return@runOnUiThread
                accounts = data.accounts
                plannerSections = data.plannerSections
                subtypesBySection = data.subtypesBySection

                accountSpinner.adapter = ArrayAdapter(
                    this,
                    android.R.layout.simple_spinner_dropdown_item,
                    if (accounts.isEmpty()) {
                        listOf("No accounts — open app & add one")
                    } else {
                        accounts.map { a ->
                            val d = a.lastDigits
                            if (!d.isNullOrBlank()) "${a.name} (···$d)" else a.name
                        }
                    },
                )

                sectionSpinner.adapter = ArrayAdapter(
                    this,
                    android.R.layout.simple_spinner_dropdown_item,
                    plannerSections.ifEmpty { listOf("Essentials") },
                )

                val defaultSection = OverlayPlannerData.defaultSectionForType(
                    smsType.equals("credit", true),
                )
                val sectionIdx = plannerSections.indexOf(defaultSection).coerceAtLeast(0)
                sectionSpinner.setSelection(sectionIdx)
                refreshSubtypeSpinner()

                OverlayFirebaseRepository.guessAccount(accounts, smsBody, smsAddress)?.let { g ->
                    val idx = accounts.indexOfFirst { it.id == g.id }
                    if (idx >= 0) accountSpinner.setSelection(idx)
                }

                statusText.text = when {
                    accounts.isEmpty() && !data.loggedIn ->
                        "Sign in & open app once to load accounts"
                    accounts.isEmpty() ->
                        "No accounts yet — add one in the app"
                    data.source == "sqlite" || data.source == "cache" ->
                        "${accounts.size} account(s) · offline ready"
                    else ->
                        "${accounts.size} account(s) ready · pick section & subcategory"
                }
                statusText.setTextColor(
                    if (accounts.isEmpty()) Color.parseColor("#C2410C")
                    else Color.parseColor("#64748B"),
                )
                syncButton.isEnabled = accounts.isNotEmpty()
            }
        }
    }

    private fun refreshSubtypeSpinner() {
        val section = sectionSpinner.selectedItem as? String ?: return
        val subtypes = OverlayPlannerData.subtypesForSection(section, subtypesBySection)
        subtypeSpinner.adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_dropdown_item,
            subtypes,
        )
    }

    private fun performSync() {
        val account = selectedAccount() ?: run {
            Toast.makeText(this, "Select a bank account", Toast.LENGTH_SHORT).show()
            return
        }
        val section = sectionSpinner.selectedItem as? String
        if (section.isNullOrBlank()) {
            Toast.makeText(this, "Select a planner section", Toast.LENGTH_SHORT).show()
            return
        }
        val subtype = subtypeSpinner.selectedItem as? String
        if (subtype.isNullOrBlank()) {
            Toast.makeText(this, "Select a subcategory", Toast.LENGTH_SHORT).show()
            return
        }
        val amount = parsedAmount()
        if (amount == null || amount <= 0.0) {
            Toast.makeText(this, "Enter a valid amount", Toast.LENGTH_SHORT).show()
            amountInput.requestFocus()
            return
        }
        smsAmount = amount

        val note = noteInput.text?.toString()?.trim().orEmpty()
        val body = when {
            isManual && note.isNotEmpty() -> note
            isManual -> "Quick add"
            else -> smsBody
        }
        val description = when {
            isManual && note.isNotEmpty() -> note
            isManual -> "Quick add"
            else -> null
        }

        syncButton.isEnabled = false
        statusText.text = "Syncing to wallet…"
        statusText.setTextColor(Color.parseColor("#4F46E5"))

        val request = OverlaySyncRepository.SyncRequest(
            body = body,
            address = if (isManual) "Quick add" else smsAddress,
            dateMillis = smsDate,
            amount = amount,
            type = smsType,
            accountName = account,
            plannerSection = section,
            subtype = subtype,
            description = description,
        )

        io.execute {
            val result = OverlaySyncRepository.sync(this@SmsOverlayActivity, request)
            runOnUiThread {
                if (isFinishing) return@runOnUiThread
                if (result.success) {
                    showSuccess(result.message, account, section, subtype)
                } else {
                    showFailure(result.message)
                }
            }
        }
    }

    private fun showForm() {
        formPanel.visibility = View.VISIBLE
        successPanel.visibility = View.GONE
        failurePanel.visibility = View.GONE
        syncButton.isEnabled = accounts.isNotEmpty()
        statusText.text = "Ready to sync"
        statusText.setTextColor(Color.parseColor("#64748B"))
    }

    private fun showSuccess(
        message: String,
        account: String,
        section: String,
        subtype: String,
    ) {
        formPanel.visibility = View.GONE
        failurePanel.visibility = View.GONE
        successPanel.visibility = View.VISIBLE
        val offlineNote = if (message.contains("offline", ignoreCase = true)) {
            "\n\nWill sync to Firebase when online."
        } else {
            ""
        }
        successDetailText.text =
            "$message$offlineNote\n\nAmount: ₹${"%.2f".format(Locale.US, smsAmount)}\nAccount: $account\nSection: $section\nSubcategory: $subtype"
    }

    private fun showFailure(error: String) {
        formPanel.visibility = View.GONE
        successPanel.visibility = View.GONE
        failurePanel.visibility = View.VISIBLE
        failureDetailText.text = error
    }

    private fun bindTypeChip() {
        val isCredit = smsType.equals("credit", true)
        typeChip.text = if (isCredit) "Credit" else "Debit"
        typeChip.setBackgroundResource(
            if (isCredit) R.drawable.sms_overlay_chip_credit
            else R.drawable.sms_overlay_chip_debit,
        )
    }

    private fun applyDefaultSectionForType() {
        if (plannerSections.isEmpty()) return
        val current = sectionSpinner.selectedItem as? String
        val isDefaultSection = current == null ||
            current == OverlayPlannerData.defaultSectionForType(true) ||
            current == OverlayPlannerData.defaultSectionForType(false)
        if (!isDefaultSection) return
        val target = OverlayPlannerData.defaultSectionForType(smsType.equals("credit", true))
        val idx = plannerSections.indexOf(target)
        if (idx >= 0) sectionSpinner.setSelection(idx)
    }

    private fun bindAmountField(amount: Double) {
        amountInput.setText(
            if (amount > 0.0) String.format(Locale.US, "%.2f", amount) else "",
        )
        if (amount <= 0.0) {
            amountInput.hint = "Enter amount"
        }
    }

    private fun parsedAmount(): Double? {
        val typed = amountInput.text?.toString().orEmpty()
        val fromField = parseAmountText(typed)
        if (fromField != null && fromField > 0.0) return fromField
        return SmsTxnDetector.extractAmount(smsBody)?.takeIf { it > 0.0 }
    }

    private fun parseAmountText(raw: String): Double? {
        val cleaned = raw
            .replace("₹", "")
            .replace(",", "")
            .replace(" ", "")
            .trim()
        if (cleaned.isEmpty()) return null
        return cleaned.toDoubleOrNull()?.takeIf { it > 0.0 && it < 100_000_000 }
    }

    private fun selectedAccount(): String? {
        if (accounts.isEmpty()) return null
        val index = accountSpinner.selectedItemPosition
        if (index < 0 || index >= accounts.size) return null
        return accounts[index].name
    }

    override fun onDestroy() {
        io.shutdownNow()
        super.onDestroy()
    }
}
