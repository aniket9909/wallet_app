package com.aniket.ewallet

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

data class OverlayAccount(
    val id: String,
    val name: String,
    val type: String,
    val lastDigits: String?,
)

data class OverlayFirebaseData(
    val accounts: List<OverlayAccount>,
    val plannerSections: List<String>,
    val subtypesBySection: Map<String, List<String>>,
    val loggedIn: Boolean,
    val source: String,
)

/**
 * Loads bank accounts + planner categories for the SMS overlay.
 * Local SQLite + SharedPreferences first; Firebase REST refresh when online.
 */
object OverlayFirebaseRepository {
    private const val TAG = "OverlayFirebaseRepo"
    const val PREFS_NAME = "ewallet_overlay_cache"
    const val KEY_ACCOUNTS = "accounts_json"
    const val KEY_CATEGORIES = "categories_json"
    const val KEY_PLANNER_SUBTYPES = "planner_subtypes_json"
    const val KEY_UID = "firebase_uid"
    const val KEY_TOKEN = "firebase_id_token"
    const val KEY_DB_URL = "firebase_db_url"
    const val DEFAULT_DB_URL =
        "https://ewallet-2d1f1-default-rtdb.asia-southeast1.firebasedatabase.app"

    private const val PREFS = PREFS_NAME
    private const val KEY_SUBTYPES = KEY_PLANNER_SUBTYPES

    fun saveCache(
        context: Context,
        accountsJson: String,
        categoriesJson: String,
        plannerSubtypesJson: String?,
        uid: String?,
        idToken: String?,
        dbUrl: String?,
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_ACCOUNTS, accountsJson)
            .putString(KEY_CATEGORIES, categoriesJson)
            .putString(KEY_SUBTYPES, plannerSubtypesJson ?: "{}")
            .putString(KEY_UID, uid)
            .putString(KEY_TOKEN, idToken)
            .putString(KEY_DB_URL, dbUrl ?: DEFAULT_DB_URL)
            .apply()

        LocalAppDatabase.ensureInitialized(context)
        LocalAppDatabase.replaceAccountsFromArray(context, accountsJson)
        try {
            val cats = JSONArray(categoriesJson)
            if (cats.length() > 0) {
                val names = mutableListOf<String>()
                for (i in 0 until cats.length()) names.add(cats.optString(i))
                LocalAppDatabase.replaceCategories(context, names)
            }
        } catch (_: Exception) {
        }
        if (!plannerSubtypesJson.isNullOrBlank()) {
            LocalAppDatabase.replaceSubcategoriesFromJson(context, plannerSubtypesJson)
        }
        Log.d(TAG, "Overlay cache saved to prefs + sqlite")
    }

    fun fetch(context: Context, transactionType: String): OverlayFirebaseData {
        LocalAppDatabase.ensureInitialized(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        var accounts = loadLocalAccounts(context, prefs)
        var subtypesMap = loadLocalSubtypes(context, prefs)

        val uid = prefs.getString(KEY_UID, null)
        val loggedIn = !uid.isNullOrBlank()

        val refreshed = tryRefreshFromFirebaseRest(context)
        if (refreshed) {
            val updatedAccounts = LocalAppDatabase.loadAccounts(context)
            if (updatedAccounts.isNotEmpty()) accounts = updatedAccounts
            val updatedSubtypes = loadLocalSubtypes(context, prefs)
            if (updatedSubtypes.values.any { it.isNotEmpty() }) subtypesMap = updatedSubtypes
        }

        val isCredit = transactionType.equals("credit", ignoreCase = true)
        val sections = if (isCredit) {
            listOf("Income") + OverlayPlannerData.sections.filter { it != "Income" }
        } else {
            OverlayPlannerData.sections.filter { it != "Income" }
        }

        val source = when {
            refreshed -> "firebase"
            accounts.isNotEmpty() && LocalAppDatabase.file(context).exists() -> "sqlite"
            accounts.isNotEmpty() -> "cache"
            else -> "empty"
        }

        Log.d(TAG, "fetch source=$source accounts=${accounts.size} sections=${subtypesMap.size}")

        return OverlayFirebaseData(
            accounts = accounts,
            plannerSections = sections,
            subtypesBySection = subtypesMap,
            loggedIn = loggedIn,
            source = source,
        )
    }

    private fun loadLocalAccounts(
        context: Context,
        prefs: android.content.SharedPreferences,
    ): List<OverlayAccount> {
        val sqlite = LocalAppDatabase.loadAccounts(context)
        val cached = parseAccounts(prefs.getString(KEY_ACCOUNTS, null))
        if (sqlite.isEmpty()) return cached
        if (cached.isEmpty()) return sqlite
        val merged = linkedMapOf<String, OverlayAccount>()
        for (a in cached) merged[a.id.ifBlank { a.name }] = a
        for (a in sqlite) merged[a.id.ifBlank { a.name }] = a
        return merged.values.sortedBy { it.name.lowercase() }
    }

    private fun loadLocalSubtypes(
        context: Context,
        prefs: android.content.SharedPreferences,
    ): Map<String, List<String>> {
        val sqlite = LocalAppDatabase.loadSubcategories(context)
        val cached = OverlayPlannerData.parseSubtypesFromJson(
            prefs.getString(KEY_SUBTYPES, null),
        )
        if (sqlite.isEmpty()) return cached
        if (cached.isEmpty()) return sqlite
        val merged = OverlayPlannerData.parseSubtypesFromJson(null).toMutableMap()
        for ((section, names) in cached) {
            val list = merged.getOrPut(section) { mutableListOf() }.toMutableList()
            for (name in names) if (!list.contains(name)) list.add(name)
            merged[section] = list
        }
        for ((section, names) in sqlite) {
            val list = merged.getOrPut(section) { mutableListOf() }.toMutableList()
            for (name in names) if (!list.contains(name)) list.add(0, name)
            merged[section] = list
        }
        return merged
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
            val subtypesJson = buildSubtypesJsonFromMoneyPlan(moneyPlanJson)

            prefs.edit()
                .putString(KEY_ACCOUNTS, accountsJson ?: "null")
                .putString(KEY_CATEGORIES, JSONArray(categories.toList()).toString())
                .putString(KEY_SUBTYPES, subtypesJson)
                .apply()

            if (!accountsJson.isNullOrBlank() && accountsJson != "null") {
                LocalAppDatabase.replaceAccountsFromJson(context, accountsJson)
            }
            if (categories.isNotEmpty()) {
                LocalAppDatabase.replaceCategories(context, categories)
            }
            LocalAppDatabase.replaceSubcategoriesFromJson(context, subtypesJson)
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

    private fun buildSubtypesJsonFromMoneyPlan(raw: String?): String {
        val base = OverlayPlannerData.parseSubtypesFromJson(null).toMutableMap()
        if (raw.isNullOrBlank() || raw == "null") {
            return JSONObject(base.mapValues { JSONArray(it.value) }).toString()
        }
        try {
            val root = JSONObject(raw)
            mergePlanNames(base, "Essentials", root.optJSONObject("expenses"))
            mergePlanNames(base, "Investment", root.optJSONObject("investments"))
            mergePlanNames(base, "Goals", root.optJSONObject("goals"))
            mergePlanNames(base, "Debt & EMI", root.optJSONObject("debts"))
        } catch (_: Exception) {
        }
        val out = JSONObject()
        for ((section, names) in base) {
            out.put(section, JSONArray(names))
        }
        return out.toString()
    }

    private fun mergePlanNames(
        map: MutableMap<String, List<String>>,
        section: String,
        node: JSONObject?,
    ) {
        if (node == null) return
        val list = map.getOrPut(section) { emptyList() }.toMutableList()
        val keys = node.keys()
        while (keys.hasNext()) {
            val name = node.optJSONObject(keys.next())?.optString("name")?.trim() ?: continue
            if (name.isNotEmpty() && !list.contains(name)) list.add(0, name)
        }
        map[section] = list
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
