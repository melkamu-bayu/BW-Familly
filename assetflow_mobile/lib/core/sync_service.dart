import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'api_client.dart';
import 'local_db.dart';
import 'outbox_repository.dart';

enum SyncStatus { idle, syncing, error }

/// Drains the outbox against POST /sync/push whenever connectivity returns.
/// Each push batch is capped (matches the server's SyncPushRequest max_length)
/// and failures back off exponentially rather than hammering the API.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _batchSize = 50;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  void start() {
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        // Fire and forget -- UI observes statusStream for progress.
        pushOutbox();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _statusController.close();
  }

  Future<void> pushOutbox({int attempt = 0}) async {
    final pending = await OutboxRepository.instance.pendingEntries();
    if (pending.isEmpty) return;

    _statusController.add(SyncStatus.syncing);

    try {
      final batch = pending.take(_batchSize).toList();
      final items = batch
          .map((entry) => {
                'entity_type': entry.entityType,
                'client_created_at': DateTime.now().toIso8601String(),
                'payload': entry.payload,
              })
          .toList();

      final response = await ApiClient.instance.dio.post('/sync/push', data: {'items': items});
      final results = (response.data['results'] as List).cast<Map<String, dynamic>>();

      for (var i = 0; i < batch.length; i++) {
        final result = results[i];
        final status = result['status'] as String;
        if (status == 'applied' || status == 'duplicate') {
          await OutboxRepository.instance.markSynced(batch[i].id);
        } else {
          await OutboxRepository.instance.markFailed(batch[i].id, result['error']?.toString() ?? 'rejected');
        }
      }

      await pullSince();

      // More left in the outbox (batch was capped) -- keep draining.
      final remaining = await OutboxRepository.instance.pendingCount();
      if (remaining > 0) {
        await pushOutbox();
      } else {
        _statusController.add(SyncStatus.idle);
      }
    } catch (e) {
      _statusController.add(SyncStatus.error);
      if (attempt < 5) {
        final delaySeconds = pow(2, attempt).toInt().clamp(1, 60);
        Timer(Duration(seconds: delaySeconds), () => pushOutbox(attempt: attempt + 1));
      }
    }
  }

  /// Pulls server-authoritative changes since the last watermark and stores
  /// the new server_time as the next watermark -- never the device clock,
  /// so device/server time drift can't cause missed records.
  Future<void> pullSince() async {
    final lastSync = await LocalDatabase.instance.getMeta('last_sync_watermark') ??
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    try {
      final response = await ApiClient.instance.dio.get('/sync/pull', queryParameters: {'since': lastSync});
      final data = response.data as Map<String, dynamic>;

      final db = await LocalDatabase.instance.database;
      for (final row in (data['revenue'] as List).cast<Map<String, dynamic>>()) {
        await db.insert('cached_revenue', {
          'id': row['id'],
          'transaction_code': row['transaction_code'],
          'business_unit_id': row['business_unit_id'],
          'category': row['category'],
          'amount': row['amount'],
          'txn_date': row['txn_date'],
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in (data['expenses'] as List).cast<Map<String, dynamic>>()) {
        await db.insert('cached_expense', {
          'id': row['id'],
          'transaction_code': row['transaction_code'],
          'business_unit_id': row['business_unit_id'],
          'category': row['category'],
          'amount': row['amount'],
          'txn_date': row['txn_date'],
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await LocalDatabase.instance.setMeta('last_sync_watermark', data['server_time'] as String);
    } catch (_) {
      // Pull failures are non-fatal -- the push side already succeeded,
      // and the next successful pull will catch up regardless of watermark gaps.
    }
  }
}
