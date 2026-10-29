import 'dart:io';

import 'package:dali_qr/features/create/domain/url_payload_policy.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = SecureQrService(
    PublicSuffixList.parse('''
com
uk
co.uk
io
github.io
ck
*.ck
!www.ck
cn
'''),
  );

  test('never assigns comparison codes to passkey requests', () {
    expect(service.calculateForPayload('FIDO:/1234567890'), isNull);
    expect(service.calculateForPayload('fido:/invalid'), isNull);
  });

  test('produces fixed Secure QR v1 vectors', () {
    final cases = <String, String>{
      'https://example.com/': 'XIH-000',
      'https://pay.example.com/parking?id=8472': 'XIH-955',
      'https://example.co.uk/document/123': 'KNM-485',
      'https://alice.github.io/pay': 'RDG-731',
      'https://你好.cn/': 'FVV-217',
    };

    for (final entry in cases.entries) {
      expect(service.calculate(entry.key).code, entry.value, reason: entry.key);
    }
  });

  test('canonicalizes equivalent URLs to the same code', () {
    final first = service.calculate(
      'HTTPS://Pay.Example.COM:443/a/../parking?id=7',
    );
    final second = service.calculate('https://pay.example.com/parking?id=7');

    expect(first.canonicalUrl, 'https://pay.example.com/parking?id=7');
    expect(first.code, second.code);
  });

  test('uses eTLD+1 and private PSL rules', () {
    expect(
      service.calculate('https://pay.example.co.uk/').registrableDomain,
      'example.co.uk',
    );
    expect(
      service.calculate('https://alice.github.io/').registrableDomain,
      'alice.github.io',
    );
    expect(
      service.calculate('https://bob.github.io/').registrableDomain,
      'bob.github.io',
    );
  });

  test('implements PSL wildcard and exception rules', () {
    final suffixes = PublicSuffixList.parse('''
ck
*.ck
!www.ck
''');

    expect(suffixes.registrableDomain('a.b.ck'), 'a.b.ck');
    expect(suffixes.registrableDomain('www.ck'), 'www.ck');
  });

  test('domain letters are stable across subdomains', () {
    final root = service
        .calculate('https://example.com/a')
        .code
        .substring(0, 3);
    final subdomain = service
        .calculate('https://pay.example.com/b')
        .code
        .substring(0, 3);

    expect(subdomain, root);
  });

  test('does not verify URLs without a registrable domain', () {
    const payloads = [
      'http://192.0.2.10/pay',
      'http://[2001:db8::1]/pay',
      'http://localhost/pay',
    ];

    for (final payload in payloads) {
      expect(
        () => service.calculate(payload),
        throwsA(isA<UrlPayloadValidationException>()),
        reason: payload,
      );
    }
  });

  test('domain algorithm rejects non-web payload types', () {
    const payloads = [
      'plain text',
      'WIFI:T:WPA;S:Example;P:secret;;',
      '+1-555-0100',
      'tel:+15550100',
      'person@example.com',
      'mailto:person@example.com',
      'geo:37.786971,-122.399677',
      'bitcoin:bc1qexample',
      'myapp://open/item/42',
    ];

    for (final payload in payloads) {
      expect(
        () => service.calculate(payload),
        throwsA(isA<UrlPayloadValidationException>()),
        reason: payload,
      );
    }
  });

  test('produces fixed content comparison code vectors', () {
    const cases = <String, String>{
      'plain text': '010-XWM',
      'WIFI:T:WPA;S:GuestNetwork;P:password123;;': '041-AVZ',
      '你好': '006-CWB',
    };

    for (final entry in cases.entries) {
      final result = service.calculateForPayload(entry.key);
      expect(result, isA<ContentQrResult>(), reason: entry.key);
      expect(result?.code, entry.value, reason: entry.key);
    }
  });

  test('keeps domain and content code formats visibly distinct', () {
    expect(
      service.calculateForPayload('https://example.com/')?.code,
      matches(RegExp(r'^[A-Z]{3}-[0-9]{3}$')),
    );
    expect(
      service.calculateForPayload('example content')?.code,
      matches(RegExp(r'^[0-9]{3}-[A-Z]{3}$')),
    );
  });

  test('uses the length modulo 1000 for long content', () {
    final result = service.calculateForPayload('a' * 1005);
    expect(result?.code, startsWith('005-'));
  });

  test('bundled PSL includes multi-label and private suffixes', () async {
    final source = await File('assets/public_suffix_list.dat').readAsString();
    final bundledService = SecureQrService(PublicSuffixList.parse(source));

    expect(
      bundledService.calculate('https://pay.example.co.uk/').registrableDomain,
      'example.co.uk',
    );
    expect(
      bundledService.calculate('https://alice.github.io/').registrableDomain,
      'alice.github.io',
    );
  });
}
