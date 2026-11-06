import 'package:dali_qr/features/create/domain/wifi_qr_payload.dart';
import 'package:dali_qr/features/create/presentation/wifi_qr_fields.dart';
import 'package:dali_qr/features/create/data/dart_qr_encoder.dart';
import 'package:dali_qr/features/create/data/qr_png_renderer.dart';
import 'package:dali_qr/features/create/application/qr_png_validator.dart';
import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:dali_qr/features/scan/domain/wifi_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Wi-Fi QR preserves curly apostrophes as distinct SSID bytes', () {
    const draft = WifiQrDraft(
      ssid: 'Guest\u2019s Hotspot',
      password: 'guestPass123',
    );
    final payload = draft.encode();
    final parsed = const QrPayloadClassifier().classify(payload);
    final network = WifiNetworkDetails.fromFields(parsed.routeArguments);
    expect(network.ssid, 'Guest\u2019s Hotspot');
    expect(network.ssid, isNot("Guest's Hotspot"));
    expect(network.nativeArguments['ssid'], draft.ssid);
    final png = const QrPngRenderer().render(
      const DartQrEncoder().encode(payload),
    );
    expect(
      const QrPngValidator().containsExactPayload(png.bytes, payload),
      isTrue,
    );
  });
  test(
    'Wi-Fi QR preserves literal credentials through encoding and scanning',
    () {
      const draft = WifiQrDraft(
        ssid: ' Guest;:"\\, café ',
        password: ' pass;:"\\,% ',
        hidden: true,
      );
      final payload = draft.encode();
      final parsed = const QrPayloadClassifier().classify(payload);
      final network = WifiNetworkDetails.fromFields(parsed.routeArguments);
      expect(network.canJoin, isTrue);
      expect(network.ssid, draft.ssid);
      expect(network.password, draft.password);
      expect(network.hidden, isTrue);
      final png = const QrPngRenderer().render(
        const DartQrEncoder().encode(payload),
      );
      expect(
        const QrPngValidator().containsExactPayload(png.bytes, payload),
        isTrue,
      );
    },
  );
  test(
    'Wi-Fi QR validates profiles and never embeds stale open-network passwords',
    () {
      expect(
        () => const WifiQrDraft(ssid: '', password: '12345678').encode(),
        throwsFormatException,
      );
      expect(
        () => const WifiQrDraft(ssid: 'Guest', password: 'short').encode(),
        throwsFormatException,
      );
      expect(
        () => WifiQrDraft(ssid: 'é' * 17, password: '12345678').encode(),
        throwsFormatException,
      );
      final open = const WifiQrDraft(
        ssid: 'Guest',
        password: 'stale-secret',
        security: WifiSecurity.open,
      ).encode();
      expect(open, isNot(contains('stale-secret')));
      expect(open, contains('T:nopass;'));
      final sae = const WifiQrDraft(
        ssid: 'Guest',
        password: 'x',
        security: WifiSecurity.wpa3,
      ).encode();
      expect(sae, contains('T:SAE;'));
    },
  );
  testWidgets(
    'Wi-Fi form hides password and emits current security and hidden flag',
    (tester) async {
      WifiQrDraft? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WifiQrFields(onChanged: (value) => draft = value),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Guest hotspot');
      await tester.enterText(find.byType(TextField).last, 'guestPass123');
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Reveal password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(draft!.hidden, isTrue);
      expect(draft!.ssid, 'Guest hotspot');
      await tester.tap(find.byType(DropdownButtonFormField<WifiSecurity>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open (no password)').last);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(draft!.encode(), isNot(contains('guestPass123')));
    },
  );
}
