import 'dart:convert';

/// Provisioning codes contain long-lived shared secrets, even when malformed.
abstract final class EphemeralCodePolicy {
  static bool isAuthenticator(String raw) => RegExp(
    r'^\s*otpauth(?:-migration)?\s*:',
    caseSensitive: false,
  ).hasMatch(raw);
  static bool blocksPersistence(String raw) =>
      isAuthenticator(raw) ||
      RegExp(r'^\s*fido\s*:', caseSensitive: false).hasMatch(raw);
}

final class AuthenticatorPayload {
  const AuthenticatorPayload({
    required this.uri,
    required this.account,
    required this.issuer,
    required this.secret,
    required this.kind,
    required this.algorithm,
    required this.digits,
    this.period,
    this.counter,
  });
  final Uri uri;
  final String account;
  final String? issuer;
  final String secret;
  final String kind;
  final String algorithm;
  final int digits;
  final int? period;
  final BigInt? counter;

  /// Some launch plugins log their capability-query URI in debug builds.
  /// Handler lookup needs only a scheme/host/path, never account credentials.
  Uri get handlerProbe => Uri(scheme: 'otpauth', host: kind, path: '/DaliQR');

  static AuthenticatorPayload? tryParse(String raw) {
    try {
      return _parse(raw);
    } on Object {
      return null;
    }
  }

  static AuthenticatorPayload? _parse(String raw) {
    if (raw.length > 4096 ||
        utf8.encode(raw).length > 4096 ||
        raw.trim() != raw ||
        RegExp(r'[\x00-\x20\x7f-\x9f]').hasMatch(raw) ||
        RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(raw)) {
      return null;
    }
    final uri = Uri.parse(raw);
    if (uri.scheme.toLowerCase() != 'otpauth' ||
        !['totp', 'hotp'].contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment ||
        uri.pathSegments.length != 1) {
      return null;
    }
    final label = uri.pathSegments.single;
    if (label.trim().isEmpty || _controls(label)) return null;
    final params = uri.queryParametersAll;
    const allowed = {
      'secret',
      'issuer',
      'algorithm',
      'digits',
      'period',
      'counter',
    };
    if (params.entries.any(
      (e) =>
          !allowed.contains(e.key) ||
          e.value.length != 1 ||
          e.value.single.isEmpty ||
          _controls(e.value.single),
    )) {
      return null;
    }
    String? value(String key) => params[key]?.single;
    final secret = value('secret');
    if (secret == null || !_base32(secret)) return null;
    final parts = label.split(':');
    if (parts.length > 2 || parts.any((p) => p.trim().isEmpty)) return null;
    final account = parts.last.trimLeft();
    final prefix = parts.length == 2 ? parts.first : null;
    final issuer = value('issuer') ?? prefix;
    if (prefix != null &&
        value('issuer') != null &&
        prefix != value('issuer')) {
      return null;
    }
    if (issuer != null && (issuer.trim().isEmpty || issuer.contains(':'))) {
      return null;
    }
    final algorithm = (value('algorithm') ?? 'SHA1').toUpperCase();
    final digitsText = value('digits') ?? '6';
    if (!['SHA1', 'SHA256', 'SHA512'].contains(algorithm) ||
        !['6', '8'].contains(digitsText)) {
      return null;
    }
    int? period;
    BigInt? counter;
    if (uri.host == 'totp') {
      final text = value('period') ?? '30';
      if (value('counter') != null || !RegExp(r'^[0-9]+$').hasMatch(text)) {
        return null;
      }
      period = int.tryParse(text);
      if (period == null || period < 1 || period > 86400) return null;
    } else {
      final text = value('counter');
      if (value('period') != null ||
          text == null ||
          !RegExp(r'^[0-9]+$').hasMatch(text)) {
        return null;
      }
      counter = BigInt.tryParse(text);
      if (counter == null || counter > ((BigInt.one << 64) - BigInt.one)) {
        return null;
      }
    }
    return AuthenticatorPayload(
      uri: uri,
      account: account,
      issuer: issuer,
      secret: secret,
      kind: uri.host,
      algorithm: algorithm,
      digits: int.parse(digitsText),
      period: period,
      counter: counter,
    );
  }

  static bool _controls(String value) =>
      RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(value) ||
      utf8.decode(utf8.encode(value)) != value;
  static bool _base32(String value) {
    if (value.length > 1024 ||
        !RegExp(r'^[A-Z2-7]+$', caseSensitive: false).hasMatch(value) ||
        !{0, 2, 4, 5, 7}.contains(value.length % 8)) {
      return false;
    }
    final remaining = value.length * 5 % 8;
    final last = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'.indexOf(
      value[value.length - 1].toUpperCase(),
    );
    return remaining == 0 || (last & ((1 << remaining) - 1)) == 0;
  }
}
