import '../../scan/domain/wifi_network.dart';

/// Standard WIFI payload. Field values are literal; escape separators once.
final class WifiQrDraft {
  const WifiQrDraft({
    this.ssid = '',
    this.password = '',
    this.security = WifiSecurity.wpa2,
    this.hidden = false,
  });
  final String ssid;
  final String password;
  final WifiSecurity security;
  final bool hidden;

  String encode() {
    final type = switch (security) {
      WifiSecurity.open => 'nopass',
      WifiSecurity.wpa2 => 'WPA',
      WifiSecurity.wpa3 => 'SAE',
      WifiSecurity.unsupported => throw const FormatException(
        'Choose a supported security type.',
      ),
    };
    final details = WifiNetworkDetails.fromFields({
      'S': ssid,
      'P': security == WifiSecurity.open ? '' : password,
      'T': type,
      'H': hidden.toString(),
    });
    if (!details.canJoin) {
      throw FormatException(details.problem ?? 'Check the Wi-Fi details.');
    }
    String escape(String value) =>
        value.replaceAllMapped(RegExp(r'[\\;,:"]'), (m) => '\\${m[0]}');
    return 'WIFI:T:$type;S:${escape(ssid)};${security == WifiSecurity.open ? '' : 'P:${escape(password)};'}H:$hidden;;';
  }
}
