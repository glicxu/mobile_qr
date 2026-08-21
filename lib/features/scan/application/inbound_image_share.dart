import 'package:flutter/services.dart';

typedef SharedImageHandler = void Function(String path);

abstract interface class InboundImageShareSource {
  Future<void> start(SharedImageHandler onSharedImage);

  void dispose();
}

final class InboundImageShare implements InboundImageShareSource {
  InboundImageShare({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('dali_qr/inbound_share');

  final MethodChannel _channel;
  SharedImageHandler? _onSharedImage;

  @override
  Future<void> start(SharedImageHandler onSharedImage) async {
    _onSharedImage = onSharedImage;
    _channel.setMethodCallHandler(_handleMethodCall);
    try {
      final path = await _channel.invokeMethod<String>('takeInitialImage');
      _deliver(path);
    } on MissingPluginException {
      // Inbound sharing is unavailable on unsupported platforms.
    } on PlatformException {
      // A malformed or inaccessible share should not prevent app startup.
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'sharedImage') return;
    _deliver(call.arguments as String?);
  }

  void _deliver(String? path) {
    if (path == null || path.trim().isEmpty) return;
    _onSharedImage?.call(path);
  }

  @override
  void dispose() {
    _onSharedImage = null;
    _channel.setMethodCallHandler(null);
  }
}
