import 'package:dali_qr/features/lookup/domain/gs1_digital_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = Gs1DigitalLinkParser();
  const base = 'https://example.com/01/09520123456788';
  test('GTIN and ordered qualifiers are parsed without changing the URI', () {
    const raw = '$base/22/2A/10/ABC%2F123/21/S%252F1?17=261200';
    final link = parser.parse(raw)!;
    expect(link.originalValue, raw);
    expect(link.gtin, '09520123456788');
    expect(link.fields, {
      '22': '2A',
      '10': 'ABC/123',
      '21': 'S%2F1',
      '17': '261200',
    });
    expect(() => link.fields['10'] = 'changed', throwsUnsupportedError);
  });
  test('qualifier subsets, prefix paths, and trailing slash are supported', () {
    for (final raw in [
      base,
      '$base/',
      '$base/21/123',
      '$base/10/LOT/',
      'http://example.com/products$base'.replaceFirst(
        base,
        '/01/09520123456788',
      ),
    ]) {
      expect(parser.parse(raw), isNotNull, reason: raw);
    }
  });
  test(
    'malformed, ambiguous, unsupported and credentialed links fall back',
    () {
      for (final raw in [
        '$base/21/S/10/L',
        '$base/10/A/10/B',
        '$base/10',
        '$base/10/',
        '$base/99/X',
        '$base?17=261231&17=261231',
        '$base?foo=bar',
        '$base?10=LOT',
        '$base?17=',
        '$base?17=261332',
        '$base?17=260431',
        '$base?17=260229',
        '$base#fragment',
        '$base/10/%00',
        '$base/10/%ZZ',
        '$base/10/%E9',
        '$base/10/%23',
        '$base/10/%20',
        '$base/10/../21/S',
        '$base/10/%2e%2e',
        '$base/10/${'a' * 21}',
        '$base/10/é',
        'https://example.com/01/09520123456789',
        'https://example.com/01/9520123456788',
        'https://example.com/gtin/09520123456788',
        'https://example.com/a/../01/09520123456788',
        'https://user:secret@example.com/01/09520123456788',
        'ftp://example.com/01/09520123456788',
        ' $base',
        '$base\\10\\LOT',
      ]) {
        expect(parser.parse(raw), isNull, reason: raw);
      }
    },
  );
  test('all supported XCHAR symbols decode exactly once', () {
    const symbols = '''!"%&'()*+,-./:;<=>?_''';
    expect(symbols.length, 20);
    expect(
      parser.parse('$base/10/${Uri.encodeComponent(symbols)}')!.fields['10'],
      symbols,
    );
  });
  test(
    'raw expiry supports month-only and leap day without a century claim',
    () {
      for (final expiry in ['261200', '280229', '000229', '991231']) {
        expect(parser.parse('$base?17=$expiry')!.fields['17'], expiry);
      }
    },
  );
}
