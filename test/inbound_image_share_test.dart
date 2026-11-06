import 'dart:async';
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
  test(
    'startup and warm delivery of the same share are consumed once',
    () async {
      final initial = Completer<Object?>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) => initial.future);
      final paths = <String>[];
      final source = InboundImageShare(channel: channel);
      final starting = source.start(paths.add);
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('sharedImage', '/cache/once.png'),
        ),
        (_) {},
      );
      initial.complete('/cache/once.png');
      await starting;
      expect(paths, ['/cache/once.png']);
      source.dispose();
    },
  );

  test(
    'cold and warm share errors are reported once and malformed events stay inert',
    () async {
      const error = {
        'id': 'error-1',
        'error': 'The shared image could not be opened.',
      };
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => error);
      final errors = <String>[];
      final paths = <String>[];
      final source = InboundImageShare(channel: channel, onError: errors.add);
      await source.start(paths.add);
      for (final value in [
        error,
        null,
        123,
        {'unexpected': true},
        '   ',
      ]) {
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('sharedImage', value),
          ),
          (_) {},
        );
      }
      expect(errors, [error['error']]);
      expect(paths, isEmpty);
      source.dispose();
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('sharedImage', '/cache/late.png'),
        ),
        (_) {},
      );
      expect(paths, isEmpty);
    },
  );
  test(
    'an unavailable startup bridge times out but a late image is still delivered',
    () async {
      final initial = Completer<Object?>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) => initial.future);
      final paths = <String>[];
      final source = InboundImageShare(
        channel: channel,
        initialReplyTimeout: Duration.zero,
      );
      await source.start(paths.add);
      expect(paths, isEmpty);
      initial.complete('/cache/late-initial.png');
      await Future<void>.delayed(Duration.zero);
      expect(paths, ['/cache/late-initial.png']);
      source.dispose();
    },
  );
}
