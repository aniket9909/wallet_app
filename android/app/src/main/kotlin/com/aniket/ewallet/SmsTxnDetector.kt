package com.aniket.ewallet

import java.util.Locale
import java.util.regex.Pattern

data class SmsTxnDetection(
    val isCredit: Boolean,
    val amount: Double,
    val transactionType: String,
)

/**
 * Kotlin port of Dart [SmsDetectionUtil.detectCreditDebit].
 * Handles UPI "Sent Rs.19.40 …" style bank SMS as well as classic debit/credit.
 */
object SmsTxnDetector {
    private val amountPattern: Pattern = Pattern.compile(
        "(?:(?:inr|rs|rupees?)\\.?\\s*|₹\\s*)([0-9]+(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?)",
        Pattern.CASE_INSENSITIVE,
    )

    private val amountFallbackPattern: Pattern = Pattern.compile(
        "(?:amount|amt|txn(?:\\s+of)?|of)\\s*(?:is\\s*)?(?:inr|rs\\.?|₹)?\\s*([0-9]+(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?)",
        Pattern.CASE_INSENSITIVE,
    )

    private val creditPatterns = listOf(
        Regex("""\bcredited\b""", RegexOption.IGNORE_CASE),
        Regex("""\bcr\.?\b""", RegexOption.IGNORE_CASE),
        Regex("""\breceived\b""", RegexOption.IGNORE_CASE),
        Regex("""\bcredit(?:ed)?\b""", RegexOption.IGNORE_CASE),
        Regex("""\bdeposited\b""", RegexOption.IGNORE_CASE),
        Regex("""\badded\s+to\b""", RegexOption.IGNORE_CASE),
        Regex("""\bmoney\s+received\b""", RegexOption.IGNORE_CASE),
    )

    private val debitPatterns = listOf(
        Regex("""\bdebited\b""", RegexOption.IGNORE_CASE),
        Regex("""\bdr\.?\b""", RegexOption.IGNORE_CASE),
        Regex("""\bspent\b""", RegexOption.IGNORE_CASE),
        Regex("""\bwithdrawn\b""", RegexOption.IGNORE_CASE),
        Regex("""\bdebit(?:ed)?\b""", RegexOption.IGNORE_CASE),
        Regex("""\bpaid\b""", RegexOption.IGNORE_CASE),
        Regex("""\bsent\b""", RegexOption.IGNORE_CASE),
        Regex("""\btransfer(?:red)?\b""", RegexOption.IGNORE_CASE),
        Regex("""\bpurchase(?:d)?\b""", RegexOption.IGNORE_CASE),
        Regex("""\bpayment\b""", RegexOption.IGNORE_CASE),
        Regex("""\bwithdraw(?:al|n)?\b""", RegexOption.IGNORE_CASE),
        Regex("""\bupi\s+(?:ref|txn|payment)\b""", RegexOption.IGNORE_CASE),
        Regex("""\bcharged\b""", RegexOption.IGNORE_CASE),
    )

    /** TEMP TEST sender — any SMS from this number is treated as a txn. */
    private const val TEST_SENDER_SUFFIX = "7678029909"

    fun isTestSender(address: String?): Boolean {
        if (address.isNullOrBlank()) return false
        val digits = address.filter { it.isDigit() }
        return digits.endsWith(TEST_SENDER_SUFFIX)
    }

    fun detect(body: String, address: String? = null): SmsTxnDetection? {
        if (isTestSender(address)) {
            return SmsTxnDetection(
                isCredit = false,
                amount = extractAmount(body) ?: 1.0,
                transactionType = "debit",
            )
        }

        val lower = body.lowercase(Locale.US)
        val isCredit = creditPatterns.any { it.containsMatchIn(lower) }
        val isDebit = debitPatterns.any { it.containsMatchIn(lower) }

        if (!isCredit && !isDebit) return null

        val amount = extractAmount(body) ?: return null
        val treatAsCredit = isCredit && !isDebit

        return SmsTxnDetection(
            isCredit = treatAsCredit,
            amount = amount,
            transactionType = if (treatAsCredit) "credit" else "debit",
        )
    }

    fun extractAmount(body: String): Double? {
        for (pattern in listOf(amountPattern, amountFallbackPattern)) {
            val matcher = pattern.matcher(body)
            while (matcher.find()) {
                val raw = matcher.group(1)?.replace(",", "") ?: continue
                val amount = raw.toDoubleOrNull() ?: continue
                if (amount > 0 && amount < 100_000_000) return amount
            }
        }
        return null
    }
}
