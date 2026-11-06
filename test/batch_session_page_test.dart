import 'dart:async';

import 'package:dali_qr/features/batch/data/batch_database.dart';
import 'package:dali_qr/features/batch/data/local_batch_repository.dart';
import 'package:dali_qr/features/batch/presentation/batch_sessions_page.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'saved_collections_page_test.dart' show settleDatabase;

SecureQrService _service() => SecureQrService(PublicSuffixList.parse('com'));
const _code = ScannedCode(
  value: '00123',
  format: ScannedCodeFormat.code128,
  source: ScanSource.camera,
);

void main() => registerBatchUiTests();
void registerBatchUiTests() {
  testWidgets(
    'explicit capture rearm prevents double taps, counts, edits, and confirms export',
    (tester) async {
      final repository = LocalBatchRepository(
        BatchDatabase(NativeDatabase.memory()),
      );
      addTearDown(repository.close);
      final session = await repository.createSession(
        'Counting',
        countDuplicates: true,
      );
      final firstCapture = Completer<ScannedCode?>();
      var captures = 0;
      var exports = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BatchSessionPage(
            repository: repository,
            session: session,
            secureQrService: _service(),
            capture: (_) {
              captures++;
              return captures == 1 ? firstCapture.future : Future.value(_code);
            },
            export: (rows, _) async {
              exports++;
              expect(rows.single.quantity, 7);
              expect(rows.single.value, '00123');
            },
          ),
        ),
      );
      await settleDatabase(tester);
      await tester.tap(find.text('Scan next'));
      await tester.tap(find.text('Scan next'));
      firstCapture.complete(_code);
      await settleDatabase(tester);
      expect(captures, 1);
      expect(find.textContaining('Quantity: 1'), findsOneWidget);
      await tester.tap(find.text('Scan next'));
      await settleDatabase(tester);
      expect(find.textContaining('Quantity: 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit quantity'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity'),
        '7',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settleDatabase(tester);
      expect(find.textContaining('Quantity: 7'), findsOneWidget);
      await tester.tap(find.byTooltip('Export CSV'));
      await tester.pumpAndSettle();
      expect(exports, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(exports, 0);
      await tester.tap(find.byTooltip('Export CSV'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share CSV'));
      await settleDatabase(tester);
      expect(exports, 1);
    },
  );

  testWidgets(
    'unique sessions resume with committed rows and ignore repeat captures',
    (tester) async {
      final repository = LocalBatchRepository(
        BatchDatabase(NativeDatabase.memory()),
      );
      addTearDown(repository.close);
      final session = await repository.createSession(
        'Resume',
        countDuplicates: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => BatchSessionPage(
                      repository: repository,
                      session: session,
                      secureQrService: _service(),
                      capture: (_) async => _code,
                    ),
                  ),
                ),
                child: const Text('Open session'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open session'));
      await settleDatabase(tester);
      await tester.tap(find.text('Scan next'));
      await settleDatabase(tester);
      await tester.tap(find.text('Scan next'));
      await settleDatabase(tester);
      expect(find.textContaining('Quantity: 1'), findsOneWidget);
      await tester.tap(find.text('Pause session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open session'));
      await settleDatabase(tester);
      expect(find.text('00123'), findsOneWidget);
      expect(find.textContaining('Quantity: 1'), findsOneWidget);
    },
  );

  testWidgets(
    'batch UI rejects credentials without persisting or displaying their secret',
    (tester) async {
      final repository = LocalBatchRepository(
        BatchDatabase(NativeDatabase.memory()),
      );
      addTearDown(repository.close);
      final session = await repository.createSession(
        'Safe',
        countDuplicates: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BatchSessionPage(
            repository: repository,
            session: session,
            secureQrService: _service(),
            capture: (_) async => const ScannedCode(
              value: 'WIFI:S:Guest;P:private-secret;;',
              format: ScannedCodeFormat.qrCode,
              source: ScanSource.camera,
            ),
          ),
        ),
      );
      await settleDatabase(tester);
      await tester.tap(find.text('Scan next'));
      await settleDatabase(tester);
      expect(find.textContaining('private-secret'), findsNothing);
      expect(find.text('No scans yet. Choose Scan next.'), findsOneWidget);
      expect(
        (await tester.runAsync(() => repository.items(session.id)))!,
        isEmpty,
      );
    },
  );

  testWidgets('batch controls fit on a narrow screen with large text', (
    tester,
  ) async {
    final repository = LocalBatchRepository(
      BatchDatabase(NativeDatabase.memory()),
    );
    addTearDown(repository.close);
    final session = await repository.createSession(
      'Large',
      countDuplicates: false,
    );
    await repository.addCode(session.id, _code);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2.5)),
          child: child!,
        ),
        home: BatchSessionPage(
          repository: repository,
          session: session,
          secureQrService: _service(),
        ),
      ),
    );
    await settleDatabase(tester);
    expect(find.text('Scan next').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
