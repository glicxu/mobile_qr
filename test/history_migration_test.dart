import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('schema 4 rows migrate to QR format without data loss', () async {
    final sqliteDatabase = sqlite3.openInMemory();
    sqliteDatabase.execute('''
      CREATE TABLE history_entries (
        id TEXT NOT NULL PRIMARY KEY,
        activity_kind INTEGER NOT NULL,
        payload_kind INTEGER NOT NULL,
        raw_payload TEXT NOT NULL,
        display_host TEXT,
        title TEXT,
        note TEXT,
        is_in_history INTEGER NOT NULL DEFAULT 1 CHECK (is_in_history IN (0, 1)),
        saved_at_utc INTEGER,
        verification_code TEXT,
        registrable_domain TEXT,
        qr_png_bytes BLOB,
        source INTEGER NOT NULL,
        created_at_utc INTEGER NOT NULL
      )
    ''');
    sqliteDatabase.execute('''
      INSERT INTO history_entries (
        id, activity_kind, payload_kind, raw_payload, display_host, title,
        note, is_in_history, saved_at_utc, verification_code,
        registrable_domain, qr_png_bytes, source, created_at_utc
      ) VALUES (
        'legacy', 1, 0, 'https://example.com', 'example.com', 'Legacy',
        'Kept', 0, 1786809600, 'ABC-123', 'example.com', X'0102', 1,
        1786723200
      )
    ''');
    sqliteDatabase.execute('PRAGMA user_version = 4');

    final database = HistoryDatabase.forTesting(
      NativeDatabase.opened(sqliteDatabase),
    );
    addTearDown(database.close);
    final repository = DriftQrHistoryRepository(database);

    final item = (await repository.watchRecent().first).single;
    expect(item.id, 'legacy');
    expect(item.rawPayload, 'https://example.com');
    expect(item.title, 'Legacy');
    expect(item.note, 'Kept');
    expect(item.isInHistory, isFalse);
    expect(item.savedAtUtc, isNotNull);
    expect(item.verificationCode, 'ABC-123');
    expect(item.registrableDomain, 'example.com');
    expect(item.qrPngBytes, [1, 2]);
    expect(item.codeFormat, ScannedCodeFormat.qrCode);
  });
}
