import 'dart:convert';

import 'package:dali_qr/features/create/domain/url_payload_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/url_fixtures.dart';

void main() {
  const policy = UrlPayloadPolicy();

  group('UrlPayloadPolicy', () {
    for (final fixture in acceptedUrlFixtures) {
      test('accepts ${fixture.name} without reserializing it', () {
        final result = policy.validate(fixture.input);
        expect(result.value, fixture.expected ?? fixture.input);
        expect(result.utf8ByteLength, utf8.encode(result.value).length);
      });
    }

    test('accepts exactly 2,000 UTF-8 bytes', () {
      const prefix = 'https://example.com/';
      final input = '$prefix${'a' * (2000 - prefix.length)}';
      expect(policy.validate(input).utf8ByteLength, 2000);
    });

    test('rejects more than 2,000 UTF-8 bytes', () {
      const prefix = 'https://example.com/';
      final input = '$prefix${'a' * (2001 - prefix.length)}';
      expectValidationError(policy, input, UrlPayloadError.tooLong);
    });

    const rejected = <(String, UrlPayloadError)>[
      ('', UrlPayloadError.empty),
      ('example.com', UrlPayloadError.unsupportedScheme),
      ('ftp://example.com', UrlPayloadError.unsupportedScheme),
      ('https:///path', UrlPayloadError.missingHost),
      ('https://user:secret@example.com', UrlPayloadError.credentials),
      ('https://example.com/%ZZ', UrlPayloadError.malformed),
      ('https://example.com/\u0000', UrlPayloadError.controlCharacter),
    ];

    for (final (input, error) in rejected) {
      test('rejects $input as ${error.name}', () {
        expectValidationError(policy, input, error);
      });
    }
  });
}

void expectValidationError(
  UrlPayloadPolicy policy,
  String input,
  UrlPayloadError error,
) {
  expect(
    () => policy.validate(input),
    throwsA(
      isA<UrlPayloadValidationException>().having(
        (exception) => exception.error,
        'error',
        error,
      ),
    ),
  );
}
