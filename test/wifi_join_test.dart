import 'dart:async';

import 'package:dali_qr/features/scan/application/qr_payload_router.dart';
import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:dali_qr/features/scan/domain/wifi_network.dart';
import 'package:dali_qr/features/scan/presentation/qr_payload_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const sample = r'WIFI:T:WPA;S:Dali\;Guest;P:50%secret;H:true;;';
WifiNetworkDetails network(String raw) => WifiNetworkDetails.fromFields(
  const QrPayloadClassifier().classify(raw).routeArguments,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const router = QrPayloadRouter();
  const channel = MethodChannel('dali_qr/routing');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final settingsOpened in [true, false]) {
    testWidgets(
      'already saved hands off to settings without repeating join: $settingsOpened',
      (tester) async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'wifiJoinCapabilities' => {
              'securityTypes': ['open', 'wpa2'],
              'canOpenSettings': true,
            },
            'joinWifi' => 'alreadySaved',
            'configureWifi' => settingsOpened,
            _ => null,
          };
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => routeQrPayload(
                    context,
                    const QrPayloadClassifier().classify(sample),
                  ),
                  child: const Text('Review Wi-Fi'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Review Wi-Fi'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Join network'));
        await tester.pumpAndSettle();
        expect(calls.where((c) => c.method == 'joinWifi'), hasLength(1));
        expect(calls.last.method, 'configureWifi');
        expect(calls.last.arguments, isEmpty);
        expect(find.widgetWithText(FilledButton, 'Join network'), findsNothing);
        expect(find.textContaining('Network saved.'), findsNothing);
        expect(find.textContaining('50%secret'), findsNothing);
        if (!settingsOpened) {
          expect(
            find.text(
              'Open Settings > Wi-Fi and select this network to connect.',
            ),
            findsOneWidget,
          );
        }
        await tester.tap(find.text('Select network in Wi-Fi settings'));
        await tester.pumpAndSettle();
        expect(calls.where((c) => c.method == 'joinWifi'), hasLength(1));
        expect(calls.where((c) => c.method == 'configureWifi'), hasLength(2));
      },
    );
  }

  test(
    'Wi-Fi credentials, escapes, spaces and hidden settings stay literal',
    () {
      final n = network(sample);
      expect(n.canJoin, isTrue);
      expect(n.nativeArguments, {
        'ssid': 'Dali;Guest',
        'password': '50%secret',
        'security': 'wpa2',
        'hidden': true,
      });
      final spaces = network('WIFI:T:WPA2;S:  Guest  ;P: secret password ;;');
      expect(spaces.ssid, '  Guest  ');
      expect(spaces.password, ' secret password ');
      expect(spaces.canJoin, isTrue);
      expect(network('WIFI:S:Guest;;').security, WifiSecurity.open);
      expect(
        network(
          'WIFI:T:nopass;S:Guest;;',
        ).nativeArguments.containsKey('password'),
        isFalse,
      );
      expect(network('WIFI:T:SAE;S:Guest;P:x;;').canJoin, isTrue);
      expect(
        network('WIFI:T:WPA3;S:Guest;P:secret123;;').security,
        WifiSecurity.wpa3,
      );
    },
  );

  test('invalid or ambiguous security never falls back to an open join', () {
    for (final raw in [
      'WIFI:S:Guest;P:secret123;;',
      'WIFI:T:nopass;S:Guest;P:secret123;;',
      'WIFI:T:WEP;S:Guest;P:0123456789;;',
      'WIFI:T:WPA2-EAP;S:Guest;P:secret123;;',
      'WIFI:T:Future;S:Guest;;',
      'WIFI:T:WPA;S:Guest;P:secret123;E:PEAP;;',
      'WIFI:T:WPA;S:Guest;P:secret123;I:employee;;',
      'WIFI:T:WPA;S:Guest;P:short;;',
      'WIFI:T:WPA;S:Guest;P:${'x' * 64};;',
      'WIFI:T:WPA;S:Guest;P:passwordé;;',
      'WIFI:T:WPA3;S:Guest;P:;;',
      'WIFI:T:nopass;S:${'x' * 33};;',
      'WIFI:T:nopass;S:${'中' * 11};;',
      'WIFI:T:nopass;S:Bad\nName;;',
      'WIFI:T:nopass;S:Bad\u0000Name;;',
      'WIFI:T:nopass;S:Guest;H:maybe;;',
    ]) {
      expect(network(raw).canJoin, isFalse, reason: raw);
    }
    expect(network('WIFI:T:nopass;S:${'中' * 10};;').canJoin, isTrue);
    expect(network('WIFI:T:nopass;S:${'x' * 32};;').canJoin, isTrue);
  });

  test('native handoff uses validated fields and typed OS outcomes', () async {
    final calls = <MethodCall>[];
    var status = 'saved';
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'wifiJoinCapabilities') {
        return {
          'securityTypes': ['open', 'wpa2'],
          'canOpenSettings': true,
        };
      }
      return status;
    });
    final caps = await router.wifiCapabilities();
    expect(caps.supports(network(sample)), isTrue);
    expect(caps.supports(network('WIFI:T:SAE;S:Guest;P:x;;')), isFalse);
    final payload = const QrPayloadClassifier().classify(sample);
    for (final result in WifiJoinOutcome.values) {
      status = result.name;
      expect(await router.joinWifi(payload), result);
      expect(calls.last.method, 'joinWifi');
      expect(calls.last.arguments, network(sample).nativeArguments);
    }
    status = 'unknown';
    expect(await router.joinWifi(payload), WifiJoinOutcome.failed);
  });

  test(
    'invalid and substituted Wi-Fi payloads never reach the native channel',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return 'saved';
      });
      for (final raw in [
        'WIFI:T:WEP;S:Guest;P:12345;;',
        'WIFI:T:WPA;S:Guest;P:short;;',
        'WIFI:S:A;S:B;;',
      ]) {
        expect(
          await router.joinWifi(const QrPayloadClassifier().classify(raw)),
          isNot(WifiJoinOutcome.saved),
        );
      }
      final valid = const QrPayloadClassifier().classify(sample);
      final forged = ClassifiedQrPayload(
        rawPayload: sample,
        type: QrContentType.wifi,
        action: QrRouteAction.configureWifi,
        title: '',
        primaryText: 'Other',
        routeArguments: {...valid.routeArguments, 'S': 'Other'},
      );
      expect(await router.joinWifi(forged), WifiJoinOutcome.failed);
      expect(calls, 0);
    },
  );

  test(
    'missing or failing native bridge produces a failure, not a join claim',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      expect(
        await router.joinWifi(const QrPayloadClassifier().classify(sample)),
        WifiJoinOutcome.failed,
      );
      expect((await router.wifiCapabilities()).securityTypes, isEmpty);
      messenger.setMockMethodCallHandler(channel, null);
      expect(
        await router.joinWifi(const QrPayloadClassifier().classify(sample)),
        WifiJoinOutcome.failed,
      );
    },
  );

  testWidgets(
    'review masks passwords, cancellation makes no request, pending joins cannot repeat',
    (tester) async {
      final pending = Completer<String>();
      var joins = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'wifiJoinCapabilities') {
          return {
            'securityTypes': ['open', 'wpa2'],
            'canOpenSettings': true,
          };
        }
        if (call.method == 'joinWifi') {
          joins++;
          expect(call.arguments, network(sample).nativeArguments);
          return pending.future;
        }
        return true;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => routeQrPayload(
                  context,
                  const QrPayloadClassifier().classify(sample),
                  comparisonCode: 'ABC123',
                ),
                child: const Text('Review Wi-Fi'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review Wi-Fi'));
      await tester.pumpAndSettle();
      expect(find.text('Dali;Guest'), findsOneWidget);
      expect(find.text('Password: ********'), findsOneWidget);
      expect(find.textContaining('50%secret'), findsNothing);
      expect(find.textContaining('ABC123'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(joins, 0);
      await tester.tap(find.text('Review Wi-Fi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reveal password'));
      await tester.pumpAndSettle();
      expect(find.text('Password: 50%secret'), findsOneWidget);
      await tester.tap(find.text('Join network'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Waiting for device...'));
      await tester.pump();
      expect(joins, 1);
      pending.complete('cancelled');
      await tester.pumpAndSettle();
      expect(find.text('Wi-Fi request cancelled.'), findsOneWidget);
      expect(find.textContaining('Network saved'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unsupported devices retain manual settings without sending credentials',
    (tester) async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'wifiJoinCapabilities') {
          return {'securityTypes': <String>[], 'canOpenSettings': true};
        }
        return true;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => routeQrPayload(
                  context,
                  const QrPayloadClassifier().classify(sample),
                ),
                child: const Text('Review Wi-Fi'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review Wi-Fi'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Join network'), findsNothing);
      await tester.tap(find.text('Open Wi-Fi settings'));
      await tester.pumpAndSettle();
      expect(calls.last.method, 'configureWifi');
      expect(calls.last.arguments, isEmpty);
      expect(calls.where((c) => c.method == 'joinWifi'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
