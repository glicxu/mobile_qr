import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:dali_qr/features/scan/presentation/qr_payload_action.dart';
import 'package:dali_qr/features/scan/presentation/qr_scanner_page.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'malformed Wi-Fi codes remain masked even after expanding Details',
    (tester) async {
      const raw = 'WIFI:S:Guest;P:private-password;P:other-password;;';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannedCodeResultView(
              code: const ScannedCode(
                value: raw,
                format: ScannedCodeFormat.qrCode,
                source: ScanSource.camera,
              ),
              secureQrService: SecureQrService(PublicSuffixList.parse('com')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('private-password'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Details'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('private-password'), findsNothing);
      expect(find.text('Wi-Fi credentials hidden.'), findsOneWidget);
      await tester.ensureVisible(find.text('Reveal Wi-Fi code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reveal Wi-Fi code'));
      await tester.pumpAndSettle();
      expect(find.text(raw), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Wi-Fi password is masked until explicitly revealed', (
    tester,
  ) async {
    final payload = const QrPayloadClassifier().classify(
      'WIFI:T:WPA;S:Guest;P:top-secret;;',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: QrSensitiveDetail(payload: payload)),
      ),
    );

    expect(find.text('Password: ********'), findsOneWidget);
    expect(find.textContaining('top-secret'), findsNothing);

    await tester.tap(find.byTooltip('Reveal Password'));
    await tester.pump();

    expect(find.text('Password: top-secret'), findsOneWidget);
    expect(find.byTooltip('Hide Password'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrSensitiveDetail(
            payload: const QrPayloadClassifier().classify(
              'WIFI:T:WPA;S:Other;P:new-secret;;',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Password: ********'), findsOneWidget);
    expect(find.textContaining('new-secret'), findsNothing);
  });
}
