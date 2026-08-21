import 'package:dali_qr/features/create/domain/qr_creation_payload_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = QrCreationPayloadPolicy();

  test('accepts common non-web payloads without changing them', () {
    const payloads = [
      'plain text',
      'mailto:support@example.com',
      'tel:+14255551212',
      'sms:+14255551212?body=Hello',
      'geo:47.6101,-122.2015',
      'WIFI:T:WPA;S:GuestNetwork;P:password123;;',
      'BEGIN:VCARD\nVERSION:3.0\nFN:John Smith\nEND:VCARD',
      'BEGIN:VEVENT\nSUMMARY:Meeting\nEND:VEVENT',
      'someapp://resource/123',
    ];

    for (final payload in payloads) {
      final result = policy.validate(payload);
      expect(result.value, payload, reason: payload);
      expect(result.webUrl, isNull, reason: payload);
    }
  });

  test('recognizes and trims valid web URLs for verification', () {
    final result = policy.validate('  https://example.com/path  ');

    expect(result.value, 'https://example.com/path');
    expect(result.webUrl?.uri.host, 'example.com');
  });

  test('keeps malformed URL-like content unverified', () {
    final result = policy.validate('https:///missing-host');

    expect(result.value, 'https:///missing-host');
    expect(result.webUrl, isNull);
  });

  test('rejects empty and oversized content', () {
    expect(
      () => policy.validate(' \n '),
      throwsA(
        isA<QrCreationPayloadValidationException>().having(
          (error) => error.error,
          'error',
          QrCreationPayloadError.empty,
        ),
      ),
    );
    expect(
      () => policy.validate('a' * 2001),
      throwsA(
        isA<QrCreationPayloadValidationException>().having(
          (error) => error.error,
          'error',
          QrCreationPayloadError.tooLong,
        ),
      ),
    );
  });
}
