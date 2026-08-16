import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'local_db.dart';

class OutboxEntry {
  final String id;
  final String entityType;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final String status;
  final int attemptCount;

  OutboxEntry({
    required this.id,
    required this.entityType,
    required this.payload,
    required this.idempotencyKey,
    required this.status,
    required this.attemptCount,
  });

  factory OutboxEntry.fromRow(Map<String, dynamic> row) => OutboxEntry(
        id: row['id'] as String,
        entityType: row['entity_type'] as String,
        payload: jsonDecode(row['payload_json'] as String) as Map<String, dynamic>,
        idempotencyKey: row['idempotency_key'] as String,
        status: row['status'] as String,
        attemptCount: row['attempt_count'] as int,
      );
}

/// Queues a revenue/expense write locally and (if online) attempts to push
/// it immediately; if offline, it just sits in the outbox until SyncService
/// runs on the next connectivity change. Every write generates its own
/// idempotency key client-side, matching the server's dedup contract.
class OutboxRepository {
  OutboxRepository._();
  static final OutboxRepository instance = OutboxRepository._();

  final _uuid = const Uuid();

  Future<String> enqueue({
    required String entityType, // 'revenue' | 'expense'
    required Map<String, dynamic> payload,
  }) async {
    final db = await LocalDatabase.instance.database;
    final idempotencyKey = _uuid.v4();
    final id = _uuid.v4();

    final enrichedPayload = {...payload, 'idempotency_key': idempotencyKey};

    await db.insert('outbox', {
      'id': id,
      'entity_type': entityType,
      'payload_json': jsonEncode(enrichedPayload),
      'idempotency_key': idempotencyKey,
      'status': 'pending',
      'attempt_count': 0,
      'client_created_at': DateTime.now().toIso8601String(),
    });

    return id;
  }

  Future<List<OutboxEntry>> pendingEntries() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('outbox', where: "status IN ('pending', 'failed')", orderBy: 'client_created_at ASC');
    return rows.map(OutboxEntry.fromRow).toList();
  }

  Future<void> markSynced(String outboxId) async {
    final db = await LocalDatabase.instance.database;
    await db.update('outbox', {'status': 'synced'}, where: 'id = ?', whereArgs: [outboxId]);
  }

  Future<void> markFailed(String outboxId, String error) async {
    final db = await LocalDatabase.instance.database;
    await db.rawUpdate(
      "UPDATE outbox SET status = 'failed', attempt_count = attempt_count + 1, last_error = ? WHERE id = ?",
      [error, outboxId],
    );
  }

  Future<int> pendingCount() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM outbox WHERE status IN ('pending', 'failed')",
    );
    if (result.isEmpty) return 0;
    final value = result.first['c'];
    return value is int ? value : int.tryParse(value.toString()) ?? 0;
  }
}
