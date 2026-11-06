import 'dart:convert';

enum WifiSecurity { open, wpa2, wpa3, unsupported }

/// Parsed credentials stay local and are passed literally to the OS.
final class WifiNetworkDetails {
  const WifiNetworkDetails({
    required this.ssid,
    required this.password,
    required this.security,
    required this.hidden,
    this.problem,
  });
  final String ssid;
  final String password;
  final WifiSecurity security;
  final bool hidden;
  final String? problem;
  bool get canJoin => problem == null && security != WifiSecurity.unsupported;
  String get securityLabel => switch (security) {
    WifiSecurity.open => 'Open network (no encryption)',
    WifiSecurity.wpa2 => 'WPA / WPA2 Personal',
    WifiSecurity.wpa3 => 'WPA3 Personal',
    WifiSecurity.unsupported => 'Unsupported security type',
  };

  factory WifiNetworkDetails.fromFields(Map<String, Object?> fields) {
    final ssid = fields['S'] is String ? fields['S'] as String : '';
    final password = fields['P'] is String ? fields['P'] as String : '';
    final type = (fields['T'] is String ? fields['T'] as String : '')
        .toUpperCase();
    final hiddenValue = (fields['H'] is String ? fields['H'] as String : '')
        .toLowerCase();
    final security = switch (type) {
      '' || 'NOPASS' => WifiSecurity.open,
      'WPA' || 'WPA2' || 'WPA-PSK' || 'WPA2-PSK' => WifiSecurity.wpa2,
      'SAE' || 'WPA3' || 'WPA3-SAE' => WifiSecurity.wpa3,
      _ => WifiSecurity.unsupported,
    };
    String? problem;
    if (ssid.isEmpty ||
        ssid.length > 32 ||
        utf8.encode(ssid).length > 32 ||
        ssid.runes.any((r) => r < 32 || r == 127) ||
        utf8.decode(utf8.encode(ssid)) != ssid) {
      problem =
          'The network name must contain 1–32 UTF-8 bytes without control characters.';
    } else if (hiddenValue.isNotEmpty &&
        hiddenValue != 'true' &&
        hiddenValue != 'false') {
      problem = 'The hidden-network setting is invalid.';
    } else if (security == WifiSecurity.unsupported ||
        ['E', 'I', 'A', 'PH2'].any(
          (key) => fields[key] is String && (fields[key] as String).isNotEmpty,
        )) {
      problem =
          'WEP, enterprise, and unrecognized security types require manual Wi-Fi configuration.';
    } else if (security == WifiSecurity.open && password.isNotEmpty) {
      problem =
          'This code contains a password without a supported security type. Configure it manually.';
    } else if (security != WifiSecurity.open &&
        (password.length < (security == WifiSecurity.wpa3 ? 1 : 8) ||
            password.length > 63 ||
            password.codeUnits.any((c) => c < 32 || c > 126))) {
      problem = security == WifiSecurity.wpa3
          ? 'WPA3 requires a 1–63 character ASCII passphrase.'
          : 'WPA / WPA2 requires an 8–63 character ASCII passphrase. Raw hexadecimal keys require manual configuration.';
    }
    return WifiNetworkDetails(
      ssid: ssid,
      password: password,
      security: security,
      hidden: hiddenValue == 'true',
      problem: problem,
    );
  }

  Map<String, Object?> get nativeArguments => {
    'ssid': ssid,
    'security': security.name,
    if (security != WifiSecurity.open) 'password': password,
    'hidden': hidden,
  };
}

enum WifiJoinOutcome {
  saved,
  alreadySaved,
  accepted,
  alreadyAssociated,
  cancelled,
  unsupported,
  busy,
  failed,
}

final class WifiJoinCapabilities {
  const WifiJoinCapabilities({
    this.securityTypes = const {},
    this.canOpenSettings = false,
  });
  final Set<String> securityTypes;
  final bool canOpenSettings;
  bool supports(WifiNetworkDetails network) =>
      network.canJoin && securityTypes.contains(network.security.name);
}
