import 'package:flutter/services.dart';

abstract final class QrClipboard {
  static const _channel = MethodChannel('dali_qr/clipboard');

  static Future<void> copyPng({
    required Uint8List bytes,
    required String payload,
  }) {
    return _channel.invokeMethod<void>('copyPng', {
      'bytes': bytes,
      'payload': payload,
    });
  }
}
