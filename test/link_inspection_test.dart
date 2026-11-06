import 'dart:io';

import 'package:dali_qr/features/scan/domain/link_inspection.dart';
import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const inspector = LinkInspector();

  test(
    'preserves exact destination and separates host from user information',
    () {
      const raw =
          'https://trusted.example:secret@evil.example:8443/a?x=%2f#section';
      final result = inspector.inspect(raw);
      expect(result.rawValue, raw);
      expect(result.asciiHost, 'evil.example');
      expect(result.scheme, 'https');
      expect(result.canOpen, isTrue);
      expect(result.warnings, [LinkWarning.userInfo, LinkWarning.unusualPort]);
    },
  );

  test(
    'Unicode and Punycode destinations have the same derived ASCII host',
    () {
      for (final raw in [
        'https://bücher.example/',
        'https://xn--bcher-kva.example/',
      ]) {
        final result = inspector.inspect(raw);
        expect(result.rawValue, raw);
        expect(result.asciiHost, 'xn--bcher-kva.example');
        expect(result.warnings, contains(LinkWarning.internationalizedHost));
        expect(result.canOpen, isTrue);
      }
    },
  );

  test('HTTP, nondefault ports, and numeric addresses get local warnings', () {
    final result = inspector.inspect('http://127.0.0.1:8080/test');
    expect(result.canOpen, isTrue);
    expect(result.warnings, [
      LinkWarning.http,
      LinkWarning.unusualPort,
      LinkWarning.numericHost,
    ]);
    expect(inspector.inspect('https://example.com:443/').warnings, isEmpty);
    expect(inspector.inspect('https://[::1]/').canOpen, isTrue);
    expect(
      inspector.inspect('http://2130706433/').warnings,
      contains(LinkWarning.numericHost),
    );
  });

  test(
    'malformed and ambiguous links stay inert without changing contents',
    () {
      for (final raw in [
        'https:example.com',
        'https:///path',
        'https://',
        'https://example.com/%ZZ',
        'https://example.com/has space',
        'https://example.com/\nnext',
        'https://example.com/\u202eevil',
        r'https://example.com\@evil.example/',
        'https://example.com:65536/',
        'https://example.com:0/',
        'https://example.com:invalid/',
        'https://bad..example/',
        'https://[invalid]/',
        'https://xn--/',
        'https://%ff.example/',
      ]) {
        final result = inspector.inspect(raw);
        expect(result.rawValue, raw);
        expect(result.canOpen, isFalse, reason: raw);
        expect(result.problem, isNotNull, reason: raw);
        final classified = const QrPayloadClassifier().classify(raw);
        expect(classified.type, QrContentType.text, reason: raw);
        expect(classified.canRoute, isFalse, reason: raw);
      }
    },
  );

  test('unknown and executable schemes never acquire an open action', () {
    for (final raw in [
      'javascript:alert(1)',
      'file:///private/data',
      'someapp://account',
    ]) {
      expect(inspector.inspect(raw).canOpen, isFalse);
      final payload = const QrPayloadClassifier().classify(raw);
      expect(payload.canRoute, isFalse);
      expect(payload.linkInspection?.rawValue, raw);
    }
  });

  test('inspection and interpretation never create an HTTP client', () {
    HttpOverrides.runZoned(() {
      for (final raw in ['https://example.com/', 'http://localhost/']) {
        expect(inspector.inspect(raw).canOpen, isTrue);
        expect(const QrPayloadClassifier().classify(raw).canRoute, isTrue);
      }
    }, createHttpClient: (_) => throw StateError('Unexpected network access'));
  });
}
