import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:punycoder/punycoder.dart';

import '../../create/domain/url_payload_policy.dart';
import 'public_suffix_list.dart';

sealed class QrVerificationResult {
  const QrVerificationResult({required this.code});

  final String code;
}

final class SecureQrResult extends QrVerificationResult {
  const SecureQrResult({
    required super.code,
    required this.registrableDomain,
    required this.canonicalUrl,
    required this.canonicalUtf8Length,
  });

  final String registrableDomain;
  final String canonicalUrl;
  final int canonicalUtf8Length;
}

final class ContentQrResult extends QrVerificationResult {
  const ContentQrResult({
    required super.code,
    required this.utf8ByteLength,
    required this.hashLetters,
  });

  final int utf8ByteLength;
  final String hashLetters;
}

final class SecureQrService {
  const SecureQrService(this._suffixes);

  final PublicSuffixList _suffixes;
  static const _urlPolicy = UrlPayloadPolicy();

  QrVerificationResult? calculateForPayload(String input) {
    try {
      _urlPolicy.validate(input);
    } on UrlPayloadValidationException {
      return calculateContent(input);
    }
    try {
      return calculate(input);
    } on UrlPayloadValidationException {
      // HTTP/HTTPS URLs without a registrable domain are not content payloads.
      return null;
    }
  }

  ContentQrResult calculateContent(String input) {
    final byteLength = utf8.encode(input).length;
    final contentValue = _bucket(
      'secure-qr/v1/content\u0000$input',
      26 * 26 * 26,
    );
    final letters = _letters(contentValue);
    final lengthDigits = (byteLength % 1000).toString().padLeft(3, '0');
    return ContentQrResult(
      code: '$lengthDigits-$letters',
      utf8ByteLength: byteLength,
      hashLetters: letters,
    );
  }

  SecureQrResult calculate(String input) {
    final validated = _urlPolicy.validate(input);
    final canonicalUrl = _canonicalize(validated.uri);
    final canonicalUri = Uri.parse(canonicalUrl);
    final asciiHost = _asciiHost(canonicalUri.host);
    final registrableDomain = _suffixes.registrableDomain(asciiHost);
    if (registrableDomain == null) {
      throw const UrlPayloadValidationException(
        UrlPayloadError.malformed,
        'The URL host does not have a registrable domain.',
      );
    }

    final domainValue = _bucket(
      'secure-qr/v1/domain\u0000$registrableDomain',
      26 * 26 * 26,
    );
    final linkValue = _bucket('secure-qr/v1/url\u0000$canonicalUrl', 100);
    final byteLength = utf8.encode(canonicalUrl).length;
    final lengthDigit = byteLength % 10;
    final letters = _letters(domainValue);

    return SecureQrResult(
      code: '$letters-$lengthDigit${linkValue.toString().padLeft(2, '0')}',
      registrableDomain: registrableDomain,
      canonicalUrl: canonicalUrl,
      canonicalUtf8Length: byteLength,
    );
  }

  static int _bucket(String value, int bucketCount) {
    final bytes = sha256.convert(utf8.encode(value)).bytes;
    final prefix =
        bytes[0] * 0x1000000 + bytes[1] * 0x10000 + bytes[2] * 0x100 + bytes[3];
    return prefix % bucketCount;
  }

  static String _letters(int value) {
    return String.fromCharCodes([
      65 + value ~/ (26 * 26),
      65 + (value ~/ 26) % 26,
      65 + value % 26,
    ]);
  }

  static String _canonicalize(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final asciiHost = _asciiHost(uri.host);
    final normalized = uri.normalizePath();
    final path = normalized.path.isEmpty ? '/' : normalized.path;
    final includePort =
        uri.hasPort &&
        !((scheme == 'http' && uri.port == 80) ||
            (scheme == 'https' && uri.port == 443));

    return Uri(
      scheme: scheme,
      host: asciiHost,
      port: includePort ? uri.port : null,
      path: path,
      query: normalized.hasQuery ? normalized.query : null,
      fragment: normalized.hasFragment ? normalized.fragment : null,
    ).toString();
  }

  static String _asciiHost(String host) {
    final decoded = Uri.decodeComponent(host).replaceFirst(RegExp(r'\.$'), '');
    if (decoded.contains(':')) return decoded.toLowerCase();
    return domainToAscii(decoded).toLowerCase();
  }
}
