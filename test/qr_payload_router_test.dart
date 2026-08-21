import 'package:dali_qr/features/scan/application/qr_payload_router.dart';
import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dali_qr/routing');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('passes parsed contact fields to the native route', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return true;
        });
    final payload = const QrPayloadClassifier().classify(
      'BEGIN:VCARD\nFN:John Smith\nTEL:+14255551212\nEND:VCARD',
    );

    expect(await const QrPayloadRouter().route(payload), isTrue);
    expect(received?.method, 'addContact');
    expect(received?.arguments, {
      'name': 'John Smith',
      'phone': '+14255551212',
    });
  });

  test('returns false when the platform route is unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    final payload = const QrPayloadClassifier().classify(
      'WIFI:T:WPA;S:Guest;P:secret;;',
    );

    expect(await const QrPayloadRouter().route(payload), isFalse);
  });
}
