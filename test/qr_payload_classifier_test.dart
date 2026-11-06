import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classifier = QrPayloadClassifier();

  test(
    'recognizes passkey requests without exposing session data in preview',
    () {
      for (final raw in ['FIDO:/1234567890', 'fido:/1234567890']) {
        final result = classifier.classify(raw);
        expect(result.type, QrContentType.passkey);
        expect(result.action, QrRouteAction.authenticatePasskey);
        expect(result.rawPayload, raw);
        expect(result.primaryText, isNot(contains('1234567890')));
      }
      for (final raw in [
        'FIDO:/',
        'FIDO://123',
        'FIDO:/12?x=3',
        'FIDO:/123\n',
        'FIDO:/abc',
      ]) {
        expect(classifier.classify(raw).canRoute, isFalse, reason: raw);
      }
    },
  );

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

  test('ambiguous Wi-Fi fields and incomplete escapes remain display-only', () {
    for (final raw in [
      'WIFI:S:First;S:Second;;',
      'WIFI:S:Guest;P:first;P:second;;',
      'WIFI:S:Guest;broken;;',
      'WIFI:S:Guest;P:unfinished\\',
      r'WIFI:S:Guest;P:bad\q;;',
    ]) {
      final result = classifier.classify(raw);
      expect(result.type, QrContentType.wifi, reason: raw);
      expect(result.sensitiveValue, raw);
      expect(result.rawPayload, raw);
      expect(result.canRoute, isFalse);
    }
    // Percent signs in Wi-Fi credentials are data, not URI escapes.
    expect(
      classifier.classify('WIFI:S:Guest;P:50%secret;;').sensitiveValue,
      '50%secret',
    );
  });

  test('incomplete, concatenated, or nested components remain display-only', () {
    for (final raw in [
      'BEGIN:VCARD\nFN:Jane',
      'Preamble\nBEGIN:VCARD\nFN:Jane\nEND:VCARD',
      'BEGIN:VCARD\nFN:Jane\nEND:VCARD\nBEGIN:VCARD\nFN:John\nEND:VCARD',
      'BEGIN:VCARD\nFN:Jane\nFN:John\nEND:VCARD',
      'BEGIN:VEVENT\nDTSTART:20261029T100000\nBEGIN:VALARM\nEND:VALARM\nEND:VEVENT',
    ]) {
      final result = classifier.classify(raw);
      expect(result.type, QrContentType.text, reason: raw);
      expect(result.canRoute, isFalse);
      expect(result.rawPayload, raw);
    }
    expect(
      classifier.classify('BEGIN:VCARD\nTEL:\nEMAIL: \nEND:VCARD').canRoute,
      isFalse,
    );
  });

  test('impossible dates and unsupported calendar semantics do not route', () {
    for (final fields in [
      'DTSTART:20260230T100000',
      'DTSTART:20261029T250000',
      'DTSTART:20261029Z',
      'DTSTART;TZID=America/New_York:20261029T100000',
      'DTSTART;TZI\n D=America/New_York:20261029T100000',
      'DTSTART:20261029T100000\nDTSTART:20261030T100000',
      'DTSTART:20261029T100000\nDTEND:20261028T100000',
      'DTSTART:20261029T100000\nDTEND:invalid',
      'DTSTART:20261029T100000Z\nDTEND:20261029T110000',
      'DTSTART:20261029\nDTEND:20261030T100000',
      'DTSTART:20261029T100000\nRRULE:FREQ=DAILY',
      'DTSTART:20261029T100000\nDURATION:PT2H',
    ]) {
      final raw = 'BEGIN:VEVENT\n$fields\nEND:VEVENT';
      expect(classifier.classify(raw).canRoute, isFalse, reason: raw);
    }
  });

  test(
    'a single wrapped UTC event and folded contact names remain supported',
    () {
      final event = classifier.classify(
        'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\n'
        'DTSTART:20261029T100000Z\nDTEND:20261029T110000Z\nEND:VEVENT\nEND:VCALENDAR',
      );
      expect(event.action, QrRouteAction.addCalendarEvent);
      expect(
        event.routeArguments['startMillis'],
        DateTime.utc(2026, 10, 29, 10).millisecondsSinceEpoch,
      );
      final contact = classifier.classify(
        'BEGIN:VCARD\r\nFN:Jane\r\n  Smith\r\nEND:VCARD',
      );
      expect(contact.primaryText, 'Jane Smith');
      final escaped = classifier.classify(
        r'BEGIN:VCARD'
        '\n'
        r'FN:Literal \\n text'
        '\nEND:VCARD',
      );
      expect(escaped.primaryText, r'Literal \n text');
    },
  );

  test(
    'out-of-range and nonnumeric location coordinates remain display-only',
    () {
      for (final raw in [
        'geo:91,0',
        'geo:0,-181',
        'geo:NaN,0',
        'geo:1',
        'geo:1,2,3,4',
      ]) {
        expect(classifier.classify(raw).canRoute, isFalse, reason: raw);
      }
      expect(
        classifier.classify('geo:0,0?q=Seattle').action,
        QrRouteAction.openLocation,
      );
    },
  );
  test(
    'all-day dates are interpreted without silently creating timed events',
    () {
      final result = classifier.classify(
        'BEGIN:VEVENT\nSUMMARY:Holiday\n'
        'DTSTART;VALUE=DATE:20261225\nDTEND;VALUE=DATE:20261226\nEND:VEVENT',
      );
      expect(result.type, QrContentType.calendarEvent);
      expect(result.primaryText, 'Holiday');
      expect(
        result.details,
        contains('All-day calendar handoff is not supported.'),
      );
      expect(result.canRoute, isFalse);
      expect(result.routeArguments, isEmpty);
    },
  );
}
