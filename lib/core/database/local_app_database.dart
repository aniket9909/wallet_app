import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/account_model.dart';
import '../../data/models/money_plan_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/transaction_model_new.dart';
import '../../data/models/wallet_data_model.dart';
import '../utils/planner_navigation.dart';

/// Shared SQLite file used by Flutter and Android Kotlin.
/// Android path: /data/data/<package>/databases/arthigo_local.db
class LocalAppDatabase {
  LocalAppDatabase._();
  static final LocalAppDatabase instance = LocalAppDatabase._();

  static const dbName = 'arthigo_local.db';
  static const version = 1;

  static const accountsTable = 'accounts';
  static const categoriesTable = 'categories';
  static const subcategoriesTable = 'subcategories';
  static const entitiesTable = 'local_entities';
  static const syncQueueTable = 'sync_queue';

  static const entitySettings = 'settings';
  static const entityWallet = 'wallet';
  static const entityMoneyPlan = 'money_plan';
  static const entityTransactions = 'transactions';
  static const entityDebts = 'debts';
  static const entityInvestments = 'investments';
  static const entityGoals = 'goals';
  static const entityPartials = 'partialTransactions';

  Database? _db;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, dbName);
    return openDatabase(
      path,
      version: version,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) async {
        await _createSchema(db);
        await _seedDefaults(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $accountsTable (
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
    ''');
    await db.execute('''
      CREATE TABLE $categoriesTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'expense',
        deleted INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $subcategoriesTable (
        id TEXT PRIMARY KEY,
        section TEXT NOT NULL,
        name TEXT NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $entitiesTable (
        key TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $syncQueueTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _seedDefaults(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const defaults = [
      'Food',
      'Bills',
      'Shopping',
      'Travel',
      'Entertainment',
      'Health',
      'Other',
    ];
    for (final name in defaults) {
      await db.insert(categoriesTable, {
        'id': 'cat_${name.toLowerCase()}',
        'name': name,
        'kind': 'expense',
        'deleted': 0,
        'synced': 0,
        'updated_at': now,
      });
    }
    for (final entry in PlannerCategories.defaultSubtypes.entries) {
      for (final name in entry.value) {
        await db.insert(subcategoriesTable, {
          'id': 'sub_${entry.key}_$name'.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_'),
          'section': entry.key,
          'name': name,
          'deleted': 0,
          'synced': 0,
          'updated_at': now,
        });
      }
    }
  }

  String newId() => _uuid.v4();

  int _now() => DateTime.now().millisecondsSinceEpoch;

  // ---------- accounts ----------

  Future<List<AccountModel>> getAccounts() async {
    final db = await database;
    final rows = await db.query(
      accountsTable,
      where: 'deleted = 0',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(_accountFromRow).toList();
  }

  Future<void> upsertAccount(AccountModel account, {bool synced = false}) async {
    final db = await database;
    await db.insert(
      accountsTable,
      {
        'id': account.id,
        'name': account.name,
        'balance': account.balance,
        'type': account.type,
        'icon': account.icon,
        'color': account.color,
        'last_digits': account.lastDigits,
        'deleted': 0,
        'synced': synced ? 1 : 0,
        'updated_at': _now(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceAccounts(List<AccountModel> accounts, {bool synced = true}) async {
    final db = await database;
    await db.transaction((txn) async {
      final pending = await txn.query(
        accountsTable,
        where: 'synced = 0',
      );
      await txn.delete(accountsTable, where: 'synced = 1 OR deleted = 1');
      for (final account in accounts) {
        final alreadyPending = pending.any((row) => row['id'] == account.id);
        if (alreadyPending) continue;
        await txn.insert(accountsTable, {
          'id': account.id,
          'name': account.name,
          'balance': account.balance,
          'type': account.type,
          'icon': account.icon,
          'color': account.color,
          'last_digits': account.lastDigits,
          'deleted': 0,
          'synced': synced ? 1 : 0,
          'updated_at': _now(),
        });
      }
    });
  }

  Future<void> markAccountDeleted(String id) async {
    final db = await database;
    await db.update(
      accountsTable,
      {'deleted': 1, 'synced': 0, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  AccountModel _accountFromRow(Map<String, Object?> row) {
    return AccountModel(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      balance: (row['balance'] as num?)?.toDouble() ?? 0,
      type: row['type'] as String? ?? 'Cash',
      icon: row['icon'] as String?,
      color: row['color'] as String?,
      lastDigits: row['last_digits'] as String?,
    );
  }

  // ---------- categories ----------

  Future<List<String>> getCategoryNames({String kind = 'expense'}) async {
    final db = await database;
    final rows = await db.query(
      categoriesTable,
      where: 'deleted = 0 AND kind = ?',
      whereArgs: [kind],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  Future<void> replaceCategories(List<String> names, {String kind = 'expense', bool synced = false}) async {
    final db = await database;
    final now = _now();
    await db.transaction((txn) async {
      await txn.delete(categoriesTable, where: 'kind = ?', whereArgs: [kind]);
      for (final name in names) {
        await txn.insert(categoriesTable, {
          'id': 'cat_${kind}_${name.toLowerCase()}'.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_'),
          'name': name,
          'kind': kind,
          'deleted': 0,
          'synced': synced ? 1 : 0,
          'updated_at': now,
        });
      }
    });
  }

  // ---------- subcategories ----------

  Future<Map<String, List<String>>> getSubcategories() async {
    final db = await database;
    final rows = await db.query(
      subcategoriesTable,
      where: 'deleted = 0',
      orderBy: 'section, name COLLATE NOCASE',
    );
    final map = <String, List<String>>{};
    for (final row in rows) {
      final section = row['section'] as String;
      final name = row['name'] as String;
      map.putIfAbsent(section, () => []).add(name);
    }
    return map;
  }

  Future<void> upsertSubcategory(String section, String name, {bool synced = false}) async {
    final db = await database;
    final id = 'sub_${section}_$name'.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    await db.insert(
      subcategoriesTable,
      {
        'id': id,
        'section': section,
        'name': name,
        'deleted': 0,
        'synced': synced ? 1 : 0,
        'updated_at': _now(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceSubcategories(
    Map<String, List<String>> bySection, {
    bool synced = false,
  }) async {
    final db = await database;
    final now = _now();
    await db.transaction((txn) async {
      await txn.delete(subcategoriesTable);
      for (final entry in bySection.entries) {
        for (final name in entry.value) {
          await txn.insert(subcategoriesTable, {
            'id': 'sub_${entry.key}_$name'.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_'),
            'section': entry.key,
            'name': name,
            'deleted': 0,
            'synced': synced ? 1 : 0,
            'updated_at': now,
          });
        }
      }
    });
  }

  Future<void> replaceSubcategoriesFromPlan(MoneyPlanModel plan, {bool synced = false}) async {
    final map = <String, List<String>>{};
    for (final entry in PlannerCategories.defaultSubtypes.entries) {
      map[entry.key] = List<String>.from(entry.value);
    }
    void merge(String section, Iterable<String> names) {
      final list = map.putIfAbsent(section, () => []);
      for (final name in names) {
        if (name.trim().isEmpty) continue;
        if (!list.contains(name)) list.insert(0, name);
      }
    }

    merge(PlannerSections.essentials, plan.expenses.map((e) => e.name));
    merge(PlannerSections.investment, plan.investments.map((e) => e.name));
    merge(PlannerSections.goals, plan.goals.map((e) => e.name));
    merge(PlannerSections.debt, plan.debts.map((e) => e.name));
    merge(PlannerSections.personal, plan.personalCategories.map((e) => e.name));
    await replaceSubcategories(map, synced: synced);
  }

  // ---------- generic JSON entities ----------

  Future<void> putEntity(String key, Map<String, dynamic> json, {bool synced = false}) async {
    final db = await database;
    await db.insert(
      entitiesTable,
      {
        'key': key,
        'json': jsonEncode(json),
        'synced': synced ? 1 : 0,
        'updated_at': _now(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getEntity(String key) async {
    final db = await database;
    final rows = await db.query(
      entitiesTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['json'] as String?;
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  Future<void> putEntityList(String key, List<Map<String, dynamic>> items, {bool synced = false}) async {
    await putEntity(key, {'items': items}, synced: synced);
  }

  Future<List<Map<String, dynamic>>> getEntityList(String key) async {
    final data = await getEntity(key);
    final items = data?['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ---------- typed helpers ----------

  Future<void> saveSettings(SettingsModel settings, {bool synced = false}) async {
    await putEntity(entitySettings, Map<String, dynamic>.from(settings.toJson()), synced: synced);
    await replaceCategories(settings.expenseTypes, kind: 'expense', synced: synced);
  }

  Future<SettingsModel?> loadSettings() async {
    final json = await getEntity(entitySettings);
    if (json == null) return null;
    return SettingsModel.fromJson(json);
  }

  Future<void> saveWallet(WalletDataModel wallet, {bool synced = false}) async {
    await putEntity(entityWallet, Map<String, dynamic>.from(wallet.toJson()), synced: synced);
  }

  Future<WalletDataModel?> loadWallet() async {
    final json = await getEntity(entityWallet);
    if (json == null) return null;
    return WalletDataModel.fromJson(json);
  }

  Future<void> saveMoneyPlan(MoneyPlanModel plan, {bool synced = false}) async {
    await putEntity(entityMoneyPlan, Map<String, dynamic>.from(plan.toJson()), synced: synced);
    await replaceSubcategoriesFromPlan(plan, synced: synced);
  }

  Future<MoneyPlanModel?> loadMoneyPlan() async {
    final json = await getEntity(entityMoneyPlan);
    if (json == null) return null;
    return MoneyPlanModel.fromJson(json);
  }

  Future<void> saveTransactions(List<TransactionModelNew> items, {bool synced = false}) async {
    if (synced && items.isEmpty) {
      final local = await loadTransactions();
      if (local.isNotEmpty) return;
    }
    await putEntityList(
      entityTransactions,
      items.map((t) => {'id': t.id, ...t.toJson()}).toList(),
      synced: synced,
    );
  }

  Future<List<TransactionModelNew>> loadTransactions() async {
    final items = await getEntityList(entityTransactions);
    return items
        .map((e) => TransactionModelNew.fromJson(e['id']?.toString() ?? '', e))
        .toList();
  }

  // ---------- sync queue ----------

  Future<void> enqueue({
    required String entity,
    required String entityId,
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    final db = await database;
    await db.insert(syncQueueTable, {
      'entity': entity,
      'entity_id': entityId,
      'action': action,
      'payload': payload == null ? null : jsonEncode(payload),
      'created_at': _now(),
    });
  }

  Future<List<Map<String, dynamic>>> pendingSync() async {
    final db = await database;
    final rows = await db.query(syncQueueTable, orderBy: 'id ASC');
    return rows
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> removeQueueItem(int id) async {
    final db = await database;
    await db.delete(syncQueueTable, where: 'id = ?', whereArgs: [id]);
  }
}
