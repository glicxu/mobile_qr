import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dali_qr/main.dart';
import 'package:dali_qr/features/scan/application/inbound_image_share.dart';
import 'package:dali_qr/features/monetization/application/customization_entitlement.dart';
import 'package:dali_qr/features/history/application/history_controller.dart';
import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:dali_qr/features/scan/data/code_image_analyzer.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:dali_qr/features/scan/presentation/qr_scanner_page.dart';
import 'package:dali_qr/features/scan/presentation/share_extension_result_app.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

SecureQrService _service() => SecureQrService(PublicSuffixList.parse('com'));

void main() {
  final fixtures =
      (jsonDecode(
                File(
                  'test/fixtures/optional_formats/manifest.json',
                ).readAsStringSync(),
              )
              as Map)['fixtures']
          as List;
  registerUniversalScannerFlows([
    for (final fixture in fixtures.where(
      (value) => (value['id'] as String).endsWith('_short'),
    ))
      {
        ...(fixture as Map<String, dynamic>),
        'pngBase64': base64Encode(
          File(
            'test/fixtures/optional_formats/${fixture['id']}.png',
          ).readAsBytesSync(),
        ),
      },
  ], mockNative: true);
  registerScannerEdgeFlows();
}

/// Native runs use actual image decoding and SQLite. The image picker is
/// replaced with a selected local path; these are app-entrypoint tests.
void registerUniversalScannerFlows(
  List<Map<String, dynamic>> fixtures, {
  bool mockNative = false,
}) {
  for (final fixture in fixtures) {
    for (final source in [ScanSource.gallery, ScanSource.sharedImage]) {
      testWidgets(
        '${fixture['id']}: ${source.name} read, copy, history and Saved',
        (tester) async {
          final previousPlatform = MobileScannerPlatform.instance;
          if (mockNative) MobileScannerPlatform.instance = _EmptyScanner();
          final previousLauncher = UrlLauncherPlatform.instance;
          final launcher = _NoLaunch();
          UrlLauncherPlatform.instance = launcher;
          final scanner = MobileScannerController(autoStart: false);
          final setup = (await tester.runAsync(() async {
            final directory = await Directory.systemTemp.createTemp(
              'dali_universal_',
            );
            final file = await File(
              '${directory.path}/fixture.png',
            ).writeAsBytes(base64Decode(fixture['pngBase64'] as String));
            final repository = DriftQrHistoryRepository(
              HistoryDatabase.forTesting(NativeDatabase.memory()),
            );
            final history = HistoryController(repository, _Settings());
            await history.initialize();
            return (directory, file, repository, history);
          }))!;
          final (directory, file, repository, history) = setup;
          String? copied;
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(SystemChannels.platform, (
            call,
          ) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
          addTearDown(() async {
            messenger.setMockMethodCallHandler(SystemChannels.platform, null);
            await scanner.dispose();
            history.dispose();
            MobileScannerPlatform.instance = previousPlatform;
            UrlLauncherPlatform.instance = previousLauncher;
            if (await file.exists()) await file.delete();
            await directory.delete();
          });
          QrHistoryItem? stored;
          var writes = 0;
          ImageSource? chosenSource;
          final watch = Stopwatch()..start();
          await tester.pumpWidget(
            MaterialApp(
              home: QrScannerPage(
                scannerController: scanner,
                secureQrService: _service(),
                sharedImagePath: source == ScanSource.sharedImage
                    ? file.path
                    : null,
                imagePathPicker: (value) async {
                  chosenSource = value;
                  return file.path;
                },
                onScanned:
                    ({
                      required payload,
                      verificationCode,
                      registrableDomain,
                      qrPngBytes,
                      required codeFormat,
                      required source,
                    }) async {
                      writes++;
                      await history.recordScanned(
                        payload: payload,
                        verificationCode: verificationCode,
                        registrableDomain: registrableDomain,
                        qrPngBytes: qrPngBytes,
                        codeFormat: codeFormat,
                        source: source,
                      );
                      final row = await repository.findMostRecentByPayload(
                        payload,
                        codeFormat: codeFormat,
                      );
                      stored = row;
                    },
              ),
            ),
          );
          if (source != ScanSource.sharedImage) {
            await tester.tap(find.text('Choose image'));
          }
          await waitForScanner(
            tester,
            () =>
                stored != null &&
                find.byType(ScannedCodeResultView).evaluate().isNotEmpty,
          );
          watch.stop();
          final code = tester
              .widget<ScannedCodeResultView>(find.byType(ScannedCodeResultView))
              .code;
          final expected = fixture['expectedNativeResults'] == null
              ? [
                  {'format': fixture['format'], 'value': fixture['value']},
                ]
              : (fixture['expectedNativeResults'] as Map)[Platform.isIOS
                        ? 'ios'
                        : 'android']
                    as List;
          expect(
            expected,
            contains(
              equals({'format': code.format.storageKey, 'value': code.value}),
            ),
          );
          expect(code.source, source);
          expect(stored!.rawPayload, code.value);
          expect(stored!.codeFormat, code.format);
          expect(stored!.source.name, source.name);
          expect(find.text('Save to Saved'), findsNothing);
          expect(find.text('Scan again'), findsNothing);
          expect(stored!.savedAtUtc, isNull);
          expect(writes, 1);
          if (source != ScanSource.sharedImage) {
            expect(chosenSource, ImageSource.gallery);
          }
          if (code.format != ScannedCodeFormat.qrCode) {
            expect(stored!.verificationCode, isNull);
            expect(stored!.qrPngBytes, isNull);
            expect(find.text('Content comparison code'), findsNothing);
          }
          await tester.scrollUntilVisible(
            find.text('Details'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Details'));
          await tester.pumpAndSettle();
          final copy = find.widgetWithText(OutlinedButton, 'Copy contents');
          await tester.ensureVisible(copy);
          await tester.pumpAndSettle();
          await tester.tap(copy);
          await tester.pumpAndSettle();
          expect(copied, code.value);
          expect(launcher.calls, 0);
          expect(
            await tester.runAsync(file.exists),
            source == ScanSource.gallery,
            reason:
                'Owned shared copies are removed; library originals are retained.',
          );
          debugPrint(
            'UNIVERSAL_FLOW_QA ${jsonEncode({'fixture': fixture['id'], 'format': code.format.storageKey, 'value': code.value, 'source': source.name, 'elapsedMs': watch.elapsedMilliseconds, 'copied': true, 'historyWrites': writes})}',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}

void registerScannerEdgeFlows() {
  testWidgets(
    'a late shared-image result cannot replace a newer share; both copies are deleted',
    (tester) async {
      final previous = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = _EmptyScanner();
      final scanner = MobileScannerController(autoStart: false);
      final (directory, first, second) = (await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'dali_share_race_',
        );
        final first = await File(
          '${directory.path}/first',
        ).writeAsString('fixture');
        final second = await File(
          '${directory.path}/second',
        ).writeAsString('fixture');
        return (directory, first, second);
      }))!;
      final analyzer = _ControlledAnalyzer();
      final writes = <String>[];
      addTearDown(() async {
        await scanner.dispose();
        MobileScannerPlatform.instance = previous;
        await directory.delete();
      });
      Widget app(String path) => MaterialApp(
        home: QrScannerPage(
          scannerController: scanner,
          secureQrService: _service(),
          sharedImagePath: path,
          imageAnalyzer: analyzer,
          onScanned:
              ({
                required payload,
                verificationCode,
                registrableDomain,
                qrPngBytes,
                required codeFormat,
                required source,
              }) async {
                writes.add(payload);
              },
        ),
      );
      await tester.pumpWidget(app(first.path));
      await waitForScanner(
        tester,
        () => analyzer.pending.containsKey(first.path),
      );
      await tester.pumpWidget(app(second.path));
      await waitForScanner(
        tester,
        () => analyzer.pending.containsKey(second.path),
      );
      analyzer.pending[first.path]!.complete(
        const CodeImageAnalysis([
          ScannedCode(
            value: 'old',
            format: ScannedCodeFormat.aztec,
            source: ScanSource.sharedImage,
          ),
        ]),
      );
      await tester.pump();
      expect(find.byType(ScannedCodeResultView), findsNothing);
      analyzer.pending[second.path]!.complete(
        const CodeImageAnalysis([
          ScannedCode(
            value: 'new',
            format: ScannedCodeFormat.pdf417,
            source: ScanSource.sharedImage,
          ),
        ]),
      );
      await waitForScanner(tester, () => writes.isNotEmpty);
      expect(writes, ['new']);
      expect(
        tester
            .widget<ScannedCodeResultView>(find.byType(ScannedCodeResultView))
            .code
            .value,
        'new',
      );
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 20 && (await first.exists() || await second.exists());
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(await first.exists(), false);
        expect(await second.exists(), false);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('iOS read-only share can show an independently decoded Aztec', (
    tester,
  ) async {
    await tester.pumpWidget(
      DaliQrShareExtensionApp(
        codes: const [],
        secureQrService: _service(),
        imageFallback: () async => const [
          ScannedCode(
            value: ' 00123 ',
            format: ScannedCodeFormat.aztec,
            source: ScanSource.sharedImage,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aztec · From shared image'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open'), findsNothing);
    expect(
      tester
          .widget<ScannedCodeResultView>(find.byType(ScannedCodeResultView))
          .code
          .value,
      ' 00123 ',
    );
  });
  testWidgets(
    'image chooser cancellation rearms and a failed camera pause does not block import',
    (tester) async {
      final previous = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = _EmptyScanner();
      final scanner = MobileScannerController(autoStart: true);
      final path = File(
        'test/fixtures/optional_formats/aztec_short.png',
      ).absolute.path;
      var picks = 0;
      var writes = 0;
      addTearDown(() async {
        await scanner.dispose();
        MobileScannerPlatform.instance = previous;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: QrScannerPage(
            scannerController: scanner,
            secureQrService: _service(),
            imagePathPicker: (_) async => ++picks == 1 ? null : path,
            onScanned:
                ({
                  required payload,
                  verificationCode,
                  registrableDomain,
                  qrPngBytes,
                  required codeFormat,
                  required source,
                }) async {
                  writes++;
                },
          ),
        ),
      );
      await tester.tap(find.text('Choose image'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      await tester.tap(find.text('Choose image'));
      await waitForScanner(tester, () => writes == 1);
      expect(
        tester
            .widget<ScannedCodeResultView>(find.byType(ScannedCodeResultView))
            .code
            .value,
        '  KEEP-00123  ',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'binary-only live results explain the limit without creating text or history',
    (tester) async {
      final previous = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = _EmptyScanner();
      final scanner = MobileScannerController(autoStart: false);
      addTearDown(() async {
        await scanner.dispose();
        MobileScannerPlatform.instance = previous;
      });
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: QrScannerPage(
            scannerController: scanner,
            secureQrService: _service(),
            onScanned:
                ({
                  required payload,
                  verificationCode,
                  registrableDomain,
                  qrPngBytes,
                  required codeFormat,
                  required source,
                }) async {
                  writes++;
                },
          ),
        ),
      );
      final capture = BarcodeCapture(
        barcodes: [
          Barcode(
            format: BarcodeFormat.dataMatrix,
            rawDecodedBytes: DecodedBarcodeBytes(
              bytes: Uint8List.fromList([0, 255, 0]),
            ),
          ),
        ],
      );
      final onDetect = tester
          .widget<MobileScanner>(find.byType(MobileScanner))
          .onDetect!;
      onDetect(capture);
      onDetect(capture);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('binary data without readable text'),
        findsOneWidget,
      );
      expect(writes, 0);
      expect(find.byType(ScannedCodeResultView), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('scanner controls and format help work at large text sizes', (
    tester,
  ) async {
    final previous = MobileScannerPlatform.instance;
    MobileScannerPlatform.instance = _EmptyScanner();
    final scanner = MobileScannerController(autoStart: false);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() async {
      await scanner.dispose();
      MobileScannerPlatform.instance = previous;
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2.5)),
          child: child!,
        ),
        home: QrScannerPage(
          scannerController: scanner,
          secureQrService: _service(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Choose image'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Choose image').hitTestable(), findsOneWidget);
    expect(find.text('Take photo'), findsNothing);
    await tester.tap(find.byTooltip('Supported formats'));
    await tester.pumpAndSettle();
    expect(find.text('Scan 13 code formats'), findsOneWidget);
    expect(find.textContaining('Data Matrix, PDF417, Aztec'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'scan results omit extra buttons and the Scan tab rearms the camera',
    (tester) async {
      final previous = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = _EmptyScanner();
      final history = (await tester.runAsync(() async {
        final value = HistoryController(
          DriftQrHistoryRepository(
            HistoryDatabase.forTesting(NativeDatabase.memory()),
          ),
          _Settings(enabled: false),
        );
        await value.initialize();
        return value;
      }))!;
      final entitlement = _TestEntitlement();
      addTearDown(() {
        history.dispose();
        entitlement.dispose();
        MobileScannerPlatform.instance = previous;
      });
      await tester.pumpWidget(
        DaliQrApp(
          secureQrService: _service(),
          historyController: history,
          customizationEntitlement: entitlement,
        ),
      );
      await tester.pumpAndSettle();
      final originalController = tester
          .widget<MobileScanner>(find.byType(MobileScanner))
          .controller;
      tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: ' 00123 ', format: BarcodeFormat.dataMatrix),
          ],
        ),
      );
      await waitForScanner(
        tester,
        () => find.byType(ScannedCodeResultView).evaluate().isNotEmpty,
      );
      expect(history.items, isEmpty);
      expect(find.text('Save to Saved'), findsNothing);
      expect(find.text('Scan again'), findsNothing);
      expect(history.savedItems, isEmpty);
      await tester.tap(find.text('Scan').last);
      await waitForScanner(
        tester,
        () =>
            find.byType(MobileScanner).evaluate().isNotEmpty &&
            tester
                .widget<MobileScanner>(find.byType(MobileScanner))
                .controller!
                .value
                .isRunning,
      );
      expect(
        tester.widget<MobileScanner>(find.byType(MobileScanner)).controller,
        same(originalController),
      );
      tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: 'FIDO:/123456', format: BarcodeFormat.qrCode),
          ],
        ),
      );
      await waitForScanner(
        tester,
        () => find.byType(ScannedCodeResultView).evaluate().isNotEmpty,
      );
      expect(find.text('Save to Saved'), findsNothing);
      expect(history.savedItems, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'a cold shared-image launch waits for the initial intent and never starts the camera',
    (tester) async {
      final previous = MobileScannerPlatform.instance;
      final platform = _EmptyScanner();
      MobileScannerPlatform.instance = platform;
      final (directory, file, history) = (await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'dali_cold_share_',
        );
        final file = await File(
          'test/fixtures/optional_formats/aztec_short.png',
        ).copy('${directory.path}/shared.png');
        final history = HistoryController(
          DriftQrHistoryRepository(
            HistoryDatabase.forTesting(NativeDatabase.memory()),
          ),
          _Settings(enabled: false),
        );
        await history.initialize();
        return (directory, file, history);
      }))!;
      final entitlement = _TestEntitlement();
      final inbound = _DelayedShare();
      addTearDown(() async {
        history.dispose();
        entitlement.dispose();
        MobileScannerPlatform.instance = previous;
        if (await file.exists()) await file.delete();
        await directory.delete();
      });
      await tester.pumpWidget(
        DaliQrApp(
          secureQrService: _service(),
          historyController: history,
          customizationEntitlement: entitlement,
          inboundImageShare: inbound,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(MobileScanner), findsNothing);
      expect(platform.starts, 0);
      inbound.initial.complete(file.path);
      await waitForScanner(
        tester,
        () => find.byType(ScannedCodeResultView).evaluate().isNotEmpty,
      );
      final code = tester
          .widget<ScannedCodeResultView>(find.byType(ScannedCodeResultView))
          .code;
      expect(code.format, ScannedCodeFormat.aztec);
      expect(code.value, '  KEEP-00123  ');
      expect(code.source, ScanSource.sharedImage);
      expect(platform.starts, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'the Android image-only launch hint keeps the camera off even without an initial image',
    (tester) async {
      final previous = MobileScannerPlatform.instance;
      final platform = _EmptyScanner();
      MobileScannerPlatform.instance = platform;
      final history = (await tester.runAsync(() async {
        final value = HistoryController(
          DriftQrHistoryRepository(
            HistoryDatabase.forTesting(NativeDatabase.memory()),
          ),
          _Settings(enabled: false),
        );
        await value.initialize();
        return value;
      }))!;
      final entitlement = _TestEntitlement();
      addTearDown(() {
        history.dispose();
        entitlement.dispose();
        MobileScannerPlatform.instance = previous;
      });
      await tester.pumpWidget(
        DaliQrApp(
          initialSharedLaunch: true,
          inboundImageShare: _NoShare(),
          secureQrService: _service(),
          historyController: history,
          customizationEntitlement: entitlement,
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.starts, 0);
      expect(find.text('Start camera'), findsOneWidget);
      expect(
        tester
            .widget<MobileScanner>(find.byType(MobileScanner))
            .controller!
            .autoStart,
        false,
      );
      await tester.tap(find.text('Start camera'));
      await waitForScanner(tester, () => platform.starts == 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

Future<void> waitForScanner(WidgetTester tester, bool Function() ready) async {
  final watch = Stopwatch()..start();
  while (!ready() && watch.elapsed < const Duration(seconds: 20)) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
  }
  expect(
    ready(),
    true,
    reason: 'The image flow did not finish within 20 seconds.',
  );
  await tester.pump();
}

final class _Settings implements HistorySettingsStore {
  _Settings({this.enabled = true});
  final bool enabled;
  @override
  Future<bool> historyEnabled() async => enabled;
  @override
  Future<void> setHistoryEnabled(bool enabled) async {}
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

final class _EmptyScanner extends MobileScannerPlatform {
  int starts = 0;
  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const [],
  }) async => const BarcodeCapture(barcodes: []);
  @override
  Future<void> dispose() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {
    throw StateError('Camera already stopped');
  }

  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
}

final class _ControlledAnalyzer implements CodeImageAnalyzer {
  final pending = <String, Completer<CodeImageAnalysis>>{};
  @override
  Future<CodeImageAnalysis> analyze(
    String path, {
    required ScanSource source,
  }) => (pending[path] = Completer<CodeImageAnalysis>()).future;
}

final class _TestEntitlement extends CustomizationEntitlement {
  @override
  bool get isBusy => false;
  @override
  bool get isStoreAvailable => false;
  @override
  bool get isUnlocked => false;
  @override
  String? get message => null;
  @override
  String? get price => null;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> purchase() async {}
  @override
  Future<void> restore() async {}
}

final class _DelayedShare implements InboundImageShareSource {
  final initial = Completer<String>();
  @override
  Future<void> start(SharedImageHandler onSharedImage) async {
    onSharedImage(await initial.future);
  }

  @override
  void dispose() {}
}

final class _NoShare implements InboundImageShareSource {
  @override
  Future<void> start(SharedImageHandler onSharedImage) async {}
  @override
  void dispose() {}
}
