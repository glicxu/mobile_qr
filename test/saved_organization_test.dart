import 'dart:io';

import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

QrHistoryItem item(String id, {bool saved = true, bool history = true}) =>
    QrHistoryItem(
      id: id,
      activityKind: QrActivityKind.scanned,
      payloadKind: QrPayloadKind.text,
      rawPayload: '  00123 $id  ',
      displayHost: null,
      title: 'Title $id',
      note: 'Kept',
      codeFormat: ScannedCodeFormat.code128,
      source: QrActivitySource.sharedImage,
      isInHistory: history,
      savedAtUtc: saved ? DateTime.utc(2026, 10, 29) : null,
      createdAtUtc: DateTime.utc(2026, 10, 28),
    );

void main() {
  late HistoryDatabase database;
  late DriftQrHistoryRepository repository;
  setUp(() {
    database = HistoryDatabase.forTesting(NativeDatabase.memory());
    repository = DriftQrHistoryRepository(database);
  });
  tearDown(() => database.close());

  test(
    'Saved items can have multiple collections and case-insensitive tags',
    () async {
      await repository.save(item('a'));
      await repository.createCollection('one', ' Personal ');
      await repository.createCollection('two', 'Work');
      await repository.organizeSavedItem(
        'a',
        collectionIds: {'one', 'two'},
        tags: ['Travel', 'travel', 'Office'],
      );
      final organization = await repository.watchOrganization().first;
      expect(organization.collections.map((value) => value.name), [
        'Personal',
        'Work',
      ]);
      expect(organization.memberships['a'], unorderedEquals(['one', 'two']));
      expect(organization.tags['a'], ['Office', 'Travel']);
      final stored = (await repository.watchRecent().first).single;
      expect(stored.rawPayload, '  00123 a  ');
      expect(stored.note, 'Kept');
      expect(stored.codeFormat, ScannedCodeFormat.code128);
      expect(stored.source, QrActivitySource.sharedImage);
    },
  );

  test(
    'collection deletion and removing one membership keep Saved data',
    () async {
      await repository.save(item('a', history: false));
      await repository.createCollection('one', 'One');
      await repository.createCollection('two', 'Two');
      await repository.organizeSavedItem(
        'a',
        collectionIds: {'one', 'two'},
        tags: ['keep'],
      );
      await repository.organizeSavedItem(
        'a',
        collectionIds: {'two'},
        tags: ['keep'],
      );
      expect((await repository.watchOrganization().first).memberships['a'], [
        'two',
      ]);
      await repository.deleteCollection('two');
      expect((await repository.watchOrganization().first).memberships, isEmpty);
      expect(
        (await repository.watchRecent().first).single.savedAtUtc,
        isNotNull,
      );
    },
  );

  test(
    'clear history preserves Saved memberships, tags, notes and timestamps',
    () async {
      await repository.save(item('both'));
      await repository.save(item('saved-only', history: false));
      await repository.save(item('history-only', saved: false));
      await repository.createCollection('one', 'Keep');
      await repository.organizeSavedItem(
        'both',
        collectionIds: {'one'},
        tags: ['Keep'],
      );
      await repository.clearHistory();
      final rows = await repository.watchRecent().first;
      expect(
        rows.map((value) => value.id),
        unorderedEquals(['both', 'saved-only']),
      );
      expect(
        rows.every((value) => !value.isInHistory && value.savedAtUtc != null),
        isTrue,
      );
      expect((await repository.watchOrganization().first).memberships['both'], [
        'one',
      ]);
      expect((await repository.watchOrganization().first).tags['both'], [
        'Keep',
      ]);
    },
  );

  test(
    'unsaving clears organization even when the history row is retained',
    () async {
      await repository.save(item('both'));
      await repository.save(item('saved-only', history: false));
      await repository.createCollection('one', 'Keep');
      for (final id in ['both', 'saved-only']) {
        await repository.organizeSavedItem(
          id,
          collectionIds: {'one'},
          tags: ['tag'],
        );
      }
      await repository.removeFromSaved('both');
      var organization = await repository.watchOrganization().first;
      expect(organization.memberships.containsKey('both'), isFalse);
      expect(organization.tags.containsKey('both'), isFalse);
      expect(organization.memberships['saved-only'], ['one']);
      final rows = await repository.watchRecent().first;
      expect(
        rows.singleWhere((value) => value.id == 'both').isInHistory,
        isTrue,
      );
      await repository.removeFromSaved('saved-only');
      organization = await repository.watchOrganization().first;
      expect(organization.memberships, isEmpty);
      expect(organization.tags, isEmpty);
      expect((await repository.watchRecent().first).map((value) => value.id), [
        'both',
      ]);
    },
  );

  test(
    'invalid assignments roll back without losing existing organization',
    () async {
      await repository.save(item('a'));
      await repository.save(item('unsaved', saved: false));
      await repository.createCollection('one', 'One');
      await repository.organizeSavedItem(
        'a',
        collectionIds: {'one'},
        tags: ['keep'],
      );
      await expectLater(
        repository.organizeSavedItem('a', collectionIds: {'missing'}, tags: []),
        throwsArgumentError,
      );
      await expectLater(
        repository.organizeSavedItem(
          'a',
          collectionIds: {},
          tags: List.generate(21, (index) => 'tag$index'),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.organizeSavedItem(
          'unsaved',
          collectionIds: {'one'},
          tags: [],
        ),
        throwsArgumentError,
      );
      final organization = await repository.watchOrganization().first;
      expect(organization.memberships['a'], ['one']);
      expect(organization.tags['a'], ['keep']);
      await expectLater(
        repository.createCollection('duplicate', ' one '),
        throwsArgumentError,
      );
      await repository.renameCollection('one', 'Renamed');
      expect(
        (await repository.watchOrganization().first).collections.single.name,
        'Renamed',
      );
    },
  );

  test(
    'schema 5 upgrades preserve barcode fields and create empty organization',
    () async {
      final legacy = sqlite3.openInMemory();
      legacy.execute('''CREATE TABLE history_entries (
      id TEXT NOT NULL PRIMARY KEY, activity_kind INTEGER NOT NULL, payload_kind INTEGER NOT NULL,
      raw_payload TEXT NOT NULL, display_host TEXT, title TEXT, note TEXT,
      is_in_history INTEGER NOT NULL DEFAULT 1, saved_at_utc INTEGER, verification_code TEXT,
      registrable_domain TEXT, qr_png_bytes BLOB, code_format TEXT NOT NULL DEFAULT 'qrCode',
      source INTEGER NOT NULL, created_at_utc INTEGER NOT NULL)''');
      legacy.execute(
        "INSERT INTO history_entries VALUES ('old',1,1,'0012345678905',NULL,'Title','Note',0,1793232000,NULL,NULL,X'0102','ean13',3,1793145600)",
      );
      legacy.execute('PRAGMA user_version = 5');
      final upgraded = HistoryDatabase.forTesting(
        NativeDatabase.opened(legacy),
      );
      addTearDown(upgraded.close);
      final repo = DriftQrHistoryRepository(upgraded);
      final row = (await repo.watchRecent().first).single;
      expect(row.rawPayload, '0012345678905');
      expect(row.codeFormat, ScannedCodeFormat.ean13);
      expect(row.source, QrActivitySource.sharedImage);
      expect(row.qrPngBytes, [1, 2]);
      expect(row.title, 'Title');
      expect(row.note, 'Note');
      expect(row.isInHistory, isFalse);
      expect(row.savedAtUtc, isNotNull);
      expect((await repo.watchOrganization().first).collections, isEmpty);
      await repo.createCollection('new', 'New');
      await repo.organizeSavedItem(
        'old',
        collectionIds: {'new'},
        tags: ['Upgraded'],
      );
      expect((await repo.watchOrganization().first).memberships['old'], [
        'new',
      ]);
    },
  );

  test('collections and tags persist across database reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dali_collections_',
    );
    final file = File('${directory.path}/history.sqlite');
    final first = HistoryDatabase.forTesting(NativeDatabase(file));
    final writer = DriftQrHistoryRepository(first);
    await writer.save(item('persist'));
    await writer.createCollection('folder', 'Offline');
    await writer.organizeSavedItem(
      'persist',
      collectionIds: {'folder'},
      tags: ['Persistent'],
    );
    await first.close();
    final second = HistoryDatabase.forTesting(NativeDatabase(file));
    try {
      final reader = DriftQrHistoryRepository(second);
      expect((await reader.watchOrganization().first).tags['persist'], [
        'Persistent',
      ]);
      expect((await reader.watchOrganization().first).memberships['persist'], [
        'folder',
      ]);
      expect(
        (await reader.watchRecent().first).single.rawPayload,
        '  00123 persist  ',
      );
    } finally {
      await second.close();
      for (final entity in directory.listSync()) {
        if (entity is File) await entity.delete();
      }
      await directory.delete();
    }
  });
}
