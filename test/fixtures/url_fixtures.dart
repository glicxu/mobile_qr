final class UrlFixture {
  const UrlFixture(this.name, this.input, {this.expected});

  final String name;
  final String input;
  final String? expected;
}

const acceptedUrlFixtures = <UrlFixture>[
  UrlFixture('basic HTTPS', 'https://example.com/'),
  UrlFixture('HTTP with port', 'http://example.com:8080/path'),
  UrlFixture(
    'query and fragment',
    'https://example.com/search?q=qr+code&q=two#results',
  ),
  UrlFixture(
    'preserves percent escape spelling',
    'https://example.com/a%2fb?redirect=%2Fhome',
  ),
  UrlFixture('Unicode host and path', 'https://例え.テスト/資料/😀?q=雪#章'),
  UrlFixture(
    'trims only outer whitespace',
    '  https://example.com/trimmed  ',
    expected: 'https://example.com/trimmed',
  ),
];
