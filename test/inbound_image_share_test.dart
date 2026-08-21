import 'package:dali_qr/features/scan/application/inbound_image_share.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/inbound_share');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('delivers the image that launched the app', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'takeInitialImage');
          return '/cache/initial.png';
        });
    final paths = <String>[];
    final source = InboundImageShare(channel: channel);

    await source.start(paths.add);

    expect(paths, ['/cache/initial.png']);
    source.dispose();
  });

  test('delivers an image shared while the app is running', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    final paths = <String>[];
    final source = InboundImageShare(channel: channel);
    await source.start(paths.add);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('sharedImage', '/cache/warm.png'),
          ),
          (_) {},
        );

    expect(paths, ['/cache/warm.png']);
    source.dispose();
  });
}
