package com.aniket.ewallet

import android.app.Activity
import android.graphics.Color
import android.os.Build
import android.view.View
import android.view.WindowManager
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
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

    private lateinit var formPanel: ScrollView
    private lateinit var successPanel: LinearLayout
    private lateinit var failurePanel: LinearLayout
    private lateinit var accountSpinner: Spinner
    private lateinit var sectionSpinner: Spinner
    private lateinit var subtypeSpinner: Spinner
    private lateinit var statusText: TextView
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

        try {
            val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
            nm.cancelAll()
        } catch (_: Exception) {
        }

        setContentView(R.layout.activity_sms_overlay)

        smsBody = intent.getStringExtra(EXTRA_BODY).orEmpty()
        smsAddress = intent.getStringExtra(EXTRA_ADDRESS).orEmpty()
        smsDate = intent.getLongExtra(EXTRA_DATE, System.currentTimeMillis())
        smsAmount = intent.getDoubleExtra(EXTRA_AMOUNT, 0.0)
        smsType = intent.getStringExtra(EXTRA_TYPE) ?: "debit"
        val isCredit = smsType.equals("credit", ignoreCase = true)

        formPanel = findViewById(R.id.formPanel)
        successPanel = findViewById(R.id.successPanel)
        failurePanel = findViewById(R.id.failurePanel)
        accountSpinner = findViewById(R.id.accountSpinner)
        sectionSpinner = findViewById(R.id.sectionSpinner)
        subtypeSpinner = findViewById(R.id.subtypeSpinner)
        statusText = findViewById(R.id.statusText)
        syncButton = findViewById(R.id.syncButton)
        successDetailText = findViewById(R.id.successDetailText)
        failureDetailText = findViewById(R.id.failureDetailText)

        findViewById<TextView>(R.id.amountText).text =
            String.format(Locale.US, "₹%.2f", smsAmount)
        findViewById<TextView>(R.id.fromText).text =
            if (smsAddress.isNotEmpty()) "From: $smsAddress" else "From: —"
        findViewById<TextView>(R.id.bodyPreview).text = smsBody

        val typeChip = findViewById<TextView>(R.id.typeChip)
        typeChip.text = if (isCredit) "Credit" else "Debit"
        typeChip.setBackgroundResource(
            if (isCredit) R.drawable.sms_overlay_chip_credit
            else R.drawable.sms_overlay_chip_debit,
        )

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
                    !data.loggedIn && accounts.isEmpty() ->
                        "Sign in & open app once to load Firebase data"
                    accounts.isEmpty() -> "No bank accounts found"
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

        syncButton.isEnabled = false
        statusText.text = "Syncing to wallet…"
        statusText.setTextColor(Color.parseColor("#4F46E5"))

        val request = OverlaySyncRepository.SyncRequest(
            body = smsBody,
            address = smsAddress,
            dateMillis = smsDate,
            amount = smsAmount,
            type = smsType,
            accountName = account,
            plannerSection = section,
            subtype = subtype,
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
        successDetailText.text =
            "$message\n\nAccount: $account\nSection: $section\nSubcategory: $subtype"
    }

    private fun showFailure(error: String) {
        formPanel.visibility = View.GONE
        successPanel.visibility = View.GONE
        failurePanel.visibility = View.VISIBLE
        failureDetailText.text = error
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
