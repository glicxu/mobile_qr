import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classifier = QrPayloadClassifier();

  test('classifies standard URI actions', () {
    final fixtures = {
      'https://example.com/path': QrRouteAction.openUrl,
      'mailto:support@example.com?subject=Help': QrRouteAction.composeEmail,
      'tel:+14255551212': QrRouteAction.call,
      'sms:+14255551212?body=Hello': QrRouteAction.composeSms,
      'geo:47.6101,-122.2015': QrRouteAction.openLocation,
    };

    for (final fixture in fixtures.entries) {
      expect(classifier.classify(fixture.key).action, fixture.value);
    }
  });

  test('parses escaped Wi-Fi values', () {
    final result = classifier.classify(
      r'WIFI:T:WPA;S:Guest\;Network;P:pass\;word;H:true;;',
    );

    expect(result.type, QrContentType.wifi);
    expect(result.primaryText, 'Guest;Network');
    expect(result.details, isNot(contains('Password: pass;word')));
    expect(result.sensitiveLabel, 'Password');
    expect(result.sensitiveValue, 'pass;word');
    expect(result.action, QrRouteAction.configureWifi);
  });

  test('parses vCard preview and route arguments', () {
    final result = classifier.classify(
      'BEGIN:VCARD\nVERSION:3.0\nFN:John Smith\n'
      'TEL:+14255551212\nEMAIL:john@example.com\nEND:VCARD',
    );

    expect(result.type, QrContentType.contact);
    expect(result.primaryText, 'John Smith');
    expect(result.routeArguments['phone'], '+14255551212');
    expect(result.routeArguments['email'], 'john@example.com');
  });

  test('parses calendar event details', () {
    final result = classifier.classify(
      'BEGIN:VEVENT\nSUMMARY:Sunday Service\n'
      'DTSTART:20260823T100000\nDTEND:20260823T113000\nEND:VEVENT',
    );

    expect(result.type, QrContentType.calendarEvent);
    expect(result.primaryText, 'Sunday Service');
    expect(result.routeArguments['startMillis'], isA<int>());
  });

  test('does not route unknown custom schemes', () {
    final result = classifier.classify('someapp://resource/123');

    expect(result.type, QrContentType.deepLink);
    expect(result.canRoute, isFalse);
  });

  test('plain text remains display-only', () {
    final result = classifier.classify('Meeting room access code: 839274');

    expect(result.type, QrContentType.text);
    expect(result.canRoute, isFalse);
  });

  test('malformed structured payloads fail closed', () {
    expect(classifier.classify('WIFI:T:WPA;P:secret;;').canRoute, isFalse);
    expect(
      classifier.classify('BEGIN:VCARD\nVERSION:3.0\nEND:VCARD').canRoute,
      isFalse,
    );
    expect(
      classifier.classify('BEGIN:VEVENT\nSUMMARY:No date\nEND:VEVENT').canRoute,
      isFalse,
    );
  });

  test('component words embedded in text are not treated as payloads', () {
    final result = classifier.classify('Notes: BEGIN:VCARD is a marker');

    expect(result.type, QrContentType.text);
    expect(result.canRoute, isFalse);
  });

  test('preserves Unicode fields exactly', () {
    final result = classifier.classify(
      'BEGIN:VCARD\nVERSION:3.0\nFN:José 東京\nEND:VCARD',
    );

    expect(result.primaryText, 'José 東京');
    expect(result.routeArguments['name'], 'José 東京');
  });
}
