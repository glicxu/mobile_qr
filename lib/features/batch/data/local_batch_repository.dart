import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';

import '../../scan/domain/scanned_code.dart';
import '../domain/batch_session.dart';
import 'batch_database.dart';

final class LocalBatchRepository implements BatchRepository {
  LocalBatchRepository(this.database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final BatchDatabase database;
  final DateTime Function() _now;
  final _random = Random.secure();

  static Future<LocalBatchRepository> open() async {
    final path = await const MethodChannel(
      'dali_qr/local_storage',
    ).invokeMethod<String>('batchDatabasePath');
    if (path == null || path.isEmpty || !File(path).isAbsolute) {
      throw StateError('Protected local storage is unavailable.');
    }
    final repository = LocalBatchRepository(
      BatchDatabase(NativeDatabase(File(path))),
    );
    try {
      await repository
          .listSessions(); // Open/migrate before showing a usable session screen.
      return repository;
    } on Object {
      await repository.close();
      rethrow;
    }
  }

  String _id() =>
      '${_now().microsecondsSinceEpoch.toRadixString(16)}-${_random.nextInt(1 << 32).toRadixString(16)}-${_random.nextInt(1 << 32).toRadixString(16)}';
  int get _millis => _now().toUtc().millisecondsSinceEpoch;

  @override
  Future<List<BatchSession>> listSessions() async =>
      (await database.customSelect('''
    SELECT s.*, (SELECT COUNT(*) FROM batch_items i WHERE i.session_id=s.id) AS item_count
    FROM batch_sessions s ORDER BY s.updated_utc DESC, s.id
  ''').get()).map(_session).toList(growable: false);

  static BatchSession _session(QueryRow row) => BatchSession(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    countDuplicates: row.read<int>('count_duplicates') == 1,
    createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
      row.read<int>('created_utc'),
      isUtc: true,
    ),
    updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
      row.read<int>('updated_utc'),
      isUtc: true,
    ),
    itemCount: row.read<int>('item_count'),
  );

  @override
  Future<BatchSession> createSession(
    String name, {
    required bool countDuplicates,
  }) => database.transaction(() async {
    final clean = BatchPolicy.sessionName(name);
    if ((await listSessions()).length >= BatchPolicy.maxSessions) {
      throw ArgumentError(
        'Delete a session before creating another. The limit is 50 sessions.',
      );
    }
    final id = _id();
    final time = _millis;
    await database.customStatement(
      'INSERT INTO batch_sessions VALUES (?,?,?,?,?)',
      [id, clean, countDuplicates ? 1 : 0, time, time],
    );
    return BatchSession(
      id: id,
      name: clean,
      countDuplicates: countDuplicates,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(time, isUtc: true),
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(time, isUtc: true),
    );
  });

  @override
  Future<List<BatchItem>> items(String sessionId) async =>
      (await database
              .customSelect(
                'SELECT * FROM batch_items WHERE session_id = ? ORDER BY position, id',
                variables: [Variable<String>(sessionId)],
              )
              .get())
          .map(
            (row) => BatchItem(
              id: row.read<String>('id'),
              sessionId: row.read<String>('session_id'),
              value: row.read<String>('value'),
              format: ScannedCodeFormat.fromStorageKey(
                row.read<String>('format'),
              ),
              storedFormatKey: row.read<String>('format'),
              sourceKey: row.read<String>('source'),
              quantity: row.read<int>('quantity'),
              firstSeenUtc: DateTime.fromMillisecondsSinceEpoch(
                row.read<int>('first_utc'),
                isUtc: true,
              ),
              lastSeenUtc: DateTime.fromMillisecondsSinceEpoch(
                row.read<int>('last_utc'),
                isUtc: true,
              ),
            ),
          )
          .toList(growable: false);

  @override
  Future<bool> addCode(String sessionId, ScannedCode code) async {
    BatchPolicy.validateCode(code);
    return database.transaction(() async {
      final session = await database
          .customSelect(
            'SELECT * FROM batch_sessions WHERE id = ?',
            variables: [Variable<String>(sessionId)],
          )
          .getSingleOrNull();
      if (session == null) {
        throw ArgumentError('This session no longer exists.');
      }
      final existing = await database
          .customSelect(
            'SELECT * FROM batch_items WHERE session_id = ? AND format = ? AND value = ?',
            variables: [
              Variable<String>(sessionId),
              Variable<String>(code.format.storageKey),
              Variable<String>(code.value),
            ],
          )
          .getSingleOrNull();
      final time = _millis;
      if (existing != null) {
        if (session.read<int>('count_duplicates') == 0) return false;
        final quantity = existing.read<int>('quantity');
        if (quantity >= BatchPolicy.maxQuantity) {
          throw ArgumentError('The maximum quantity is 999999.');
        }
        await database.customStatement(
          'UPDATE batch_items SET quantity = ?, last_utc = ? WHERE id = ?',
          [quantity + 1, time, existing.read<String>('id')],
        );
      } else {
        final current = await items(sessionId);
        if (current.length >= BatchPolicy.maxItems) {
          throw ArgumentError('The session limit is 1000 distinct codes.');
        }
        if (current.fold<int>(
                  0,
                  (sum, item) => sum + utf8.encode(item.value).length,
                ) +
                utf8.encode(code.value).length >
            BatchPolicy.maxSessionBytes) {
          throw ArgumentError(
            'The session has reached its 1 MiB content limit.',
          );
        }
        final position = await database
            .customSelect(
              'SELECT COALESCE(MAX(position), -1) AS last_position FROM batch_items WHERE session_id = ?',
              variables: [Variable<String>(sessionId)],
            )
            .getSingle();
        await database.customStatement(
          'INSERT INTO batch_items VALUES (?,?,?,?,?,?,?,?,?)',
          [
            _id(),
            sessionId,
            code.value,
            code.format.storageKey,
            code.source.name,
            1,
            time,
            time,
            position.read<int>('last_position') + 1,
          ],
        );
      }
      await database.customStatement(
        'UPDATE batch_sessions SET updated_utc = ? WHERE id = ?',
        [time, sessionId],
      );
      return true;
    });
  }

  @override
  Future<void> setQuantity(String itemId, int quantity) async {
    if (quantity < 1 || quantity > BatchPolicy.maxQuantity) {
      throw ArgumentError('Quantity must be between 1 and 999999.');
    }
    await database.transaction(() async {
      await database.customStatement(
        'UPDATE batch_sessions SET updated_utc = ? WHERE id = (SELECT session_id FROM batch_items WHERE id = ?)',
        [_millis, itemId],
      );
      await database.customStatement(
        'UPDATE batch_items SET quantity = ? WHERE id = ?',
        [quantity, itemId],
      );
    });
  }

  @override
  Future<void> removeItem(String itemId) => database.transaction(() async {
    await database.customStatement(
      'UPDATE batch_sessions SET updated_utc = ? WHERE id = (SELECT session_id FROM batch_items WHERE id = ?)',
      [_millis, itemId],
    );
    await database.customStatement('DELETE FROM batch_items WHERE id = ?', [
      itemId,
    ]);
  });
  @override
  Future<void> deleteSession(String sessionId) => database.customStatement(
    'DELETE FROM batch_sessions WHERE id = ?',
    [sessionId],
  );
  @override
  Future<void> close() => database.close();
}
