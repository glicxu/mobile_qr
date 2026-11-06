import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dali_qr/features/scan/data/mobile_scanner_code_adapter.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import 'barcode_fixture_data.g.dart';

Future<List<ScannedCode>> analyzeFixture(Uint8List png, String name) async {
  final directory = await Directory(
    '${(await getTemporaryDirectory()).path}/scanner-qa',
  ).create(recursive: true);
  final file = File('${directory.path}/$name.png');
  final controller = MobileScannerController(autoStart: false);
  addTearDown(() async {
    await controller.dispose();
    if (await file.exists()) await file.delete();
  });
  await file.writeAsBytes(png);
  // Match the app's still-image call, including domain allowlist filtering.
  final capture = await controller.analyzeImage(file.path);
  return capture == null
      ? const []
      : MobileScannerCodeAdapter.extract(capture, source: ScanSource.gallery);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final fixtures = (jsonDecode(scannerFixturesJson) as List)
      .cast<Map<String, dynamic>>();
  for (final fixture in fixtures) {
    testWidgets('native image decode: ${fixture['id']}', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final codes = await analyzeFixture(
        base64Decode(fixture['pngBase64'] as String),
        fixture['id'] as String,
      );
      expect(codes, hasLength(1));
      final actual = {
        'format': codes.single.format.storageKey,
        'value': codes.single.value,
      };
      final platform = Platform.isIOS ? 'ios' : 'android';
      final expected = fixture['expectedNativeResults'][platform] as List;
      expect(
        expected,
        contains(equals(actual)),
        reason: 'Unexpected native representation',
      );
      expect(codes.single.source, ScanSource.gallery);
      debugPrint(
        'SCANNER_QA ${jsonEncode({'fixture': fixture['id'], ...actual})}',
      );
    });
  }

  testWidgets('blank image has no results', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final blank = img.Image(width: 400, height: 400);
    img.fill(blank, color: img.ColorRgb8(255, 255, 255));
    expect(await analyzeFixture(img.encodePng(blank), 'blank'), isEmpty);
  });

  testWidgets('multiple symbols are sorted and duplicate values collapse', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final qr = fixtures.firstWhere((fixture) => fixture['id'] == 'qr_url');
    final barcode = fixtures.firstWhere(
      (fixture) => fixture['id'] == 'code128_short',
    );
    final qrImage = img.decodePng(base64Decode(qr['pngBase64'] as String))!;
    final barcodeImage = img.decodePng(
      base64Decode(barcode['pngBase64'] as String),
    )!;
    final canvas = img.Image(
      width: qrImage.width * 2 + barcodeImage.width + 160,
      height:
          (qrImage.height > barcodeImage.height
              ? qrImage.height
              : barcodeImage.height) +
          80,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, barcodeImage, dstX: 20, dstY: 20);
    img.compositeImage(
      canvas,
      qrImage,
      dstX: barcodeImage.width + 60,
      dstY: 20,
    );
    img.compositeImage(
      canvas,
      qrImage,
      dstX: barcodeImage.width + qrImage.width + 100,
      dstY: 20,
    );
    final codes = await analyzeFixture(img.encodePng(canvas), 'multiple');
    expect(codes.map((code) => code.format), [
      ScannedCodeFormat.qrCode,
      ScannedCodeFormat.code128,
    ]);
    expect(codes.map((code) => code.value), [
      qr['encodedValue'],
      barcode['encodedValue'],
    ]);
  });
}
