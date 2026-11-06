import 'dart:convert';
import 'dart:io';

import 'package:dali_qr/features/create/domain/structured_qr_payload.dart';
import 'package:dali_qr/features/create/data/dart_qr_encoder.dart';
import 'package:dali_qr/features/create/data/qr_png_renderer.dart';
import 'package:dali_qr/features/scan/data/code_image_analyzer.dart';
import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:dali_qr/features/scan/domain/authenticator_payload.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dali_qr/features/scan/application/qr_payload_router.dart';
import 'package:dali_qr/features/scan/presentation/qr_payload_action.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('authenticator review cancels locally and handles provider absence', (
    tester,
  ) async {
    const raw =
        'otpauth://totp/DaliQA:qa%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=DaliQA';
    final payload = const QrPayloadClassifier().classify(raw);
    final available = await canLaunchUrl(
      AuthenticatorPayload.tryParse(raw)!.handlerProbe,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => routeQrPayload(context, payload),
              child: const Text('Review setup'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Review setup'));
    await tester.pumpAndSettle();
    expect(find.textContaining('JBSWY3DPEHPK3PXP'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    if (!available) {
      expect(await const QrPayloadRouter().route(payload), isFalse);
    }
    debugPrint(
      'STRUCTURED_QR_QA ${jsonEncode({'type': 'authenticator', 'reviewCancelled': true, 'providerAvailable': available, 'providerLaunched': false, 'result': 'passed'})}',
    );
  });
  final drafts = [
    const StructuredQrDraft(
      type: QrCreationType.contact,
      fields: {
        'name': 'Léa; QR Team',
        'phone': '+15550100001',
        'email': 'qa+qr@example.com',
      },
    ),
    StructuredQrDraft(
      type: QrCreationType.event,
      fields: const {
        'title': 'QR; test, event',
        'location': 'Room 2',
        'description': 'Line one\nLine two ✓',
      },
      start: DateTime.utc(2027, 2, 20, 12, 30),
      end: DateTime.utc(2027, 2, 20, 13, 30),
      useUtc: true,
    ),
    const StructuredQrDraft(
      type: QrCreationType.location,
      fields: {'latitude': '-33.8600', 'longitude': '151.2100'},
    ),
    const StructuredQrDraft(
      type: QrCreationType.email,
      fields: {
        'email': 'qa+tag%value@example.com',
        'subject': 'A+B & 100% ✓',
        'body': 'Line one\nLine two + & # ? %',
      },
    ),
    const StructuredQrDraft(
      type: QrCreationType.phone,
      fields: {'phone': '+15550100001'},
    ),
    const StructuredQrDraft(
      type: QrCreationType.sms,
      fields: {'phone': '+15550100001', 'body': 'Meet + & # ? % ✓\nTomorrow'},
    ),
  ];
  for (final draft in drafts) {
    testWidgets('native structured QR round trip: ${draft.type.name}', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final raw = draft.encode();
      final expected = const QrPayloadClassifier().classify(raw);
      final png = const QrPngRenderer().render(
        const DartQrEncoder().encode(raw),
      );
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/dali_structured_qa_${draft.type.name}.png',
      );
      final controller = MobileScannerController(autoStart: false);
      try {
        await file.writeAsBytes(png.bytes);
        final result = await NativeCodeImageAnalyzer(
          controller,
        ).analyze(file.path, source: ScanSource.gallery);
        expect(result.codes, hasLength(1));
        final code = result.codes.single;
        expect(code.format, ScannedCodeFormat.qrCode);
        expect(code.value, raw);
        final actual = const QrPayloadClassifier().classify(code.value);
        expect(actual.type, expected.type);
        expect(actual.action, expected.action);
        expect(actual.routeArguments, expected.routeArguments);
        expect(actual.launchUri, expected.launchUri);
        debugPrint(
          'STRUCTURED_QR_QA ${jsonEncode({'type': draft.type.name, 'exactPayload': true, 'exactInterpretedFields': true, 'result': 'passed'})}',
        );
      } finally {
        await controller.dispose();
        if (await file.exists()) await file.delete();
      }
    });
  }
  for (final draft in drafts) {
    testWidgets('confirmed native handoff: ${draft.type.name}', (tester) async {
      final payload = const QrPayloadClassifier().classify(draft.encode());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => routeQrPayload(context, payload),
                child: const Text('Review action'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review action'));
      await tester.pumpAndSettle();
      debugPrint(
        'STRUCTURED_HANDOFF_BEGIN ${jsonEncode({'type': draft.type.name})}',
      );
      await tester.tap(find.text('Continue'));
      // The watcher observes the external activity and returns to this QA app.
      // No Send, Save, Pay or Call button is pressed.
      await Future<void>.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      final unavailable = find
          .text(payload.failureMessage)
          .evaluate()
          .isNotEmpty;
      debugPrint(
        'STRUCTURED_QR_QA ${jsonEncode({'type': '${draft.type.name}_handoff', 'result': unavailable ? 'handlerUnavailable' : 'returned', 'userDataCommitted': false})}',
      );
    });
  }
}
