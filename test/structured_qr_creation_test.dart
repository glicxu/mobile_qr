import 'dart:convert';
import 'dart:io';

import 'package:dali_qr/features/create/domain/structured_qr_payload.dart';
import 'package:dali_qr/features/create/data/dart_qr_encoder.dart';
import 'package:dali_qr/features/create/data/qr_png_renderer.dart';
import 'package:dali_qr/features/create/application/qr_png_validator.dart';
import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'coordinate input emits RFC decimal syntax without losing precision',
    () {
      expect(
        const StructuredQrDraft(
          type: QrCreationType.location,
          fields: {'latitude': '+.500', 'longitude': '-000.0'},
        ).encode(),
        'geo:0.500,-0.0',
      );
      expect(
        () => const StructuredQrDraft(
          type: QrCreationType.location,
          fields: {'latitude': '90.000000000000000001', 'longitude': '0'},
        ).encode(),
        throwsFormatException,
      );
    },
  );
  const classifier = QrPayloadClassifier();
  final samples = <(StructuredQrDraft, QrContentType, QrRouteAction)>[
    (
      const StructuredQrDraft(
        type: QrCreationType.contact,
        fields: {
          'name': 'Léa; Ops, Team\\QA',
          'phone': '+1 (555) 010-0001',
          'email': 'lea+qr@example.com',
        },
      ),
      QrContentType.contact,
      QrRouteAction.addContact,
    ),
    (
      StructuredQrDraft(
        type: QrCreationType.event,
        fields: {
          'title': 'Meet; review, plan\\next',
          'location': 'Room 2; East',
          'description': 'Line one\nLine two ✓',
        },
        start: DateTime.utc(2027, 2, 20, 12, 30),
        end: DateTime.utc(2027, 2, 20, 13, 30),
        useUtc: true,
      ),
      QrContentType.calendarEvent,
      QrRouteAction.addCalendarEvent,
    ),
    (
      const StructuredQrDraft(
        type: QrCreationType.location,
        fields: {'latitude': '-33.8600', 'longitude': '151.2100'},
      ),
      QrContentType.location,
      QrRouteAction.openLocation,
    ),
    (
      const StructuredQrDraft(
        type: QrCreationType.email,
        fields: {
          'email': 'qa+demo%tag@example.com',
          'subject': 'A+B & 100% ✓',
          'body': 'Line one\nLine two + & # ? %',
        },
      ),
      QrContentType.email,
      QrRouteAction.composeEmail,
    ),
    (
      const StructuredQrDraft(
        type: QrCreationType.phone,
        fields: {'phone': '+1 (555) 010-0001'},
      ),
      QrContentType.phone,
      QrRouteAction.call,
    ),
    (
      const StructuredQrDraft(
        type: QrCreationType.sms,
        fields: {
          'phone': '+1 (555) 010-0001',
          'body': 'Meet + & # ? % ✓\nTomorrow',
        },
      ),
      QrContentType.sms,
      QrRouteAction.composeSms,
    ),
  ];
  final manifest = <Map<String, String>>[];
  for (final (draft, type, action) in samples) {
    test(
      '${draft.type.name}: generated PNG preserves payload and native fields',
      () {
        final raw = draft.encode();
        final png = const QrPngRenderer().render(
          const DartQrEncoder().encode(raw),
        );
        expect(
          const QrPngValidator().containsExactPayload(png.bytes, raw),
          isTrue,
        );
        final parsed = classifier.classify(raw);
        expect(parsed.type, type);
        expect(parsed.action, action);
        switch (draft.type) {
          case QrCreationType.contact:
            expect(parsed.routeArguments, {
              'name': 'Léa; Ops, Team\\QA',
              'phone': '+15550100001',
              'email': 'lea+qr@example.com',
            });
          case QrCreationType.event:
            expect(parsed.routeArguments, {
              'title': 'Meet; review, plan\\next',
              'location': 'Room 2; East',
              'description': 'Line one\nLine two ✓',
              'startMillis': DateTime.utc(
                2027,
                2,
                20,
                12,
                30,
              ).millisecondsSinceEpoch,
              'endMillis': DateTime.utc(
                2027,
                2,
                20,
                13,
                30,
              ).millisecondsSinceEpoch,
            });
          case QrCreationType.location:
            expect(raw, 'geo:-33.8600,151.2100');
          case QrCreationType.email:
            expect(
              Uri.decodeComponent(parsed.launchUri!.path),
              'qa+demo%tag@example.com',
            );
            expect(parsed.primaryText, 'qa+demo%tag@example.com');
            expect(parsed.launchUri!.queryParameters, {
              'subject': 'A+B & 100% ✓',
              'body': 'Line one\r\nLine two + & # ? %',
            });
            expect(raw, contains('qa%2Bdemo%25tag@'));
            expect(raw, contains('A%2BB%20%26%20100%25'));
          case QrCreationType.phone:
            expect(raw, 'tel:+15550100001');
          case QrCreationType.sms:
            expect(parsed.launchUri!.path, '+15550100001');
            expect(parsed.launchUri!.queryParameters, {
              'body': 'Meet + & # ? % ✓\nTomorrow',
            });
          default:
            fail('Unexpected structured type');
        }
        final directory = Directory('.dart_tool/structured-qr-qa')
          ..createSync(recursive: true);
        final file = '${draft.type.name}.png';
        File('${directory.path}/$file').writeAsBytesSync(png.bytes);
        manifest.add({'type': draft.type.name, 'file': file, 'payload': raw});
        File(
          '${directory.path}/manifest.json',
        ).writeAsStringSync(jsonEncode(manifest));
      },
    );
  }
  test('invalid or injectable fields cannot generate actionable payloads', () {
    for (final draft in [
      StructuredQrDraft(
        type: QrCreationType.contact,
        fields: {'name': 'A' * 2001},
      ),
      const StructuredQrDraft(
        type: QrCreationType.contact,
        fields: {'name': 'A\nTEL:911'},
      ),
      const StructuredQrDraft(
        type: QrCreationType.email,
        fields: {'email': 'a@example.com?bcc=x@example.com'},
      ),
      const StructuredQrDraft(
        type: QrCreationType.email,
        fields: {
          'email': 'a@example.com',
          'subject': 'Hi\r\nBcc: x@example.com',
        },
      ),
      const StructuredQrDraft(
        type: QrCreationType.email,
        fields: {'email': 'a..b@example.com'},
      ),
      const StructuredQrDraft(
        type: QrCreationType.phone,
        fields: {'phone': '*123#'},
      ),
      const StructuredQrDraft(
        type: QrCreationType.sms,
        fields: {'phone': '+1555?body=wrong'},
      ),
      const StructuredQrDraft(
        type: QrCreationType.location,
        fields: {'latitude': 'NaN', 'longitude': '0'},
      ),
      const StructuredQrDraft(
        type: QrCreationType.location,
        fields: {'latitude': '90.01', 'longitude': '180'},
      ),
      const StructuredQrDraft(
        type: QrCreationType.location,
        fields: {'latitude': '0', 'longitude': '181'},
      ),
      const StructuredQrDraft(
        type: QrCreationType.event,
        fields: {'title': 'Meeting'},
      ),
      StructuredQrDraft(
        type: QrCreationType.event,
        fields: const {'title': 'Meeting'},
        start: DateTime(2027),
        end: DateTime(2026),
      ),
    ]) {
      expect(
        draft.encode,
        throwsFormatException,
        reason: '${draft.type} must reject invalid inputs',
      );
    }
  });
  test('UTF-8 content lines fold without breaking fields or characters', () {
    final name = 'Élodie 😀; Team, \\' * 12;
    final raw = StructuredQrDraft(
      type: QrCreationType.contact,
      fields: {'name': name},
    ).encode();
    expect(
      raw.split('\r\n').every((line) => utf8.encode(line).length <= 75),
      isTrue,
    );
    expect(classifier.classify(raw).routeArguments['name'], name);
  });
  test('local and UTC event wall times have explicit distinct semantics', () {
    final local = StructuredQrDraft(
      type: QrCreationType.event,
      fields: const {'title': 'Local meeting'},
      start: DateTime.utc(2027, 3, 2, 9),
      end: DateTime.utc(2027, 3, 2, 10),
    ).encode();
    expect(local, contains('DTSTART:20270302T090000\r\n'));
    expect(
      classifier.classify(local).routeArguments['startMillis'],
      DateTime(2027, 3, 2, 9).millisecondsSinceEpoch,
    );
    expect(local, contains('UID:'));
    expect(local, contains('DTSTAMP:'));
  });
}
