package com.aniket.ewallet

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Same SQLite file Flutter writes: databases/arthigo_local.db
 * Flutter sqflite and this helper share accounts, categories, and subcategories.
 */
object LocalAppDatabase {
    private const val TAG = "LocalAppDatabase"
    const val DB_NAME = "arthigo_local.db"
    private const val DB_VERSION = 1

    const val TABLE_ACCOUNTS = "accounts"
    const val TABLE_CATEGORIES = "categories"
    const val TABLE_SUBCATEGORIES = "subcategories"
    const val TABLE_ENTITIES = "local_entities"
    const val TABLE_SYNC_QUEUE = "sync_queue"

    const val ENTITY_TRANSACTIONS = "transactions"

    private const val OPEN_FLAGS =
        SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING

    fun file(context: Context): File = context.getDatabasePath(DB_NAME)

    /** Create DB + tables if Flutter has not opened the app yet. */
    fun ensureInitialized(context: Context) {
        val dbFile = file(context)
        dbFile.parentFile?.mkdirs()
        val db = try {
            SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                OPEN_FLAGS or SQLiteDatabase.CREATE_IF_NECESSARY,
            )
        } catch (e: Exception) {
            Log.w(TAG, "ensureInitialized open failed: ${e.message}")
            return
        }
        try {
            db.beginTransaction()
            createSchemaIfNeeded(db)
            seedDefaultsIfEmpty(db)
            db.setTransactionSuccessful()
        } catch (e: Exception) {
            Log.w(TAG, "ensureInitialized failed: ${e.message}")
        } finally {
            try {
                db.endTransaction()
            } catch (_: Exception) {
            }
            db.close()
        }
    }

    private fun createSchemaIfNeeded(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TABLE_ACCOUNTS (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                balance REAL NOT NULL DEFAULT 0,
                type TEXT NOT NULL,
                icon TEXT,
                color TEXT,
                last_digits TEXT,
                deleted INTEGER NOT NULL DEFAULT 0,
                synced INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TABLE_CATEGORIES (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                kind TEXT NOT NULL DEFAULT 'expense',
                deleted INTEGER NOT NULL DEFAULT 0,
                synced INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TABLE_SUBCATEGORIES (
                id TEXT PRIMARY KEY,
                section TEXT NOT NULL,
                name TEXT NOT NULL,
                deleted INTEGER NOT NULL DEFAULT 0,
                synced INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TABLE_ENTITIES (
                key TEXT PRIMARY KEY,
                json TEXT NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TABLE_SYNC_QUEUE (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                entity TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                action TEXT NOT NULL,
                payload TEXT,
                created_at INTEGER NOT NULL
            )
            """.trimIndent(),
        )
    }

    private fun seedDefaultsIfEmpty(db: SQLiteDatabase) {
        val count = db.rawQuery("SELECT COUNT(*) FROM $TABLE_CATEGORIES", null).use {
            if (it.moveToFirst()) it.getInt(0) else 0
        }
        if (count > 0) return
        val now = System.currentTimeMillis()
        val defaults = listOf(
            "Food", "Bills", "Shopping", "Travel",
            "Entertainment", "Health", "Other",
        )
        for (name in defaults) {
            val id = "cat_${name.lowercase()}".replace(Regex("[^A-Za-z0-9_]"), "_")
            db.execSQL(
                """
                INSERT OR IGNORE INTO $TABLE_CATEGORIES
                (id, name, kind, deleted, synced, updated_at)
                VALUES (?, ?, 'expense', 0, 0, ?)
                """.trimIndent(),
                arrayOf(id, name, now),
            )
        }
        val subtypes = OverlayPlannerData.parseSubtypesFromJson(null)
        for ((section, names) in subtypes) {
            for (name in names) {
                val id = "sub_${section}_$name".replace(Regex("[^A-Za-z0-9_]"), "_")
                db.execSQL(
                    """
                    INSERT OR IGNORE INTO $TABLE_SUBCATEGORIES
                    (id, section, name, deleted, synced, updated_at)
                    VALUES (?, ?, ?, 0, 0, ?)
                    """.trimIndent(),
                    arrayOf(id, section, name, now),
                )
            }
        }
    }

    fun openReadable(context: Context): SQLiteDatabase? = open(context)

    fun openWritable(context: Context): SQLiteDatabase? = open(context)

    private fun open(context: Context): SQLiteDatabase? {
        val dbFile = file(context)
        if (!dbFile.exists()) {
            ensureInitialized(context)
        }
        if (!dbFile.exists()) return null
        return try {
            SQLiteDatabase.openDatabase(dbFile.absolutePath, null, OPEN_FLAGS)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to open $DB_NAME: ${e.message}")
            null
        }
    }

    fun loadAccounts(context: Context): List<OverlayAccount> {
        val db = openReadable(context) ?: return emptyList()
        val out = mutableListOf<OverlayAccount>()
        try {
            db.query(
                TABLE_ACCOUNTS,
                arrayOf("id", "name", "type", "last_digits"),
                "deleted = 0",
                null,
                null,
                null,
                "name COLLATE NOCASE",
            ).use { cursor ->
                val idIdx = cursor.getColumnIndex("id")
                val nameIdx = cursor.getColumnIndex("name")
                val typeIdx = cursor.getColumnIndex("type")
                val digitsIdx = cursor.getColumnIndex("last_digits")
                while (cursor.moveToNext()) {
                    out.add(
                        OverlayAccount(
                            id = cursor.getString(idIdx) ?: "",
                            name = cursor.getString(nameIdx) ?: "",
                            type = cursor.getString(typeIdx) ?: "Cash",
                            lastDigits = if (digitsIdx >= 0 && !cursor.isNull(digitsIdx)) {
                                cursor.getString(digitsIdx)
                            } else {
                                null
                            },
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "loadAccounts failed: ${e.message}")
        } finally {
            db.close()
        }
        return out
    }

    fun loadCategoryNames(context: Context): List<String> {
        val db = openReadable(context) ?: return emptyList()
        val out = mutableListOf<String>()
        try {
            db.query(
                TABLE_CATEGORIES,
                arrayOf("name"),
                "deleted = 0",
                null,
                null,
                null,
                "name COLLATE NOCASE",
            ).use { cursor ->
                val nameIdx = cursor.getColumnIndex("name")
                while (cursor.moveToNext()) {
                    val name = cursor.getString(nameIdx)?.trim().orEmpty()
                    if (name.isNotEmpty()) out.add(name)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "loadCategoryNames failed: ${e.message}")
        } finally {
            db.close()
        }
        return out
    }

    fun loadSubcategories(context: Context): Map<String, List<String>> {
        val db = openReadable(context) ?: return emptyMap()
        val map = linkedMapOf<String, MutableList<String>>()
        try {
            db.query(
                TABLE_SUBCATEGORIES,
                arrayOf("section", "name"),
                "deleted = 0",
                null,
                null,
                null,
                "section, name COLLATE NOCASE",
            ).use { cursor ->
                val sectionIdx = cursor.getColumnIndex("section")
                val nameIdx = cursor.getColumnIndex("name")
                while (cursor.moveToNext()) {
                    val section = cursor.getString(sectionIdx)?.trim().orEmpty()
                    val name = cursor.getString(nameIdx)?.trim().orEmpty()
                    if (section.isEmpty() || name.isEmpty()) continue
                    map.getOrPut(section) { mutableListOf() }.add(name)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "loadSubcategories failed: ${e.message}")
        } finally {
            db.close()
        }
        return map.mapValues { it.value.toList() }
    }

    fun replaceAccountsFromJson(context: Context, accountsJson: String?) {
        val parsed = parseAccountsJson(accountsJson)
        if (parsed.isEmpty()) return
        upsertAccounts(context, parsed)
    }

    fun replaceAccountsFromArray(context: Context, accountsJson: String?) {
        val parsed = parseAccountsArray(accountsJson)
        if (parsed.isEmpty()) return
        upsertAccounts(context, parsed)
    }

    private data class AccountRow(
        val id: String,
        val name: String,
        val balance: Double,
        val type: String,
        val lastDigits: String?,
    )

    private fun parseAccountsJson(raw: String?): List<AccountRow> {
        if (raw.isNullOrBlank() || raw == "null") return emptyList()
        val out = mutableListOf<AccountRow>()
        try {
            val trimmed = raw.trim()
            if (trimmed.startsWith("[")) {
                return parseAccountsArray(trimmed)
            }
            val obj = JSONObject(trimmed)
            val keys = obj.keys()
            while (keys.hasNext()) {
                val id = keys.next()
                val item = obj.optJSONObject(id) ?: continue
                val name = item.optString("name").trim()
                if (name.isEmpty()) continue
                out.add(
                    AccountRow(
                        id = id,
                        name = name,
                        balance = item.optDouble("balance", 0.0),
                        type = item.optString("type", "Cash"),
                        lastDigits = item.optString("last_digits").ifBlank { null },
                    ),
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "parseAccountsJson failed: ${e.message}")
        }
        return out
    }

    private fun parseAccountsArray(raw: String?): List<AccountRow> {
        if (raw.isNullOrBlank() || raw == "null") return emptyList()
        val out = mutableListOf<AccountRow>()
        try {
            val arr = JSONArray(raw.trim())
            for (i in 0 until arr.length()) {
                val item = arr.optJSONObject(i) ?: continue
                val name = item.optString("name").trim()
                if (name.isEmpty()) continue
                val id = item.optString("id").ifBlank { name }
                out.add(
                    AccountRow(
                        id = id,
                        name = name,
                        balance = item.optDouble("balance", 0.0),
                        type = item.optString("type", "Cash"),
                        lastDigits = item.optString("last_digits").ifBlank { null },
                    ),
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "parseAccountsArray failed: ${e.message}")
        }
        return out
    }

    private fun upsertAccounts(context: Context, rows: List<AccountRow>) {
        val db = openWritable(context) ?: return
        val now = System.currentTimeMillis()
        try {
            db.beginTransaction()
            for (row in rows) {
                db.execSQL(
                    """
                    INSERT OR REPLACE INTO $TABLE_ACCOUNTS
                    (id, name, balance, type, icon, color, last_digits, deleted, synced, updated_at)
                    VALUES (?, ?, ?, ?, NULL, NULL, ?, 0, 1, ?)
                    """.trimIndent(),
                    arrayOf(row.id, row.name, row.balance, row.type, row.lastDigits, now),
                )
            }
            db.setTransactionSuccessful()
        } catch (e: Exception) {
            Log.w(TAG, "upsertAccounts failed: ${e.message}")
        } finally {
            try {
                db.endTransaction()
            } catch (_: Exception) {
            }
            db.close()
        }
    }

    fun replaceCategories(context: Context, names: Collection<String>) {
        if (names.isEmpty()) return
        val db = openWritable(context) ?: return
        val now = System.currentTimeMillis()
        try {
            db.beginTransaction()
            for (name in names) {
                val trimmed = name.trim()
                if (trimmed.isEmpty()) continue
                val id = "cat_expense_${trimmed.lowercase().replace(Regex("[^A-Za-z0-9_]"), "_")}"
                db.execSQL(
                    """
                    INSERT OR REPLACE INTO $TABLE_CATEGORIES
                    (id, name, kind, deleted, synced, updated_at)
                    VALUES (?, ?, 'expense', 0, 1, ?)
                    """.trimIndent(),
                    arrayOf(id, trimmed, now),
                )
            }
            db.setTransactionSuccessful()
        } catch (e: Exception) {
            Log.w(TAG, "replaceCategories failed: ${e.message}")
        } finally {
            try {
                db.endTransaction()
            } catch (_: Exception) {
            }
            db.close()
        }
    }

    fun replaceSubcategoriesFromJson(context: Context, subtypesJson: String?) {
        val parsed = OverlayPlannerData.parseSubtypesFromJson(subtypesJson)
        if (parsed.values.all { it.isEmpty() }) return
        val db = openWritable(context) ?: return
        val now = System.currentTimeMillis()
        try {
            db.beginTransaction()
            db.delete(TABLE_SUBCATEGORIES, null, null)
            for ((section, names) in parsed) {
                for (name in names) {
                    val id = "sub_${section}_$name".replace(Regex("[^A-Za-z0-9_]"), "_")
                    db.execSQL(
                        """
                        INSERT OR REPLACE INTO $TABLE_SUBCATEGORIES
                        (id, section, name, deleted, synced, updated_at)
                        VALUES (?, ?, ?, 0, 1, ?)
                        """.trimIndent(),
                        arrayOf(id, section, name, now),
                    )
                }
            }
            db.setTransactionSuccessful()
        } catch (e: Exception) {
            Log.w(TAG, "replaceSubcategoriesFromJson failed: ${e.message}")
        } finally {
            try {
                db.endTransaction()
            } catch (_: Exception) {
            }
            db.close()
        }
    }

    fun enqueueTransaction(
        context: Context,
        request: OverlaySyncRepository.SyncRequest,
        accountId: String?,
    ): Boolean {
        val db = openWritable(context) ?: return false
        val txnId = UUID.randomUUID().toString()
        val isoDate = OverlaySyncRepository.formatIsoDateStatic(request.dateMillis)
        val txnType = if (request.type.equals("credit", true)) "credit" else "debit"
        val description = request.description?.takeIf { it.isNotBlank() }
            ?: OverlaySyncRepository.buildDescriptionStatic(request.body, request.type)
        val note =
            "Planner: ${request.plannerSection} · Subtype: ${request.subtype}\n${request.body}"

        val payload = JSONObject().apply {
            put("id", txnId)
            put("type", txnType)
            put("amount", request.amount)
            put("description", description)
            put("category", request.subtype)
            put("account", request.accountName)
            put("date", isoDate)
            put("note", note)
            if (!accountId.isNullOrBlank()) put("account_id", accountId)
        }

        val now = System.currentTimeMillis()
        return try {
            db.insert(
                TABLE_SYNC_QUEUE,
                null,
                android.content.ContentValues().apply {
                    put("entity", ENTITY_TRANSACTIONS)
                    put("entity_id", txnId)
                    put("action", "upsert")
                    put("payload", payload.toString())
                    put("created_at", now)
                },
            ) > 0
        } catch (e: Exception) {
            Log.w(TAG, "enqueueTransaction failed: ${e.message}")
            false
        } finally {
            db.close()
        }
    }

    fun findAccountId(context: Context, accountName: String): String? {
        return loadAccounts(context).firstOrNull { it.name == accountName }?.id
    }
}
