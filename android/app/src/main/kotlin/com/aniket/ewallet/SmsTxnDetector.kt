package com.aniket.ewallet

import java.util.Locale
import java.util.regex.Pattern

data class SmsTxnDetection(
    val isCredit: Boolean,
    val amount: Double,
    val transactionType: String,
)

/**
 * Lightweight Kotlin port of Dart [SmsDetectionUtil.detectCreditDebit].
 */
object SmsTxnDetector {
    private val amountPattern: Pattern = Pattern.compile(
        "(inr|rs\\.?|₹|rupees?)\\s*([0-9,]+\\.?[0-9]*)",
        Pattern.CASE_INSENSITIVE,
    )

    fun detect(body: String): SmsTxnDetection? {
        val lower = body.lowercase(Locale.US)

        val isCredit = lower.contains("credited") ||
            lower.contains("cr.") ||
            lower.contains("cr ") ||
            lower.contains("received") ||
            lower.contains("credit") ||
            lower.contains("deposited")

        val isDebit = lower.contains("debited") ||
            lower.contains("dr.") ||
            lower.contains("dr ") ||
            lower.contains("spent") ||
            lower.contains("withdrawn") ||
            lower.contains("debit") ||
            lower.contains("paid")

        if (!isCredit && !isDebit) return null

        val matcher = amountPattern.matcher(body)
        if (!matcher.find()) return null

        val raw = matcher.group(2) ?: return null
        val amount = raw.replace(",", "").toDoubleOrNull() ?: return null

        return SmsTxnDetection(
            isCredit = isCredit,
            amount = amount,
            transactionType = if (isCredit) "credit" else "debit",
        )
    }
}
