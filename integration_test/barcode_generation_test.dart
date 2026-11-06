import 'dart:convert';
import 'dart:io';

import 'package:dali_qr/features/create/application/barcode_generator.dart';
import 'package:dali_qr/features/scan/data/code_image_analyzer.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import 'barcode_fixture_data.g.dart';
import 'optional_format_data.g.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final fixtures = <Map<String, dynamic>>[
    ...(jsonDecode(scannerFixturesJson) as List).cast<Map<String, dynamic>>(),
    ...(jsonDecode(optionalFormatFixturesJson) as List)
        .cast<Map<String, dynamic>>(),
    for (final format in ['dataMatrix', 'pdf417', 'aztec'])
      {
        'id': '${format}_unicode',
        'format': format,
        'value': format == 'dataMatrix'
            ? '  Café Grüße\nend  '
            : '  Café 中文 😀\nend  ',
      },
  ];
  for (final f in fixtures) {
    final format = ScannedCodeFormat.fromStorageKey(
      (f['symbolFormat'] ?? f['format']) as String,
    );
    if (format == ScannedCodeFormat.qrCode) continue;
    testWidgets('generate and scan ${f['id']}', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final value = (f['encodedValue'] ?? f['value']) as String;
      final code = await BarcodeGenerator.generate(value, format);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/dali_generated_${f['id']}.png');
      final controller = MobileScannerController(autoStart: false);
      try {
        await file.writeAsBytes(code.png);
        final result = await NativeCodeImageAnalyzer(
          controller,
        ).analyze(file.path, source: ScanSource.gallery);
        final actual = result.codes
            .map((c) => {'format': c.format.storageKey, 'value': c.value})
            .toList();
        final expected =
            (f['expectedNativeResults'] as Map?)?[Platform.isIOS
                ? 'ios'
                : 'android'] ??
            [
              {'format': format.storageKey, 'value': value},
            ];
        debugPrint(
          'BARCODE_GENERATION_QA ${jsonEncode({'fixture': f['id'], 'width': code.width, 'height': code.height, 'results': actual})}',
        );
        expect(actual, isNotEmpty);
        expect(
          actual.every(
            (a) => (expected as List).any(
              (e) => e['format'] == a['format'] && e['value'] == a['value'],
            ),
          ),
          isTrue,
        );
      } finally {
        await controller.dispose();
        if (await file.exists()) await file.delete();
      }
    });
  }
}
