import 'package:punycoder/punycoder.dart';

enum LinkWarning {
  http,
  userInfo,
  internationalizedHost,
  unusualPort,
  numericHost,
}

/// A local interpretation, never a reputation or authenticity assessment.
final class LinkInspection {
  const LinkInspection({
    required this.rawValue,
    required this.scheme,
    this.uri,
    this.asciiHost,
    this.problem,
    this.warnings = const [],
  });

  final String rawValue;
  final String scheme;
  final Uri? uri;
  final String? asciiHost;
  final String? problem;
  final List<LinkWarning> warnings;

  bool get canOpen =>
      problem == null && uri != null && (scheme == 'http' || scheme == 'https');
}

final class LinkInspector {
  const LinkInspector();

  static final _scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.-]*):');
  static final _hiddenCharacters = RegExp(
    r'[\s\x00-\x1f\x7f-\x9f\u061c\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]',
  );
  static final _badEscape = RegExp(r'%(?![0-9A-Fa-f]{2})');

  LinkInspection inspect(String raw) {
    final scheme = _scheme.firstMatch(raw)?.group(1)?.toLowerCase() ?? '';
    LinkInspection invalid(String reason) =>
        LinkInspection(rawValue: raw, scheme: scheme, problem: reason);
    if (scheme != 'http' && scheme != 'https') {
      return invalid('This link scheme is not supported for opening.');
    }
    if (_hiddenCharacters.hasMatch(raw) || raw.contains(r'\')) {
      return invalid(
        'The destination contains whitespace, hidden characters, or a backslash.',
      );
    }
    if (_badEscape.hasMatch(raw)) {
      return invalid('The destination contains an invalid percent escape.');
    }
    try {
      final uri = Uri.parse(raw);
      if (!uri.hasAuthority || uri.host.isEmpty) {
        return invalid('The destination does not include a host.');
      }
      if (uri.port < 1 || uri.port > 65535) {
        return invalid('The destination has an invalid port.');
      }
      final host = Uri.decodeComponent(uri.host);
      // Uri validates bracketed IPv6 syntax. Domain conversion is local only.
      final asciiHost = host.contains(':')
          ? host.toLowerCase()
          : domainToAscii(host);
      final internationalized =
          host.codeUnits.any((unit) => unit > 127) ||
          asciiHost.split('.').any((label) => label.startsWith('xn--'));
      if (internationalized) {
        domainToUnicode(asciiHost); // Validate Punycode decoding.
      }
      return LinkInspection(
        rawValue: raw,
        scheme: scheme,
        uri: uri,
        asciiHost: asciiHost,
        warnings: List.unmodifiable([
          if (scheme == 'http') LinkWarning.http,
          if (uri.userInfo.isNotEmpty) LinkWarning.userInfo,
          if (internationalized) LinkWarning.internationalizedHost,
          if (uri.hasPort && uri.port != (scheme == 'https' ? 443 : 80))
            LinkWarning.unusualPort,
          if (RegExp(r'^[0-9.]+$').hasMatch(asciiHost) ||
              asciiHost.contains(':'))
            LinkWarning.numericHost,
        ]),
      );
    } on FormatException {
      return invalid(
        'The destination is malformed or its host cannot be interpreted.',
      );
    } on ArgumentError {
      return invalid(
        'The destination is malformed or its host cannot be interpreted.',
      );
    }
  }
}
