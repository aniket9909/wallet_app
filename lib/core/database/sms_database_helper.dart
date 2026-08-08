import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/sms_message_model.dart';

class SmsDatabaseHelper {
  static final SmsDatabaseHelper instance = SmsDatabaseHelper._init();
  static Database? _database;

  SmsDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sms_messages.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL';

    await db.execute('''
      CREATE TABLE sms_messages (
        id $idType,
        body $textType,
        address $textType,
        date $integerType,
        is_read $integerType DEFAULT 0,
        status $textType DEFAULT 'pending',
        is_credit_debit $integerType DEFAULT 0,
        amount $realType,
        transaction_type $textType
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for version 2
      await db.execute('ALTER TABLE sms_messages ADD COLUMN status TEXT DEFAULT "pending"');
      await db.execute('ALTER TABLE sms_messages ADD COLUMN is_credit_debit INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE sms_messages ADD COLUMN amount REAL');
      await db.execute('ALTER TABLE sms_messages ADD COLUMN transaction_type TEXT');
    }
  }

  Future<int> insertSms(SmsMessageModel sms) async {
    final db = await database;
    return await db.insert(
      'sms_messages',
      sms.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SmsMessageModel>> getAllSms() async {
    final db = await database;
    const orderBy = 'date DESC';
    final result = await db.query('sms_messages', orderBy: orderBy);
    return result.map((map) => SmsMessageModel.fromMap(map)).toList();
  }

  Future<List<SmsMessageModel>> getUnreadSms() async {
    final db = await database;
    const orderBy = 'date DESC';
    final result = await db.query(
      'sms_messages',
      where: 'is_read = ?',
      whereArgs: [0],
      orderBy: orderBy,
    );
    return result.map((map) => SmsMessageModel.fromMap(map)).toList();
  }

  Future<SmsMessageModel?> getSmsById(int id) async {
    final db = await database;
    final maps = await db.query(
      'sms_messages',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return SmsMessageModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateSms(SmsMessageModel sms) async {
    final db = await database;
    return await db.update(
      'sms_messages',
      sms.toMap(),
      where: 'id = ?',
      whereArgs: [sms.id],
    );
  }

  Future<int> markAsRead(int id) async {
    final db = await database;
    return await db.update(
      'sms_messages',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSms(int id) async {
    final db = await database;
    return await db.delete(
      'sms_messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllSms() async {
    final db = await database;
    return await db.delete('sms_messages');
  }

  Future<int> getSmsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sms_messages');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getUnreadCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sms_messages WHERE is_read = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> existsByBodyAndDate(String body, DateTime date) async {
    final db = await database;
    final result = await db.query(
      'sms_messages',
      where: 'body = ? AND date = ?',
      whereArgs: [body, date.millisecondsSinceEpoch],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<SmsMessageModel?> findByBodyAndDate(String body, DateTime date) async {
    final db = await database;
    final result = await db.query(
      'sms_messages',
      where: 'body = ? AND date = ?',
      whereArgs: [body, date.millisecondsSinceEpoch],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return SmsMessageModel.fromMap(result.first);
  }

  Future<List<SmsMessageModel>> getCreditDebitSms() async {
    final db = await database;
    const orderBy = 'date DESC';
    final result = await db.query(
      'sms_messages',
      where: 'is_credit_debit = ?',
      whereArgs: [1],
      orderBy: orderBy,
    );
    return result.map((map) => SmsMessageModel.fromMap(map)).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

