import 'dart:convert';
import 'dart:math';

import 'package:punycoder/punycoder.dart';

enum QrCreationType { text, wifi, contact, event, location, email, phone, sms }

extension QrCreationTypeLabel on QrCreationType {
  String get label => switch (this) {
    QrCreationType.text => 'Text or link',
    QrCreationType.wifi => 'Wi-Fi network',
    QrCreationType.contact => 'Contact',
    QrCreationType.event => 'Event',
    QrCreationType.location => 'Location',
    QrCreationType.email => 'Email',
    QrCreationType.phone => 'Phone',
    QrCreationType.sms => 'SMS',
  };
}

/// Inputs are literal values, never pre-escaped protocol fragments.
final class StructuredQrDraft {
  const StructuredQrDraft({
    required this.type,
    this.fields = const {},
    this.start,
    this.end,
    this.useUtc = false,
  });
  final QrCreationType type;
  final Map<String, String> fields;
  final DateTime? start;
  final DateTime? end;
  final bool useUtc;

  String _field(String key, {bool required = false, bool multiline = false}) {
    final value = fields[key] ?? '';
    if (value.length > 2000 || utf8.encode(value).length > 2000) {
      throw FormatException('The $key is too long for a QR code.');
    }
    if (required && value.trim().isEmpty) throw FormatException('Enter $key.');
    final controls = multiline
        ? RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]')
        : RegExp(r'[\x00-\x1f\x7f-\x9f]');
    if (controls.hasMatch(value) || utf8.decode(utf8.encode(value)) != value) {
      throw FormatException('The $key contains an unsupported character.');
    }
    return value;
  }

  String encode() => switch (type) {
    QrCreationType.contact => _contact(),
    QrCreationType.event => _event(),
    QrCreationType.location => _location(),
    QrCreationType.email => _email(),
    QrCreationType.phone => 'tel:${_phone(_field('phone', required: true))}',
    QrCreationType.sms => _sms(),
    _ => throw const FormatException('Choose a structured QR type.'),
  };

  String _contact() {
    final name = _field('name', required: true);
    final phone = _field('phone');
    final email = _field('email');
    if (phone.isNotEmpty) _phone(phone);
    if (email.isNotEmpty) _address(email);
    return _lines([
      'BEGIN:VCARD',
      'VERSION:3.0',
      'N:;${_text(name)};;;',
      'FN:${_text(name)}',
      if (phone.isNotEmpty) 'TEL:${_phone(phone)}',
      if (email.isNotEmpty) 'EMAIL:${_text(_address(email))}',
      'END:VCARD',
    ]);
  }

  String _event() {
    final title = _field('title', required: true);
    final location = _field('location');
    final description = _field('description', multiline: true);
    if (start == null || end == null) {
      throw const FormatException('Choose a start and end date and time.');
    }
    DateTime wallTime(DateTime d) => useUtc
        ? DateTime.utc(d.year, d.month, d.day, d.hour, d.minute)
        : DateTime(d.year, d.month, d.day, d.hour, d.minute);
    final from = wallTime(start!);
    final to = wallTime(end!);
    if (!to.isAfter(from) || from.year < 1 || to.year > 9999) {
      throw const FormatException('The event must end after it starts.');
    }
    // Reject local daylight-saving gaps rather than silently shifting the time.
    if (from.hour != start!.hour ||
        from.minute != start!.minute ||
        to.hour != end!.hour ||
        to.minute != end!.minute) {
      throw const FormatException(
        'This local time does not exist. Choose another time or UTC.',
      );
    }
    final random = Random.secure();
    final uid = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return _lines([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Dali QR//Event//EN',
      'BEGIN:VEVENT',
      'UID:$uid@dali-qr.local',
      'DTSTAMP:${_date(DateTime.now().toUtc())}',
      'DTSTART:${_date(from)}',
      'DTEND:${_date(to)}',
      'SUMMARY:${_text(title)}',
      if (location.isNotEmpty) 'LOCATION:${_text(location)}',
      if (description.isNotEmpty) 'DESCRIPTION:${_text(description)}',
      'END:VEVENT',
      'END:VCALENDAR',
    ]);
  }

  String _location() {
    final latitude = _field('latitude', required: true);
    final longitude = _field('longitude', required: true);
    final number = RegExp(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$');
    final lat = double.tryParse(latitude);
    final lon = double.tryParse(longitude);
    if (!number.hasMatch(latitude) ||
        !number.hasMatch(longitude) ||
        lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      throw const FormatException(
        'Enter latitude from −90 to 90 and longitude from −180 to 180, using a decimal point.',
      );
    }
    String decimal(String value, int limit) {
      final negative = value.startsWith('-');
      final parts = value.replaceFirst(RegExp(r'^[+-]'), '').split('.');
      var whole = parts.first.replaceFirst(RegExp(r'^0+'), '');
      if (whole.isEmpty) whole = '0';
      final fraction = parts.length == 2
          ? (parts.last.isEmpty ? '0' : parts.last)
          : null;
      // Check exact boundary decimals, including values that double rounds
      // back onto 90/180. Keep fractional precision in the generated URI.
      if (int.parse(whole) == limit &&
          fraction != null &&
          RegExp(r'[1-9]').hasMatch(fraction)) {
        throw const FormatException(
          'Coordinates are outside the latitude/longitude bounds.',
        );
      }
      return '${negative ? '-' : ''}$whole${fraction == null ? '' : '.$fraction'}';
    }

    return 'geo:${decimal(latitude, 90)},${decimal(longitude, 180)}';
  }

  String _email() {
    final address = _address(_field('email', required: true));
    final subject = _field('subject');
    final body = _field('body', multiline: true);
    final parts = address.split('@');
    // Percent-encode literal '%' and URI delimiters; spaces must be %20, not '+'.
    return 'mailto:${Uri.encodeComponent(parts[0])}@${parts[1]}${_query({if (subject.isNotEmpty) 'subject': subject, if (body.isNotEmpty) 'body': body.replaceAll(RegExp(r'\r\n|\r|\n'), '\r\n')})}';
  }

  String _sms() {
    final phone = _phone(_field('phone', required: true));
    final body = _field('body', multiline: true);
    return 'sms:$phone${_query({if (body.isNotEmpty) 'body': body})}';
  }

  static String _query(Map<String, String> values) => values.isEmpty
      ? ''
      : '?${values.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

  static String _phone(String value) {
    // One number only. Do not accept service codes, URI parameters or extensions.
    if (!RegExp(r'^\+?[0-9][0-9 ()\-.]*[0-9]$|^\+?[0-9]$').hasMatch(value) ||
        value.length > 64) {
      throw const FormatException(
        'Enter one phone number using digits and an optional leading +. Extensions and service codes are not supported.',
      );
    }
    return value.replaceAll(RegExp(r'[ ()\-.]'), '');
  }

  static String _address(String value) {
    final parts = value.split('@');
    if (parts.length != 2 ||
        parts[0].isEmpty ||
        parts[0].length > 64 ||
        !RegExp(r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~.\-]+$").hasMatch(parts[0]) ||
        parts[0].startsWith('.') ||
        parts[0].endsWith('.') ||
        parts[0].contains('..')) {
      throw const FormatException(
        'Enter one email address without a display name.',
      );
    }
    final domain = domainToAscii(parts[1]);
    if (domain.isEmpty ||
        domain.length > 253 ||
        domain
            .split('.')
            .any(
              (label) =>
                  label.isEmpty ||
                  label.length > 63 ||
                  !RegExp(
                    r'^[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?$',
                  ).hasMatch(label),
            )) {
      throw const FormatException('Enter a valid email domain.');
    }
    final address = '${parts[0]}@$domain';
    if (utf8.encode(address).length > 254) {
      throw const FormatException('The email address is too long.');
    }
    return address;
  }

  static String _text(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');

  static String _date(DateTime value) {
    String pad(int n, [int size = 2]) => n.toString().padLeft(size, '0');
    return '${pad(value.year, 4)}${pad(value.month)}${pad(value.day)}T${pad(value.hour)}${pad(value.minute)}${pad(value.second)}${value.isUtc ? 'Z' : ''}';
  }

  static String _lines(List<String> lines) =>
      '${lines.map(_fold).join('\r\n')}\r\n';
  static String _fold(String line) {
    final out = StringBuffer();
    var width = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      final size = utf8.encode(char).length;
      if (width + size > 75) {
        out.write('\r\n ');
        width = 1;
      }
      out.write(char);
      width += size;
    }
    return out.toString();
  }
}
