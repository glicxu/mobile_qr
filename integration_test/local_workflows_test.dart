import 'dart:io';

import 'package:dali_qr/features/batch/data/local_batch_repository.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/batch_session_page_test.dart' as batch;
import '../test/gs1_details_test.dart' as gs1;
import '../test/saved_collections_page_test.dart' as collections;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  collections.registerCollectionsTests();
  batch.registerBatchUiTests();
  gs1.registerGs1UiTests(rejectNetwork: false);
  testWidgets(
    'native batch storage is private and committed rows survive reopening',
    (tester) async {
      final path = await const MethodChannel(
        'dali_qr/local_storage',
      ).invokeMethod<String>('batchDatabasePath');
      expect(path, isNotNull);
      expect(
        path,
        contains(Platform.isAndroid ? '/no_backup/dali_batch/' : '/DaliBatch/'),
      );
      var repository = await LocalBatchRepository.open();
      final session = await repository.createSession(
        'QA storage reopen',
        countDuplicates: false,
      );
      try {
        await repository.addCode(
          session.id,
          const ScannedCode(
            value: '00123',
            format: ScannedCodeFormat.code128,
            source: ScanSource.camera,
          ),
        );
        await repository.close();
        repository = await LocalBatchRepository.open();
        final row = (await repository.items(session.id)).single;
        expect(row.value, '00123');
        expect(row.quantity, 1);
      } finally {
        await repository.deleteSession(session.id);
        await repository.close();
      }
    },
  );
}
