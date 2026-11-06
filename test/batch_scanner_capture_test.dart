import 'dart:async';

import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:dali_qr/features/scan/presentation/qr_scanner_page.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  for (final pauseFails in [false, true]) {
    testWidgets(
      'capture returns once without automatic history when pause fails=$pauseFails',
      (tester) async {
        final previous = MobileScannerPlatform.instance;
        final platform = _Scanner();
        MobileScannerPlatform.instance = platform;
        addTearDown(() async {
          await platform.captures.close();
          MobileScannerPlatform.instance = previous;
        });
        final selected = <ScannedCode>[];
        var historyWrites = 0;
        var batchOpens = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: QrScannerPage(
              secureQrService: SecureQrService(PublicSuffixList.parse('com')),
              onCodeSelected: selected.add,
              onBatchRequested: () async {
                batchOpens++;
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
                    historyWrites++;
                  },
            ),
          ),
        );
        await tester.pumpAndSettle();
        const capture = BarcodeCapture(
          barcodes: [
            Barcode(rawValue: ' 00123 ', format: BarcodeFormat.code128),
          ],
        );
        for (var i = 0; i < 20; i++) {
          platform.captures.add(capture);
        }
        await tester.pump();
        expect(selected, isEmpty);
        await tester.tap(find.byTooltip('Batch sessions'));
        await tester.pump();
        expect(batchOpens, 0);
        if (pauseFails) {
          platform.paused.completeError(StateError('Camera already stopped'));
        } else {
          platform.paused.complete();
        }
        await tester.pumpAndSettle();
        for (var i = 0; i < 20; i++) {
          platform.captures.add(capture);
        }
        await tester.pumpAndSettle();
        expect(selected, hasLength(1));
        expect(selected.single.value, ' 00123 ');
        expect(selected.single.format, ScannedCodeFormat.code128);
        expect(selected.single.source, ScanSource.camera);
        expect(historyWrites, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final class _Scanner extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  final paused = Completer<void>();
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.off,
        size: Size(640, 480),
      );
  @override
  Future<void> pause() => paused.future;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
}
