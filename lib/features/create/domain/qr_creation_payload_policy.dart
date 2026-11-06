import 'dart:convert';

import 'url_payload_policy.dart';
import '../../scan/domain/authenticator_payload.dart';

enum QrCreationPayloadError { empty, tooLong, sensitive }

final class QrCreationPayloadValidationException implements Exception {
  const QrCreationPayloadValidationException(this.error, this.message);

  final QrCreationPayloadError error;
  final String message;

  @override
  String toString() => message;
}

final class QrCreationPayload {
  const QrCreationPayload({
    required this.value,
    required this.utf8ByteLength,
    required this.webUrl,
  });

  final String value;
  final int utf8ByteLength;
  final ValidatedUrlPayload? webUrl;
}

final class QrCreationPayloadPolicy {
  const QrCreationPayloadPolicy({this.maxUtf8Bytes = 2000});

  final int maxUtf8Bytes;
  static const _urlPolicy = UrlPayloadPolicy();

  QrCreationPayload validate(String input) {
    if (EphemeralCodePolicy.isAuthenticator(input)) {
      throw const QrCreationPayloadValidationException(
        QrCreationPayloadError.sensitive,
        'Authenticator setup codes are scan-only. Create account setup codes through the account provider.',
      );
    }
    if (input.trim().isEmpty) {
      throw const QrCreationPayloadValidationException(
        QrCreationPayloadError.empty,
        'Enter content for the QR code.',
      );
    }

    ValidatedUrlPayload? webUrl;
    try {
      webUrl = _urlPolicy.validate(input);
    } on UrlPayloadValidationException {
      // Non-web and malformed URL-like values remain ordinary QR content.
    }
    final value = webUrl?.value ?? input;
    final byteLength = utf8.encode(value).length;
    if (byteLength > maxUtf8Bytes) {
      throw QrCreationPayloadValidationException(
        QrCreationPayloadError.tooLong,
        'The content is $byteLength bytes; the limit is $maxUtf8Bytes bytes.',
      );
    }

    return QrCreationPayload(
      value: value,
      utf8ByteLength: byteLength,
      webUrl: webUrl,
    );
  }
}
