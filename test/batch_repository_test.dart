import 'dart:convert';
import 'dart:io';

import 'package:dali_qr/features/batch/application/batch_export.dart';
import 'package:dali_qr/features/batch/data/batch_database.dart';
import 'package:dali_qr/features/batch/data/local_batch_repository.dart';
import 'package:dali_qr/features/batch/domain/batch_session.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

ScannedCode code(
  String value, {
  ScannedCodeFormat format = ScannedCodeFormat.code128,
  ScanSource source = ScanSource.camera,
}) => ScannedCode(value: value, format: format, source: source);

void main() {
  late LocalBatchRepository repository;
  late DateTime now;
  setUp(() {
    now = DateTime.utc(2026, 10, 29);
    repository = LocalBatchRepository(
      BatchDatabase(NativeDatabase.memory()),
      now: () => now,
    );
  });
  tearDown(() => repository.close());

  test(
    'unique mode ignores exact repeats and distinguishes formats and whitespace',
    () async {
      final session = await repository.createSession(
        'Unique',
        countDuplicates: false,
      );
      expect(await repository.addCode(session.id, code('00123')), isTrue);
      expect(await repository.addCode(session.id, code('00123')), isFalse);
      await repository.addCode(
        session.id,
        code('00123', format: ScannedCodeFormat.qrCode),
      );
      await repository.addCode(session.id, code(' 00123 '));
      final rows = await repository.items(session.id);
      expect(rows.map((row) => row.value), ['00123', '00123', ' 00123 ']);
      expect(rows.every((row) => row.quantity == 1), isTrue);
      expect((await repository.listSessions()).single.itemCount, 3);
    },
  );

  test(
    'count mode commits one count per accepted capture and keeps the first source',
    () async {
      final session = await repository.createSession(
        'Counts',
        countDuplicates: true,
      );
      await repository.addCode(session.id, code('inventory'));
      now = now.add(const Duration(minutes: 1));
      await repository.addCode(
        session.id,
        code('inventory', source: ScanSource.gallery),
      );
      final row = (await repository.items(session.id)).single;
      expect(row.quantity, 2);
      expect(row.sourceKey, 'camera');
      expect(
        row.lastSeenUtc.difference(row.firstSeenUtc),
        const Duration(minutes: 1),
      );
      await repository.setQuantity(row.id, 12);
      expect((await repository.items(session.id)).single.quantity, 12);
      await expectLater(repository.setQuantity(row.id, 0), throwsArgumentError);
      await repository.removeItem(row.id);
      expect(await repository.items(session.id), isEmpty);
    },
  );

  test(
    'credentials and malformed personal structured data are never persisted',
    () async {
      final session = await repository.createSession(
        'Private',
        countDuplicates: false,
      );
      for (final value in [
        'FIDO:/123456789',
        ' FIDO:/bad',
        'WIFI:S:Guest;P:secret;;',
        'WIFI:S:broken;S:duplicate;;',
        'BEGIN:VCARD\nFN:Private',
        'BEGIN:VCALENDAR',
        'mailto:private@example.com',
        'tel:123',
        'sms:123',
        'smsto:invalid\ntext',
        'http://user:password@example.com',
        'http://user:password@bad host',
      ]) {
        await expectLater(
          repository.addCode(session.id, code(value)),
          throwsArgumentError,
          reason: value,
        );
      }
      expect(await repository.items(session.id), isEmpty);
    },
  );

  test('size and quantity limits reject the whole mutation', () async {
    final session = await repository.createSession(
      'Limits',
      countDuplicates: true,
    );
    await expectLater(
      repository.addCode(session.id, code('x' * 4097)),
      throwsArgumentError,
    );
    await expectLater(
      repository.addCode(session.id, code('é' * 2049)),
      throwsArgumentError,
    );
    await repository.addCode(session.id, code('kept'));
    final row = (await repository.items(session.id)).single;
    await repository.setQuantity(row.id, BatchPolicy.maxQuantity);
    await expectLater(
      repository.addCode(session.id, code('kept')),
      throwsArgumentError,
    );
    expect(
      (await repository.items(session.id)).single.quantity,
      BatchPolicy.maxQuantity,
    );
    await expectLater(
      repository.addCode('missing', code('a')),
      throwsArgumentError,
    );
  });

  test(
    'session deletion cascades its rows and retains other sessions',
    () async {
      final a = await repository.createSession('A', countDuplicates: false);
      final b = await repository.createSession('B', countDuplicates: false);
      await repository.addCode(a.id, code('A'));
      await repository.addCode(b.id, code('B'));
      await repository.deleteSession(a.id);
      expect(await repository.items(a.id), isEmpty);
      expect((await repository.items(b.id)).single.value, 'B');
      expect((await repository.listSessions()).single.id, b.id);
      expect(
        (await repository.database
                .customSelect('PRAGMA secure_delete')
                .getSingle())
            .read<int>('secure_delete'),
        1,
      );
    },
  );

  test(
    'committed sessions recover after the database is closed and reopened',
    () async {
      // Close the unused fixture connection before exercising a real disk store.
      await repository.close();
      final directory = await Directory.systemTemp.createTemp(
        'dali_batch_recovery_',
      );
      final file = File('${directory.path}/batch.sqlite');
      final first = LocalBatchRepository(BatchDatabase(NativeDatabase(file)));
      final session = await first.createSession(
        'Recover',
        countDuplicates: true,
      );
      await first.addCode(session.id, code('00123'));
      await first.addCode(session.id, code('00123'));
      await first.close();
      repository = LocalBatchRepository(BatchDatabase(NativeDatabase(file)));
      expect((await repository.listSessions()).single.countDuplicates, isTrue);
      expect((await repository.items(session.id)).single.quantity, 2);
      await repository.close();
      for (final entity in directory.listSync()) {
        if (entity is File) await entity.delete();
      }
      await directory.delete();
    },
  );

  test(
    'unknown future storage keys survive CSV export without becoming another format',
    () async {
      final session = await repository.createSession(
        'Future',
        countDuplicates: false,
      );
      await repository.database.customStatement(
        'INSERT INTO batch_items VALUES (?,?,?,?,?,?,?,?,?)',
        [
          'future',
          session.id,
          'raw',
          'futureFormat',
          'futureSource',
          1,
          1,
          1,
          1,
        ],
      );
      final rows = await repository.items(session.id);
      expect(rows.single.format, ScannedCodeFormat.unknown);
      expect(rows.single.sourceLabel, 'Unknown source');
      expect(BatchCsv.encode(rows), contains('"futureFormat"'));
      expect(BatchCsv.encode(rows), contains('"futureSource"'));
    },
  );

  test(
    'session limit rejects an additional session without deleting existing sessions',
    () async {
      for (var i = 0; i < BatchPolicy.maxSessions; i++) {
        await repository.createSession('Session $i', countDuplicates: false);
      }
      await expectLater(
        repository.createSession('Overflow', countDuplicates: false),
        throwsArgumentError,
      );
      expect((await repository.listSessions()).length, BatchPolicy.maxSessions);
    },
  );

  for (final byteLimit in [false, true]) {
    test(
      '${byteLimit ? 'UTF-8 byte' : 'distinct row'} limit rejects new rows but permits intentional counts',
      () async {
        final session = await repository.createSession(
          'Bounded',
          countDuplicates: true,
        );
        final count = byteLimit ? 256 : BatchPolicy.maxItems;
        await repository.database.transaction(() async {
          for (var i = 0; i < count; i++) {
            final prefix = '$i:unicode';
            final value = byteLimit
                ? prefix + 'x' * (4096 - utf8.encode(prefix).length)
                : prefix;
            await repository.database.customStatement(
              'INSERT INTO batch_items VALUES (?,?,?,?,?,?,?,?,?)',
              ['seed-$i', session.id, value, 'code128', 'camera', 1, 0, 0, i],
            );
          }
        });
        final first = (await repository.items(session.id)).first;
        await expectLater(
          repository.addCode(session.id, code('overflow')),
          throwsArgumentError,
        );
        expect((await repository.items(session.id)).length, count);
        await repository.addCode(session.id, code(first.value));
        expect((await repository.items(session.id)).first.quantity, 2);
        await repository.setQuantity(first.id, BatchPolicy.maxQuantity);
        await expectLater(
          repository.addCode(session.id, code(first.value)),
          throwsArgumentError,
        );
        expect(
          (await repository.items(session.id)).first.quantity,
          BatchPolicy.maxQuantity,
        );
      },
    );
  }

  test(
    'CSV neutralizes formulas, quotes cells and preserves literal source values',
    () {
      for (final value in [
        '=1+1',
        '+SUM(A1)',
        '-1',
        '@test',
        '\t\r\n =1',
        '\ufeff=1',
        '\u200b=1',
        "'=1",
        '＝1',
      ]) {
        expect(BatchCsv.cell(value), startsWith('"\'\t'), reason: value);
      }
      expect(BatchCsv.cell('00123'), '"00123"');
      expect(BatchCsv.cell('a,"b"\nline'), '"a,""b""\nline"');
      expect(BatchCsv.encode(const []), endsWith('\r\n'));
    },
  );

  test(
    'export files exist during sharing and are removed after success or failure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dali_batch_export_',
      );
      for (final fail in [false, true]) {
        File? exported;
        final future = const BatchExport().share(
          [],
          directory: directory,
          shareFile: (file) async {
            exported = file;
            expect(await file.exists(), isTrue);
            final bytes = await file.readAsBytes();
            expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
            expect(utf8.decode(bytes), startsWith('"value"'));
            if (fail) throw StateError('Share unavailable');
          },
        );
        if (fail) {
          await expectLater(future, throwsStateError);
        } else {
          await future;
        }
        expect(await exported!.exists(), isFalse);
      }
      await directory.delete();
    },
  );

  test(
    'stale cleanup deletes only owned CSVs in export and plugin cache folders',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dali_batch_cleanup_',
      );
      final current = DateTime.utc(2026, 10, 29);
      for (final name in ['dali_batch_exports', 'share_plus']) {
        final folder = await Directory('${directory.path}/$name').create();
        final stale = await File(
          '${folder.path}/dali_batch_old.csv',
        ).writeAsString('old');
        final unrelated = await File(
          '${folder.path}/unrelated.csv',
        ).writeAsString('keep');
        await stale.setLastModified(current.subtract(const Duration(days: 2)));
        await unrelated.setLastModified(
          current.subtract(const Duration(days: 2)),
        );
      }
      await BatchExport.cleanupStale(
        temporaryDirectory: directory,
        now: current,
      );
      for (final name in ['dali_batch_exports', 'share_plus']) {
        final folder = Directory('${directory.path}/$name');
        expect(
          await File('${folder.path}/dali_batch_old.csv').exists(),
          isFalse,
        );
        expect(await File('${folder.path}/unrelated.csv').exists(), isTrue);
        await File('${folder.path}/unrelated.csv').delete();
        await folder.delete();
      }
      await directory.delete();
    },
  );
}
