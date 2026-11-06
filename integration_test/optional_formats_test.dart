import 'dart:convert';
import 'dart:io';

import 'package:dali_qr/features/scan/data/code_image_analyzer.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import 'optional_format_data.g.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final fixture
      in (jsonDecode(optionalFormatFixturesJson) as List)
          .cast<Map<String, dynamic>>()) {
    testWidgets('production 2D image decode: ${fixture['id']}', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final format = BarcodeFormat.values.byName(fixture['format'] as String);
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/dali_candidate_${fixture['id']}.png',
      );
      final controller = MobileScannerController(
        autoStart: false,
        formats: [format],
      );
      try {
        await file.writeAsBytes(base64Decode(fixture['pngBase64'] as String));
        final timer = Stopwatch()..start();
        final result = await NativeCodeImageAnalyzer(
          controller,
        ).analyze(file.path, source: ScanSource.gallery);
        timer.stop();
        final actual = result.codes
            .map(
              (code) => {'format': code.format.storageKey, 'value': code.value},
            )
            .toList();
        debugPrint(
          'UNIVERSAL_2D_QA ${jsonEncode({'fixture': fixture['id'], 'elapsedMs': timer.elapsedMilliseconds, 'results': actual})}',
        );
        expect(actual, [
          {'format': fixture['format'], 'value': fixture['value']},
        ]);
      } finally {
        await controller.dispose();
        if (await file.exists()) await file.delete();
      }
    });
  }
}
