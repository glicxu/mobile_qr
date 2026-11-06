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

const _url = 'http://trusted.example@evil.example:8080/account';

void main() => registerLinkReviewTests();

void registerLinkReviewTests({bool rejectNetwork = true}) {
  final launches = <String>[];
  late UrlLauncherPlatform previousLauncher;
  HttpOverrides? previousOverrides;
  setUp(() {
    if (rejectNetwork) {
      previousOverrides = HttpOverrides.current;
      HttpOverrides.global = _NoNetwork();
    }
    launches.clear();
    previousLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _RecordingLauncher(launches);
  });
  tearDown(() {
    if (rejectNetwork) HttpOverrides.global = previousOverrides;
    UrlLauncherPlatform.instance = previousLauncher;
  });

  for (final source in [ScanSource.camera, ScanSource.gallery]) {
    testWidgets(
      '${source.name} result reviews the real destination before launch',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ScannedCodeResultView(
                code: ScannedCode(
                  value: _url,
                  format: ScannedCodeFormat.code128,
                  source: source,
                ),
                secureQrService: SecureQrService(
                  PublicSuffixList.parse('example'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Host: evil.example'), findsOneWidget);
        expect(find.text('Scheme: http'), findsOneWidget);
        expect(find.textContaining('Text before @'), findsOneWidget);
        expect(launches, isEmpty);
        await _open(tester);
        expect(find.text('Review destination'), findsNothing);
        expect(launches, hasLength(1));
        expect(launches.single, _url);
      },
    );
  }

  for (final saved in [false, true]) {
    testWidgets(
      '${saved ? 'Saved' : 'history'} opens directly from the reviewed result',
      (tester) async {
        final repository = DriftQrHistoryRepository(
          HistoryDatabase.forTesting(NativeDatabase.memory()),
        );
        final now = DateTime.now().toUtc();
        await repository.save(
          QrHistoryItem(
            id: 'review',
            activityKind: QrActivityKind.scanned,
            payloadKind: QrPayloadKind.url,
            rawPayload: _url,
            displayHost: 'evil.example',
            title: 'Review test',
            codeFormat: ScannedCodeFormat.code128,
            source: QrActivitySource.camera,
            createdAtUtc: now,
            savedAtUtc: saved ? now : null,
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
        await tester.tap(find.text('Review test'));
        await tester.pumpAndSettle();
        expect(find.text('Host: evil.example'), findsOneWidget);
        expect(launches, isEmpty);
        await _open(tester);
        expect(find.text('Review destination'), findsNothing);
        expect(launches, hasLength(1));
        expect(launches.single, _url);
      },
    );
  }

  testWidgets(
    'iOS share view remains read-only and shows destination warnings',
    (tester) async {
      await tester.pumpWidget(
        DaliQrShareExtensionApp(
          secureQrService: SecureQrService(PublicSuffixList.parse('example')),
          codes: const [
            ScannedCode(
              value: _url,
              format: ScannedCodeFormat.code128,
              source: ScanSource.sharedImage,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Host: evil.example'), findsOneWidget);
      expect(find.text('Scheme: http'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Open'), findsNothing);
      expect(find.text('Review destination'), findsNothing);
      expect(launches, isEmpty);
    },
  );

  testWidgets('review and open stay usable at large text size', (tester) async {
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
              value: _url,
              format: ScannedCodeFormat.code128,
              source: ScanSource.gallery,
            ),
            secureQrService: SecureQrService(PublicSuffixList.parse('example')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);
    expect(tester.takeException(), isNull);
    expect(launches, hasLength(1));
  });
}

Future<void> _open(WidgetTester tester) async {
  final open = find.widgetWithText(FilledButton, 'Open');
  for (var attempt = 0; attempt < 20 && open.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(open);
  await tester.pumpAndSettle();
  await tester.tap(open);
  await tester.pumpAndSettle();
}

final class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Unexpected network request');
}

final class _RecordingLauncher extends UrlLauncherPlatform {
  _RecordingLauncher(this.launches);
  final List<String> launches;
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    expect(options.mode, PreferredLaunchMode.externalApplication);
    launches.add(url);
    return true;
  }
}

final class _HistorySettings implements HistorySettingsStore {
  @override
  Future<bool> historyEnabled() async => true;
  @override
  Future<void> setHistoryEnabled(bool enabled) async {}
}
