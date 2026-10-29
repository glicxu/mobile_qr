import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/qr_payload_classifier.dart';

final class QrPayloadRouter {
  const QrPayloadRouter();

  static const _channel = MethodChannel('dali_qr/routing');

  Future<bool> route(ClassifiedQrPayload payload) async {
    switch (payload.action) {
      case QrRouteAction.authenticatePasskey:
        // Preserve the standard uppercase scheme (Dart Uri normalizes it).
        if (!RegExp(
          r'^FIDO:/[0-9]+$',
          caseSensitive: false,
        ).hasMatch(payload.rawPayload)) {
          return false;
        }
        return await _invoke('authenticatePasskey', {
          'uri': 'FIDO:${payload.rawPayload.substring(5)}',
        });
      case QrRouteAction.openUrl:
      case QrRouteAction.composeEmail:
      case QrRouteAction.call:
      case QrRouteAction.composeSms:
      case QrRouteAction.openLocation:
      case QrRouteAction.openDeepLink:
        final uri = payload.launchUri;
        if (uri == null) return false;
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      case QrRouteAction.configureWifi:
        return await _invoke('configureWifi', payload.routeArguments);
      case QrRouteAction.addContact:
        return await _invoke('addContact', payload.routeArguments);
      case QrRouteAction.addCalendarEvent:
        return await _invoke('addCalendarEvent', payload.routeArguments);
      case QrRouteAction.none:
        return false;
    }
  }

  Future<bool> _invoke(String method, Map<String, Object?> arguments) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
