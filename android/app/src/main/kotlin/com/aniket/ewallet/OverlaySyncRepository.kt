package com.aniket.ewallet

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/**
 * Writes a wallet transaction directly to Firebase RTDB from the SMS overlay
 * (no Flutter app open required).
 */
object OverlaySyncRepository {
    private const val TAG = "OverlaySyncRepo"

    data class SyncRequest(
        val body: String,
        val address: String,
        val dateMillis: Long,
        val amount: Double,
        val type: String,
        val accountName: String,
        val plannerSection: String,
        val subtype: String,
        val description: String? = null,
    )

    data class SyncResult(
        val success: Boolean,
        val message: String,
        val transactionId: String? = null,
    )

    fun sync(context: Context, request: SyncRequest): SyncResult {
        val prefs = context.getSharedPreferences(
            OverlayFirebaseRepository.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        val uid = prefs.getString(OverlayFirebaseRepository.KEY_UID, null)
        val token = prefs.getString(OverlayFirebaseRepository.KEY_TOKEN, null)
        val dbUrl = (prefs.getString(OverlayFirebaseRepository.KEY_DB_URL, null)
            ?: OverlayFirebaseRepository.DEFAULT_DB_URL).trimEnd('/')

        if (uid.isNullOrBlank() || token.isNullOrBlank()) {
            return SyncResult(false, "Not signed in. Open the app once while logged in.")
        }

        return try {
            val accountsRaw = httpGet("$dbUrl/users/$uid/accounts.json?auth=$token")
            val accountId = findAccountId(accountsRaw, request.accountName)
                ?: return SyncResult(false, "Account \"${request.accountName}\" not found in Firebase")

            val description = request.description?.takeIf { it.isNotBlank() }
                ?: buildDescription(request.body, request.type)
            val isoDate = formatIsoDate(request.dateMillis)
            val txnType = if (request.type.equals("credit", true)) "credit" else "debit"
            val note =
                "Planner: ${request.plannerSection} · Subtype: ${request.subtype}\n${request.body}"

            val txnJson = JSONObject().apply {
                put("type", txnType)
                put("amount", request.amount)
                put("description", description)
                put("category", request.subtype)
                put("account", request.accountName)
                put("date", isoDate)
                put("note", note)
            }

            val pushResponse = httpPost(
                "$dbUrl/users/$uid/transactions.json?auth=$token",
                txnJson.toString(),
            ) ?: return SyncResult(false, "Failed to create transaction")

            val txnId = JSONObject(pushResponse).optString("name")
            if (txnId.isBlank()) {
                return SyncResult(false, "Firebase did not return a transaction id")
            }

            updateWallet(dbUrl, uid, token, request)
            updateAccountBalance(dbUrl, uid, token, accountId, accountsRaw, request)

            Log.d(TAG, "Synced transaction $txnId")
            SyncResult(
                success = true,
                message = "₹${"%.2f".format(request.amount)} synced to ${request.plannerSection} · ${request.subtype}",
                transactionId = txnId,
            )
        } catch (e: Exception) {
            Log.e(TAG, "Sync failed: ${e.message}", e)
            SyncResult(false, e.message ?: "Sync failed")
        }
    }

    private fun buildDescription(body: String, type: String): String {
        val fromMatch = Regex(
            """(?i)\bfrom\s+([A-Za-z0-9][A-Za-z0-9 .&/@_-]{1,48})""",
        ).find(body)
        if (fromMatch != null) {
            val name = fromMatch.groupValues[1].trim()
            if (name.length >= 2) return "SMS from $name"
        }
        return if (type.equals("credit", true)) "SMS credit" else "SMS debit"
    }

    private fun formatIsoDate(millis: Long): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
        sdf.timeZone = TimeZone.getDefault()
        return sdf.format(Date(millis))
    }

    private fun findAccountId(accountsRaw: String?, accountName: String): String? {
        if (accountsRaw.isNullOrBlank() || accountsRaw == "null") return null
        return try {
            val trimmed = accountsRaw.trim()
            if (trimmed.startsWith("[")) {
                val arr = JSONArray(trimmed)
                for (i in 0 until arr.length()) {
                    val obj = arr.optJSONObject(i) ?: continue
                    if (obj.optString("name") == accountName) {
                        return obj.optString("id", accountName)
                    }
                }
                null
            } else {
                val obj = JSONObject(trimmed)
                val keys = obj.keys()
                while (keys.hasNext()) {
                    val id = keys.next()
                    val child = obj.optJSONObject(id) ?: continue
                    if (child.optString("name") == accountName) return id
                }
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun updateWallet(dbUrl: String, uid: String, token: String, req: SyncRequest) {
        if (req.subtype.equals("Transfer", true)) return

        val walletRaw = httpGet("$dbUrl/users/$uid/wallet.json?auth=$token")
        val wallet = if (walletRaw.isNullOrBlank() || walletRaw == "null") {
            JSONObject().apply {
                put("total_balance", 0)
                put("total_income", 0)
                put("total_expense", 0)
                put("monthly_income", 0)
                put("monthly_expense", 0)
            }
        } else {
            JSONObject(walletRaw)
        }

        val cal = java.util.Calendar.getInstance()
        val nowMonth = cal.get(java.util.Calendar.MONTH)
        val nowYear = cal.get(java.util.Calendar.YEAR)
        cal.timeInMillis = req.dateMillis
        val isCurrentMonth =
            cal.get(java.util.Calendar.MONTH) == nowMonth &&
                cal.get(java.util.Calendar.YEAR) == nowYear

        val isCredit = req.type.equals("credit", true)
        var balance = wallet.optDouble("total_balance", 0.0)
        var totalIncome = wallet.optDouble("total_income", 0.0)
        var totalExpense = wallet.optDouble("total_expense", 0.0)
        var monthlyIncome = wallet.optDouble("monthly_income", 0.0)
        var monthlyExpense = wallet.optDouble("monthly_expense", 0.0)

        if (isCredit) {
            balance += req.amount
            totalIncome += req.amount
            if (isCurrentMonth) monthlyIncome += req.amount
        } else {
            balance -= req.amount
            totalExpense += req.amount
            if (isCurrentMonth) monthlyExpense += req.amount
        }

        val patch = JSONObject().apply {
            put("total_balance", balance)
            put("total_income", totalIncome)
            put("total_expense", totalExpense)
            put("monthly_income", monthlyIncome)
            put("monthly_expense", monthlyExpense)
        }
        httpPatch("$dbUrl/users/$uid/wallet.json?auth=$token", patch.toString())
    }

    private fun updateAccountBalance(
        dbUrl: String,
        uid: String,
        token: String,
        accountId: String,
        accountsRaw: String?,
        req: SyncRequest,
    ) {
        var currentBalance = 0.0
        if (!accountsRaw.isNullOrBlank() && accountsRaw != "null") {
            try {
                val trimmed = accountsRaw.trim()
                if (trimmed.startsWith("[")) {
                    val arr = JSONArray(trimmed)
                    for (i in 0 until arr.length()) {
                        val obj = arr.optJSONObject(i) ?: continue
                        if (obj.optString("name") == req.accountName) {
                            currentBalance = obj.optDouble("balance", 0.0)
                            break
                        }
                    }
                } else {
                    val obj = JSONObject(trimmed)
                    val child = obj.optJSONObject(accountId)
                    currentBalance = child?.optDouble("balance", 0.0) ?: 0.0
                }
            } catch (_: Exception) {
            }
        }

        val isCredit = req.type.equals("credit", true)
        val newBalance = if (isCredit) currentBalance + req.amount else currentBalance - req.amount
        val patch = JSONObject().apply { put("balance", newBalance) }
        httpPatch("$dbUrl/users/$uid/accounts/$accountId.json?auth=$token", patch.toString())
    }

    private fun httpGet(url: String): String? {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = TimeUnit.SECONDS.toMillis(8).toInt()
            readTimeout = TimeUnit.SECONDS.toMillis(8).toInt()
            requestMethod = "GET"
        }
        return try {
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val body = BufferedReader(InputStreamReader(stream)).use { it.readText() }
            if (code !in 200..299) null else body
        } finally {
            conn.disconnect()
        }
    }

    private fun httpPost(url: String, jsonBody: String): String? {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = TimeUnit.SECONDS.toMillis(10).toInt()
            readTimeout = TimeUnit.SECONDS.toMillis(10).toInt()
            requestMethod = "POST"
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=UTF-8")
        }
        return try {
            OutputStreamWriter(conn.outputStream).use { it.write(jsonBody) }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val body = BufferedReader(InputStreamReader(stream)).use { it.readText() }
            if (code in 200..299) body else null
        } finally {
            conn.disconnect()
        }
    }

    private fun httpPatch(url: String, jsonBody: String) {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = TimeUnit.SECONDS.toMillis(8).toInt()
            readTimeout = TimeUnit.SECONDS.toMillis(8).toInt()
            requestMethod = "PATCH"
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=UTF-8")
        }
        try {
            OutputStreamWriter(conn.outputStream).use { it.write(jsonBody) }
            conn.responseCode
        } finally {
            conn.disconnect()
        }
    }
}
