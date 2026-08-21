import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:dali_qr/features/scan/presentation/qr_payload_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  });
}
