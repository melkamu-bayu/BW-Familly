import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite store. Two jobs:
///  1. Read cache -- lets list/detail screens render instantly and work offline.
///  2. Outbox -- pending writes queued while offline, pushed via /sync/push
///     once connectivity returns (see state/sync_service.dart).
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'assetflow_local.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE outbox (
            id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,          -- 'revenue' | 'expense'
            payload_json TEXT NOT NULL,
            idempotency_key TEXT NOT NULL UNIQUE,
            status TEXT NOT NULL DEFAULT 'pending', -- pending | syncing | synced | failed
            attempt_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            client_created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_revenue (
            id TEXT PRIMARY KEY,
            transaction_code TEXT,
            business_unit_id TEXT,
            category TEXT,
            amount REAL,
            txn_date TEXT,
            synced INTEGER NOT NULL DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_expense (
            id TEXT PRIMARY KEY,
            transaction_code TEXT,
            business_unit_id TEXT,
            category TEXT,
            amount REAL,
            txn_date TEXT,
            synced INTEGER NOT NULL DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_meta (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

  Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query('sync_meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert('sync_meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
