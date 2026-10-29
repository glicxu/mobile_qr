import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:dali_qr/features/scan/presentation/qr_scanner_page.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scan result shows only relevant result actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScannedCodeResultView(
            code: const ScannedCode(
              value: 'https://example.com',
              format: ScannedCodeFormat.qrCode,
              source: ScanSource.camera,
            ),
            secureQrService: SecureQrService(PublicSuffixList.parse('com')),
          ),
        ),
      ),
    );

    expect(find.text('Save code'), findsNothing);
    expect(find.text('Scan again'), findsNothing);
    expect(find.text('Open').hitTestable(), findsOneWidget);
    expect(find.text('Website'), findsNothing);
    expect(find.text('Raw content'), findsNothing);
    expect(find.text('Copy contents'), findsNothing);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Raw content'), findsOneWidget);
    expect(find.text('Copy contents'), findsOneWidget);
  });
}
