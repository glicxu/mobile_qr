import 'dart:convert';

import 'package:dali_qr/features/scan/application/qr_payload_router.dart';
import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:dali_qr/features/scan/domain/wifi_network.dart';
import 'package:dali_qr/features/scan/presentation/qr_payload_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const id = String.fromEnvironment('WIFI_QA_ID', defaultValue: 'local');
  const router = QrPayloadRouter();
  testWidgets(
    'native Wi-Fi validation rejects invalid credentials before handoff',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final caps = await router.wifiCapabilities();
      expect(caps.securityTypes, containsAll(['open', 'wpa2']));
      const channel = MethodChannel('dali_qr/routing');
      expect(
        await channel.invokeMethod<String>('joinWifi', {
          'ssid': 'DALI-QR-QA-$id-BAD',
          'security': 'wpa2',
          'password': 'short',
          'hidden': false,
        }),
        'failed',
      );
      expect(
        await channel.invokeMethod<String>('joinWifi', {
          'ssid': '',
          'security': 'open',
          'hidden': false,
        }),
        'failed',
      );
      debugPrint(
        'WIFI_JOIN_QA ${jsonEncode({'case': 'nativeValidation', 'result': 'passed', 'supportedSecurity': caps.securityTypes.toList()})}',
      );
    },
  );

  for (final security in ['wpa2', 'open', 'wpa3']) {
    testWidgets(
      'system Wi-Fi approval and cancellation: $security',
      (tester) async {
        final caps = await router.wifiCapabilities();
        if (!caps.securityTypes.contains(security)) {
          expect(security, 'wpa3');
          debugPrint(
            'WIFI_JOIN_QA ${jsonEncode({'case': security, 'result': 'unsupportedOnDevice'})}',
          );
          return;
        }
        final ssid = 'DALI-QR-QA-$id-${security.toUpperCase()}';
        final raw = security == 'open'
            ? 'WIFI:T:nopass;S:$ssid;;'
            : 'WIFI:T:${security == 'wpa3' ? 'SAE' : 'WPA'};S:$ssid;P:Test%pass123;H:true;;';
        final payload = const QrPayloadClassifier().classify(raw);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => routeQrPayload(context, payload),
                  child: const Text('Review Wi-Fi'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Review Wi-Fi'));
        await tester.pumpAndSettle();
        expect(find.text(ssid), findsOneWidget);
        expect(find.textContaining('Test%pass123'), findsNothing);
        await tester.tap(find.text('Join network'));
        expect(await router.joinWifi(payload), WifiJoinOutcome.busy);
        // tool/qa_wifi_join.py observes the real system screen and presses Back.
        final timer = Stopwatch()..start();
        while (find.text('Wi-Fi request cancelled.').evaluate().isEmpty &&
            timer.elapsed < const Duration(seconds: 70)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Wi-Fi request cancelled.'), findsOneWidget);
        expect(find.textContaining('Network saved'), findsNothing);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        debugPrint(
          'WIFI_JOIN_QA ${jsonEncode({'case': security, 'ssid': ssid, 'result': 'cancelled', 'duplicate': 'busy', 'passwordRevealed': false})}',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
