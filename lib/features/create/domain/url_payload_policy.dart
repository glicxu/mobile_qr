import 'dart:convert';

enum UrlPayloadError {
  empty,
  tooLong,
  controlCharacter,
  malformed,
  unsupportedScheme,
  missingHost,
  credentials,
}

final class UrlPayloadValidationException implements Exception {
  const UrlPayloadValidationException(this.error, this.message);

  final UrlPayloadError error;
  final String message;

  @override
  String toString() => message;
}

final class ValidatedUrlPayload {
  const ValidatedUrlPayload({
    required this.value,
    required this.uri,
    required this.utf8ByteLength,
    required this.wasTrimmed,
  });

  /// The exact string that will be encoded. It is never produced by
  /// serializing [uri], because doing so could change meaningful URL syntax.
  final String value;
  final Uri uri;
  final int utf8ByteLength;
  final bool wasTrimmed;
}

final class UrlPayloadPolicy {
  const UrlPayloadPolicy({this.maxUtf8Bytes = 2000});

  final int maxUtf8Bytes;

  static final _controlCharacters = RegExp(r'[\x00-\x1F\x7F-\x9F]');
  static final _malformedPercentEscape = RegExp(r'%(?![0-9A-Fa-f]{2})');

  ValidatedUrlPayload validate(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      throw const UrlPayloadValidationException(
        UrlPayloadError.empty,
        'Enter an HTTP or HTTPS URL.',
      );
    }
    if (_controlCharacters.hasMatch(value)) {
      throw const UrlPayloadValidationException(
        UrlPayloadError.controlCharacter,
        'The URL contains a control character.',
      );
    }
    if (_malformedPercentEscape.hasMatch(value)) {
      throw const UrlPayloadValidationException(
        UrlPayloadError.malformed,
        'The URL contains an invalid percent escape.',
      );
    }

    final byteLength = utf8.encode(value).length;
    if (byteLength > maxUtf8Bytes) {
      throw UrlPayloadValidationException(
        UrlPayloadError.tooLong,
        'The URL is $byteLength bytes; the limit is $maxUtf8Bytes bytes.',
      );
    }

    final Uri uri;
    try {
      uri = Uri.parse(value);
    } on FormatException {
      throw const UrlPayloadValidationException(
        UrlPayloadError.malformed,
        'Enter a well-formed URL.',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw const UrlPayloadValidationException(
        UrlPayloadError.unsupportedScheme,
        'Only HTTP and HTTPS URLs are supported.',
      );
    }
    // Uri.isAbsolute is false when a fragment is present, even when the URL
    // has a valid absolute scheme and authority. Check those parts directly.
    if (!uri.hasAuthority || uri.host.isEmpty) {
      throw const UrlPayloadValidationException(
        UrlPayloadError.missingHost,
        'The URL must include a host.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw const UrlPayloadValidationException(
        UrlPayloadError.credentials,
        'URLs containing credentials are not supported.',
      );
    }

    return ValidatedUrlPayload(
      value: value,
      uri: uri,
      utf8ByteLength: byteLength,
      wasTrimmed: value != input,
    );
  }
}
