import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/qr_payload_classifier.dart';
import '../domain/link_inspection.dart';
import '../domain/wifi_network.dart';
import '../domain/authenticator_payload.dart';

final class QrPayloadRouter {
  const QrPayloadRouter();

  static const _channel = MethodChannel('dali_qr/routing');

  Future<bool> route(ClassifiedQrPayload payload) async {
    switch (payload.action) {
      case QrRouteAction.setupAuthenticator:
        final setup = AuthenticatorPayload.tryParse(payload.rawPayload);
        if (payload.type != QrContentType.authenticator ||
            setup == null ||
            setup.uri != payload.launchUri) {
          return false;
        }
        try {
          if (!await canLaunchUrl(setup.handlerProbe)) return false;
          return await launchUrl(
            setup.uri,
            mode: LaunchMode.externalApplication,
          );
        } on Object {
          return false;
        }
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
        final inspection = const LinkInspector().inspect(payload.rawPayload);
        if (!inspection.canOpen || inspection.uri != payload.launchUri) {
          return false;
        }
        return launchUrl(inspection.uri!, mode: LaunchMode.externalApplication);
      case QrRouteAction.openDeepLink:
        // No custom URI scheme is currently approved for arbitrary handoff.
        return false;
      case QrRouteAction.composeEmail:
      case QrRouteAction.call:
      case QrRouteAction.composeSms:
      case QrRouteAction.openLocation:
        final uri = payload.launchUri;
        if (uri == null) return false;
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      case QrRouteAction.configureWifi:
        final outcome = await joinWifi(payload);
        return [
          WifiJoinOutcome.saved,
          WifiJoinOutcome.alreadySaved,
          WifiJoinOutcome.accepted,
          WifiJoinOutcome.alreadyAssociated,
        ].contains(outcome);
      case QrRouteAction.addContact:
        return await _invoke('addContact', payload.routeArguments);
      case QrRouteAction.addCalendarEvent:
        return await _invoke('addCalendarEvent', payload.routeArguments);
      case QrRouteAction.none:
        return false;
    }
  }

  Future<WifiJoinCapabilities> wifiCapabilities() async {
    try {
      final data = await _channel.invokeMapMethod<String, Object?>(
        'wifiJoinCapabilities',
      );
      return WifiJoinCapabilities(
        securityTypes:
            (data?['securityTypes'] as List?)?.whereType<String>().toSet() ??
            const {},
        canOpenSettings: data?['canOpenSettings'] == true,
      );
    } on Object {
      return const WifiJoinCapabilities();
    }
  }

  Future<WifiJoinOutcome> joinWifi(ClassifiedQrPayload payload) async {
    if (payload.type != QrContentType.wifi ||
        payload.action != QrRouteAction.configureWifi) {
      return WifiJoinOutcome.failed;
    }
    final parsed = const QrPayloadClassifier().classify(payload.rawPayload);
    if (parsed.type != QrContentType.wifi ||
        parsed.action != QrRouteAction.configureWifi ||
        parsed.routeArguments.length != payload.routeArguments.length ||
        parsed.routeArguments.entries.any(
          (e) => payload.routeArguments[e.key] != e.value,
        )) {
      return WifiJoinOutcome.failed;
    }
    final network = WifiNetworkDetails.fromFields(payload.routeArguments);
    if (!network.canJoin) return WifiJoinOutcome.unsupported;
    try {
      final status = await _channel.invokeMethod<String>(
        'joinWifi',
        network.nativeArguments,
      );
      return WifiJoinOutcome.values.firstWhere(
        (v) => v.name == status,
        orElse: () => WifiJoinOutcome.failed,
      );
    } on Object {
      return WifiJoinOutcome.failed;
    }
  }

  Future<bool> openWifiSettings() => _invoke('configureWifi', const {});

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
