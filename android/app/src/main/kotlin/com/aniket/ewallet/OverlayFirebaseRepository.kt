package com.aniket.ewallet

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

data class OverlayAccount(
    val id: String,
    val name: String,
    val type: String,
    val lastDigits: String?,
)

data class OverlayFirebaseData(
    val accounts: List<OverlayAccount>,
    val categories: List<String>,
    val loggedIn: Boolean,
    val source: String,
)

/**
 * Loads bank accounts + categories for the SMS overlay.
 *
 * Primary: SharedPreferences cache written by Flutter from Firebase.
 * Refresh: Firebase Realtime Database REST (same paths as Flutter) when a
 * cached uid + idToken are available.
 */
object OverlayFirebaseRepository {
    private const val TAG = "OverlayFirebaseRepo"
    private const val PREFS = "ewallet_overlay_cache"
    private const val KEY_ACCOUNTS = "accounts_json"
    private const val KEY_CATEGORIES = "categories_json"
    private const val KEY_UID = "firebase_uid"
    private const val KEY_TOKEN = "firebase_id_token"
    private const val KEY_DB_URL = "firebase_db_url"

    // Matches google-services.json firebase_url for this project.
    private const val DEFAULT_DB_URL =
        "https://ewallet-2d1f1-default-rtdb.asia-southeast1.firebasedatabase.app"

    private val defaultDebitCategories = listOf(
        "Food & Groceries",
        "Housing/Rent",
        "Transportation",
        "Healthcare",
        "Entertainment",
        "Shopping",
        "SIP",
        "Other essential",
        "Other personal",
    )

    private val defaultCreditCategories = listOf(
        "Salary",
        "Other income",
        "Refund",
        "Transfer in",
    )

    fun saveCache(
        context: Context,
        accountsJson: String,
        categoriesJson: String,
        uid: String?,
        idToken: String?,
        dbUrl: String?,
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_ACCOUNTS, accountsJson)
            .putString(KEY_CATEGORIES, categoriesJson)
            .putString(KEY_UID, uid)
            .putString(KEY_TOKEN, idToken)
            .putString(KEY_DB_URL, dbUrl ?: DEFAULT_DB_URL)
            .apply()
        Log.d(TAG, "Overlay cache saved")
    }

    fun fetch(context: Context, transactionType: String): OverlayFirebaseData {
        val refreshed = tryRefreshFromFirebaseRest(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val accounts = parseAccounts(prefs.getString(KEY_ACCOUNTS, null))
        val cachedCategories = parseCategories(prefs.getString(KEY_CATEGORIES, null))
        val uid = prefs.getString(KEY_UID, null)
        val loggedIn = !uid.isNullOrBlank()

        return OverlayFirebaseData(
            accounts = accounts,
            categories = categoriesForType(transactionType, cachedCategories),
            loggedIn = loggedIn,
            source = if (refreshed) "firebase" else "cache",
        )
    }

    private fun tryRefreshFromFirebaseRest(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val uid = prefs.getString(KEY_UID, null) ?: return false
        val token = prefs.getString(KEY_TOKEN, null) ?: return false
        val dbUrl = (prefs.getString(KEY_DB_URL, DEFAULT_DB_URL) ?: DEFAULT_DB_URL)
            .trimEnd('/')

        return try {
            val accountsJson = httpGet("$dbUrl/users/$uid/accounts.json?auth=$token")
            val expenseTypesJson =
                httpGet("$dbUrl/users/$uid/settings/expense_types.json?auth=$token")
            val moneyPlanJson = httpGet("$dbUrl/users/$uid/money_plan.json?auth=$token")

            val categories = linkedSetOf<String>()
            parseExpenseTypesJson(expenseTypesJson, categories)
            parseMoneyPlanJson(moneyPlanJson, categories)

            prefs.edit()
                .putString(KEY_ACCOUNTS, accountsJson ?: "null")
                .putString(KEY_CATEGORIES, JSONArray(categories.toList()).toString())
                .apply()
            Log.d(TAG, "Refreshed overlay data from Firebase REST")
            true
        } catch (e: Exception) {
            Log.w(TAG, "Firebase REST refresh failed: ${e.message}")
            false
        }
    }

    private fun httpGet(url: String): String? {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = TimeUnit.SECONDS.toMillis(6).toInt()
            readTimeout = TimeUnit.SECONDS.toMillis(6).toInt()
            requestMethod = "GET"
        }
        return try {
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val body = BufferedReader(InputStreamReader(stream)).use { it.readText() }
            if (code !in 200..299) {
                Log.w(TAG, "HTTP $code for $url → $body")
                return null
            }
            body
        } finally {
            conn.disconnect()
        }
    }

    private fun parseAccounts(raw: String?): List<OverlayAccount> {
        if (raw.isNullOrBlank() || raw == "null") return emptyList()
        val out = mutableListOf<OverlayAccount>()
        try {
            // Flutter cache is a JSON array; RTDB REST is a JSON object map.
            val trimmed = raw.trim()
            if (trimmed.startsWith("[")) {
                val arr = JSONArray(trimmed)
                for (i in 0 until arr.length()) {
                    val obj = arr.optJSONObject(i) ?: continue
                    val name = obj.optString("name").trim()
                    if (name.isEmpty()) continue
                    out.add(
                        OverlayAccount(
                            id = obj.optString("id", name),
                            name = name,
                            type = obj.optString("type", "Bank"),
                            lastDigits = obj.optString("last_digits").ifBlank { null },
                        ),
                    )
                }
            } else {
                val obj = JSONObject(trimmed)
                val keys = obj.keys()
                while (keys.hasNext()) {
                    val id = keys.next()
                    val child = obj.optJSONObject(id) ?: continue
                    val name = child.optString("name").trim()
                    if (name.isEmpty()) continue
                    out.add(
                        OverlayAccount(
                            id = id,
                            name = name,
                            type = child.optString("type", "Bank"),
                            lastDigits = child.optString("last_digits").ifBlank { null },
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "parseAccounts failed: ${e.message}")
        }
        return out.sortedBy { it.name.lowercase() }
    }

    private fun parseCategories(raw: String?): List<String> {
        if (raw.isNullOrBlank() || raw == "null") return emptyList()
        val out = mutableListOf<String>()
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val value = arr.optString(i).trim()
                if (value.isNotEmpty()) out.add(value)
            }
        } catch (e: Exception) {
            Log.e(TAG, "parseCategories failed: ${e.message}")
        }
        return out
    }

    private fun parseExpenseTypesJson(raw: String?, out: MutableSet<String>) {
        if (raw.isNullOrBlank() || raw == "null") return
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val value = arr.optString(i).trim()
                if (value.isNotEmpty()) out.add(value)
            }
        } catch (_: Exception) {
        }
    }

    private fun parseMoneyPlanJson(raw: String?, out: MutableSet<String>) {
        if (raw.isNullOrBlank() || raw == "null") return
        try {
            val root = JSONObject(raw)
            for (bucket in listOf("expenses", "investments", "goals", "debts")) {
                val node = root.optJSONObject(bucket) ?: continue
                val keys = node.keys()
                while (keys.hasNext()) {
                    val child = node.optJSONObject(keys.next()) ?: continue
                    val name = child.optString("name").trim()
                    if (name.isNotEmpty()) out.add(name)
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun categoriesForType(type: String, fromFirebase: List<String>): List<String> {
        val isCredit = type.equals("credit", ignoreCase = true)
        val defaults = if (isCredit) defaultCreditCategories else defaultDebitCategories
        val merged = linkedSetOf<String>()
        merged.addAll(fromFirebase)
        merged.addAll(defaults)
        return merged.toList()
    }

    fun guessAccount(
        accounts: List<OverlayAccount>,
        smsBody: String,
        address: String,
    ): OverlayAccount? {
        if (accounts.isEmpty()) return null
        for (account in accounts) {
            val digits = account.lastDigits
            if (!digits.isNullOrBlank() && smsBody.contains(digits)) return account
        }
        val addr = address.uppercase()
        for (account in accounts) {
            val name = account.name.uppercase()
            if (addr.contains(name)) return account
            if (name.split(' ').any { it.length > 2 && addr.contains(it) }) return account
        }
        val banks = accounts.filter { it.type.contains("bank", ignoreCase = true) }
        return banks.firstOrNull() ?: accounts.first()
    }
}
