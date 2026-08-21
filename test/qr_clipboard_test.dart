import 'package:dali_qr/features/history/application/qr_clipboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'copies PNG bytes and payload through the native clipboard channel',
    () async {
      const channel = MethodChannel('dali_qr/clipboard');
      MethodCall? receivedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            receivedCall = call;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await QrClipboard.copyPng(
        bytes: Uint8List.fromList([1, 2, 3]),
        payload: 'https://example.com/',
      );

      expect(receivedCall?.method, 'copyPng');
      expect(receivedCall?.arguments['bytes'], [1, 2, 3]);
      expect(receivedCall?.arguments['payload'], 'https://example.com/');
    },
  );
}
