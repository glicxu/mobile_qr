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
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

SecureQrService _service() => SecureQrService(PublicSuffixList.parse('com'));

const _raw = 'https://example.com/01/09520123456788/10/ABC%2F123?17=261200';
void main() => registerGs1UiTests();
void registerGs1UiTests({bool rejectNetwork = true}) {
  late UrlLauncherPlatform previousLauncher;
  late _NoLaunch launcher;
  var expectedLaunches = 0;
  _NoNetwork? network;
  HttpOverrides? previousNetwork;
  setUp(() {
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = _NoLaunch();
    expectedLaunches = 0;
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
      expectedLaunches,
      reason: 'Only an explicit Open action may launch another app.',
    );
    if (rejectNetwork) {
      expect(network!.calls, 0, reason: 'Identifier review must stay offline.');
    }
  });

  for (final source in [ScanSource.camera, ScanSource.gallery]) {
    testWidgets(
      '${source.name} GS1 parsing stays local and Open launches the reviewed URL',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ScannedCodeResultView(
                code: ScannedCode(
                  value: _raw,
                  format: ScannedCodeFormat.qrCode,
                  source: source,
                ),
                secureQrService: _service(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('GS1 Digital Link fields'), findsOneWidget);
        expect(find.text('ABC/123'), findsOneWidget);
        expect(launcher.calls, 0);
        final open = find.widgetWithText(FilledButton, 'Open');
        await tester.scrollUntilVisible(
          open,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(open);
        await tester.pumpAndSettle();
        expectedLaunches = 1;
        expect(launcher.calls, 1);
        expect(launcher.lastUrl, _raw);
        expect(find.text('Open destination'), findsNothing);
      },
    );
  }
  testWidgets('read-only share view preserves the original GS1 URI', (
    tester,
  ) async {
    await tester.pumpWidget(
      DaliQrShareExtensionApp(
        codes: const [
          ScannedCode(
            value: _raw,
            format: ScannedCodeFormat.qrCode,
            source: ScanSource.sharedImage,
          ),
        ],
        secureQrService: _service(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('GS1 Digital Link fields'), findsOneWidget);
    expect(find.text('Online resolution is unavailable.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open'), findsNothing);
    expect(find.text('ABC/123'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Details'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text(_raw), findsWidgets);
  });
  for (final saved in [false, true]) {
    testWidgets(
      '${saved ? 'Saved' : 'history'} displays candidates without rewriting stored records',
      (tester) async {
        final repository = DriftQrHistoryRepository(
          HistoryDatabase.forTesting(NativeDatabase.memory()),
        );
        final now = DateTime.now().toUtc();
        const raw = _raw;
        const format = ScannedCodeFormat.qrCode;
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
        expect(find.text('GS1 Digital Link fields'), findsOneWidget);
        expect(find.text('ABC/123'), findsOneWidget);
        expect(find.text('Link review'), findsOneWidget);
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
}

final class _NoLaunch extends UrlLauncherPlatform {
  int calls = 0;
  String? lastUrl;
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls++;
    lastUrl = url;
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
