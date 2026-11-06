import 'dart:async';

import 'package:flutter/services.dart';

typedef SharedImageHandler = void Function(String path);

abstract interface class InboundImageShareSource {
  Future<void> start(SharedImageHandler onSharedImage);

  void dispose();
}

final class InboundImageShare implements InboundImageShareSource {
  InboundImageShare({
    MethodChannel? channel,
    this.onError,
    this.initialReplyTimeout = const Duration(seconds: 3),
  }) : _channel = channel ?? const MethodChannel('dali_qr/inbound_share');

  final MethodChannel _channel;
  final void Function(String message)? onError;
  final Duration initialReplyTimeout;
  final _delivered = <String>[];
  SharedImageHandler? _onSharedImage;

  @override
  Future<void> start(SharedImageHandler onSharedImage) async {
    _onSharedImage = onSharedImage;
    _channel.setMethodCallHandler(_handleMethodCall);
    try {
      // Keep the delivery continuation on the original future: if the bridge
      // replies late, its image must still be consumed rather than discarded.
      await _channel
          .invokeMethod<Object?>('takeInitialImage')
          .then(_deliver)
          .timeout(initialReplyTimeout);
    } on MissingPluginException {
      // Inbound sharing is unavailable on unsupported platforms.
    } on PlatformException {
      // A malformed or inaccessible share should not prevent app startup.
    } on TimeoutException {
      // An unavailable native bridge must not block normal scanner startup.
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'sharedImage') return;
    _deliver(call.arguments);
  }

  void _deliver(Object? value) {
    if (_onSharedImage == null) return;
    if (value case {'error': final String message, 'id': final String id}) {
      if (_remember('error:$id')) onError?.call(message);
    } else if (value is String && value.trim().isNotEmpty && _remember(value)) {
      _onSharedImage?.call(value);
    }
  }

  bool _remember(String identity) {
    if (_delivered.contains(identity)) return false;
    _delivered.add(identity);
    if (_delivered.length > 32) _delivered.removeAt(0);
    return true;
  }

  @override
  void dispose() {
    _onSharedImage = null;
    _channel.setMethodCallHandler(null);
  }
}
