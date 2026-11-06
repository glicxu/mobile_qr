import 'dart:io';

import 'package:dali_qr/features/history/application/history_controller.dart';
import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:dali_qr/features/history/presentation/history_page.dart';
import 'package:dali_qr/features/history/presentation/saved_page.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:dali_qr/features/scan/presentation/qr_scanner_page.dart';
import 'package:dali_qr/features/scan/presentation/share_extension_result_app.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

SecureQrService _service() => SecureQrService(PublicSuffixList.parse('com'));

void main() {
  registerIdentifierDetailsTests();

  testWidgets(
    'copy contents uses the original ISBN label and lowercase check character',
    (tester) async {
      const raw = 'ISBN-10: 0-8044-2957-x';
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        _result(raw, ScannedCodeFormat.qrCode, ScanSource.camera),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Details'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      final copy = find.widgetWithText(OutlinedButton, 'Copy contents');
      for (
        var attempt = 0;
        attempt < 10 && copy.hitTestable().evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      await tester.tap(copy.hitTestable());
      await tester.pumpAndSettle();
      expect(copied, raw);
    },
  );
}

void registerIdentifierDetailsTests({bool rejectNetwork = true}) {
  late UrlLauncherPlatform previousLauncher;
  late _NoLaunch launcher;
  _NoNetwork? network;
  HttpOverrides? previousNetwork;
  setUp(() {
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = _NoLaunch();
    UrlLauncherPlatform.instance = launcher;
    if (rejectNetwork) {
      previousNetwork = HttpOverrides.current;
      network = _NoNetwork();
      HttpOverrides.global = network;
    }
  });
  tearDown(() {
    UrlLauncherPlatform.instance = previousLauncher;
    if (rejectNetwork) HttpOverrides.global = previousNetwork;
    expect(
      launcher.calls,
      0,
      reason: 'Identifier review must never launch another app.',
    );
    if (rejectNetwork) {
      expect(network!.calls, 0, reason: 'Identifier review must stay offline.');
    }
  });

  testWidgets('camera UPC-E shows an explicit derived value without lookup', (
    tester,
  ) async {
    await tester.pumpWidget(
      _result('04252614', ScannedCodeFormat.upcE, ScanSource.camera),
    );
    await tester.pumpAndSettle();
    expect(find.text('UPC-E candidate'), findsOneWidget);
    expect(find.text('04252614'), findsOneWidget);
    expect(find.text('Derived UPC-A'), findsOneWidget);
    expect(find.text('042100005264'), findsOneWidget);
    expect(find.text('Check digit matches.'), findsOneWidget);
    _expectUnavailable(isbn: false);
  });

  testWidgets('gallery keeps a zero-prefixed EAN-13 as scanned', (
    tester,
  ) async {
    await tester.pumpWidget(
      _result('0012345678905', ScannedCodeFormat.ean13, ScanSource.gallery),
    );
    await tester.pumpAndSettle();
    expect(find.text('EAN-13 candidate'), findsOneWidget);
    expect(find.text('0012345678905'), findsOneWidget);
    expect(find.text('012345678905'), findsNothing);
    expect(find.text('Derived UPC-A'), findsNothing);
    _expectUnavailable(isbn: false);
  });

  testWidgets(
    'read-only share view interprets labeled ISBN without an app-link action',
    (tester) async {
      await tester.pumpWidget(
        DaliQrShareExtensionApp(
          secureQrService: _service(),
          codes: const [
            ScannedCode(
              value: 'ISBN-10: 0-8044-2957-x',
              format: ScannedCodeFormat.qrCode,
              source: ScanSource.sharedImage,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ISBN-10 candidate'), findsOneWidget);
      expect(find.text('ISBN-10: 0-8044-2957-x'), findsOneWidget);
      expect(find.text('Equivalent ISBN-13'), findsOneWidget);
      expect(find.text('9780804429573'), findsOneWidget);
      expect(find.text('Content comparison code'), findsOneWidget);
      expect(find.text('Link review'), findsNothing);
      _expectUnavailable(isbn: true);
    },
  );

  for (final saved in [false, true]) {
    testWidgets(
      '${saved ? 'Saved' : 'history'} displays candidates without rewriting stored records',
      (tester) async {
        final repository = DriftQrHistoryRepository(
          HistoryDatabase.forTesting(NativeDatabase.memory()),
        );
        final now = DateTime.now().toUtc();
        final raw = saved ? 'ISBN: 0306406152' : '04252614';
        final format = saved
            ? ScannedCodeFormat.qrCode
            : ScannedCodeFormat.upcE;
        final source = saved
            ? QrActivitySource.manual
            : QrActivitySource.camera;
        await repository.save(
          QrHistoryItem(
            id: 'identifier',
            activityKind: saved
                ? QrActivityKind.created
                : QrActivityKind.scanned,
            payloadKind: QrPayloadKind.text,
            rawPayload: raw,
            displayHost: null,
            title: 'Identifier test',
            note: 'Keep this note',
            isInHistory: !saved,
            savedAtUtc: saved ? now : null,
            codeFormat: format,
            source: source,
            createdAtUtc: now,
          ),
        );
        final controller = HistoryController(repository, _HistorySettings());
        await controller.initialize();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: saved
                ? SavedPage(controller: controller)
                : HistoryPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Identifier test'));
        await tester.pumpAndSettle();
        expect(find.text('Identifier check'), findsOneWidget);
        expect(find.text('Check digit matches.'), findsOneWidget);
        _expectUnavailable(isbn: saved);
        final stored = (await tester.runAsync(
          () => repository.watchRecent().first,
        ))!.single;
        expect(stored.rawPayload, raw);
        expect(stored.codeFormat, format);
        expect(stored.source, source);
        expect(stored.title, 'Identifier test');
        expect(stored.note, 'Keep this note');
        expect(stored.isInHistory, !saved);
        expect(stored.savedAtUtc != null, saved);
      },
    );
  }

  testWidgets('invalid check digits do not invent a repaired identifier', (
    tester,
  ) async {
    await tester.pumpWidget(
      _result('9780306406158', ScannedCodeFormat.ean13, ScanSource.camera),
    );
    await tester.pumpAndSettle();
    expect(find.text('Check digit does not match.'), findsOneWidget);
    expect(find.text('9780306406158'), findsOneWidget);
    expect(find.text('9780306406157'), findsNothing);
    expect(find.text('Equivalent ISBN-13'), findsNothing);
    _expectUnavailable(isbn: true);
  });

  testWidgets('bare numeric text stays unclassified', (tester) async {
    await tester.pumpWidget(
      _result('0306406152', ScannedCodeFormat.qrCode, ScanSource.gallery),
    );
    await tester.pumpAndSettle();
    expect(find.text('Identifier check'), findsNothing);
    expect(find.text('ISBN-10 candidate'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Open'), findsNothing);
  });

  testWidgets(
    'identifier details wrap at large text size on a narrow display',
    (tester) async {
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
          home: Scaffold(
            body: ScannedCodeResultView(
              code: const ScannedCode(
                value: '04252614',
                format: ScannedCodeFormat.upcE,
                source: ScanSource.gallery,
              ),
              secureQrService: _service(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Derived UPC-A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _result(String value, ScannedCodeFormat format, ScanSource source) =>
    MaterialApp(
      home: Scaffold(
        body: ScannedCodeResultView(
          code: ScannedCode(value: value, format: format, source: source),
          secureQrService: _service(),
        ),
      ),
    );

void _expectUnavailable({required bool isbn}) {
  expect(
    find.text(
      isbn
          ? 'Online book details are unavailable.'
          : 'Online product details are unavailable.',
    ),
    findsOneWidget,
  );
  expect(
    find.textContaining('does not confirm an assigned product or book'),
    findsOneWidget,
  );
  expect(find.widgetWithText(FilledButton, 'Open'), findsNothing);
  expect(find.text('Look up product'), findsNothing);
  expect(find.text('Look up book'), findsNothing);
}

final class _NoLaunch extends UrlLauncherPlatform {
  int calls = 0;
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls++;
    return false;
  }
}

final class _NoNetwork extends HttpOverrides {
  int calls = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    calls++;
    throw StateError('Unexpected network access');
  }
}

final class _HistorySettings implements HistorySettingsStore {
  @override
  Future<bool> historyEnabled() async => true;
  @override
  Future<void> setHistoryEnabled(bool enabled) async {}
}
