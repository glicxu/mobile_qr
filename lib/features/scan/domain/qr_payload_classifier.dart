import 'link_inspection.dart';
import 'authenticator_payload.dart';

enum QrContentType {
  webUrl,
  email,
  phone,
  sms,
  location,
  wifi,
  contact,
  calendarEvent,
  deepLink,
  text,
  passkey,
  authenticator,
}

enum QrRouteAction {
  openUrl,
  composeEmail,
  call,
  composeSms,
  openLocation,
  configureWifi,
  addContact,
  addCalendarEvent,
  openDeepLink,
  none,
  authenticatePasskey,
  setupAuthenticator,
}

final class ClassifiedQrPayload {
  const ClassifiedQrPayload({
    required this.rawPayload,
    required this.type,
    required this.action,
    required this.title,
    required this.primaryText,
    this.details = const [],
    this.launchUri,
    this.routeArguments = const {},
    this.sensitiveLabel,
    this.sensitiveValue,
    this.linkInspection,
  });

  final String rawPayload;
  final QrContentType type;
  final QrRouteAction action;
  final String title;
  final String primaryText;
  final List<String> details;
  final Uri? launchUri;
  final Map<String, Object?> routeArguments;
  final String? sensitiveLabel;
  final String? sensitiveValue;
  final LinkInspection? linkInspection;

  bool get canRoute => action != QrRouteAction.none;
  bool get isEphemeral =>
      type == QrContentType.passkey || type == QrContentType.authenticator;
  String get previewText => isEphemeral || sensitiveValue != null
      ? '$title: $primaryText'
      : rawPayload;
}

final class QrPayloadClassifier {
  const QrPayloadClassifier();

  ClassifiedQrPayload classify(String raw) {
    if (EphemeralCodePolicy.isAuthenticator(raw)) {
      final setup = AuthenticatorPayload.tryParse(raw);
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.authenticator,
        action: setup == null
            ? QrRouteAction.none
            : QrRouteAction.setupAuthenticator,
        title: 'Authenticator setup',
        primaryText: setup == null
            ? 'This authenticator code is malformed or unsupported. Import it directly in your trusted authenticator.'
            : setup.account,
        details: setup == null
            ? const []
            : [
                if (setup.issuer != null) 'Issuer: ${setup.issuer}',
                '${setup.kind.toUpperCase()} · ${setup.algorithm} · ${setup.digits} digits',
                if (setup.period != null) 'Period: ${setup.period} seconds',
                if (setup.counter != null) 'Counter: ${setup.counter}',
                'Only continue to an authenticator you trust. Opening an app does not confirm account setup.',
              ],
        sensitiveLabel: setup == null ? 'Provisioning content' : 'Secret key',
        sensitiveValue: setup?.secret ?? raw,
        launchUri: setup?.uri,
      );
    }
    try {
      return _classify(raw);
    } on FormatException {
      return _text(raw);
    } on ArgumentError {
      return _text(raw);
    }
  }

  static ClassifiedQrPayload _text(String raw, {LinkInspection? link}) =>
      ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.text,
        action: QrRouteAction.none,
        title: 'Text',
        primaryText: raw,
        linkInspection: link,
      );

  ClassifiedQrPayload _classify(String raw) {
    final uri = Uri.tryParse(raw);
    final scheme =
        uri?.scheme.toLowerCase() ??
        RegExp(
          r'^([A-Za-z][A-Za-z0-9+.-]*):',
        ).firstMatch(raw)?.group(1)?.toLowerCase();

    if (scheme == 'fido') {
      final valid = RegExp(
        r'^FIDO:/[0-9]+$',
        caseSensitive: false,
      ).hasMatch(raw);
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.passkey,
        action: valid ? QrRouteAction.authenticatePasskey : QrRouteAction.none,
        title: 'Passkey sign-in',
        primaryText: valid
            ? 'Continue with your phone’s passkey provider.'
            : 'This passkey QR code is malformed. Scan a fresh code.',
        details: valid
            ? const [
                'Keep the devices nearby with Bluetooth enabled.',
                'Approve only a sign-in you started. Your phone will ask you to confirm.',
              ]
            : const [],
      );
    }

    if (scheme == 'http' || scheme == 'https') {
      final link = const LinkInspector().inspect(raw);
      if (!link.canOpen) return _text(raw, link: link);
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.webUrl,
        action: QrRouteAction.openUrl,
        title: 'Website',
        primaryText: link.asciiHost!,
        launchUri: link.uri,
        linkInspection: link,
      );
    }
    if (raw.toUpperCase().startsWith('WIFI:')) return _wifi(raw);
    if (_containsComponent(raw, 'VCARD')) {
      final body = _componentBody(raw, 'VCARD');
      return body == null ? _text(raw) : _vCard(raw, body);
    }
    if (_containsComponent(raw, 'VEVENT')) {
      final body = _componentBody(raw, 'VEVENT');
      return body == null ? _text(raw) : _calendar(raw, body);
    }
    if (uri == null) return _text(raw);
    if (uri.hasScheme &&
        (RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(raw) ||
            RegExp(r'%(?![0-9A-Fa-f]{2})').hasMatch(raw))) {
      return _text(raw);
    }
    if (scheme == 'mailto' && uri.path.isNotEmpty) {
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.email,
        action: QrRouteAction.composeEmail,
        title: 'Email',
        primaryText: Uri.decodeComponent(uri.path),
        details: _queryDetails(uri, const ['subject', 'body']),
        launchUri: uri,
      );
    }
    if (scheme == 'tel' && uri.path.isNotEmpty) {
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.phone,
        action: QrRouteAction.call,
        title: 'Phone number',
        primaryText: uri.path,
        launchUri: uri,
      );
    }
    if ((scheme == 'sms' || scheme == 'smsto') && uri.path.isNotEmpty) {
      final launchUri = scheme == 'smsto'
          ? Uri.parse('sms:${raw.substring(raw.indexOf(':') + 1)}')
          : uri;
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.sms,
        action: QrRouteAction.composeSms,
        title: 'Text message',
        primaryText: uri.path,
        details: _queryDetails(uri, const ['body']),
        launchUri: launchUri,
      );
    }
    if (scheme == 'geo' && uri.path.isNotEmpty) {
      final coordinates = uri.path
          .split(';')
          .first
          .split(',')
          .map(double.tryParse)
          .toList();
      if (coordinates.length < 2 ||
          coordinates.length > 3 ||
          coordinates.any((value) => value == null || !value.isFinite) ||
          coordinates[0]!.abs() > 90 ||
          coordinates[1]!.abs() > 180) {
        return _text(raw);
      }
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.location,
        action: QrRouteAction.openLocation,
        title: 'Location',
        primaryText: uri.path,
        details: _queryDetails(uri, const ['q']),
        launchUri: uri,
      );
    }

    if (uri.scheme.isNotEmpty &&
        RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:\S+$').hasMatch(raw)) {
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.deepLink,
        action: QrRouteAction.none,
        title: 'App link',
        primaryText: uri.scheme,
        launchUri: uri,
        linkInspection: const LinkInspector().inspect(raw),
      );
    }
    return _text(raw);
  }

  ClassifiedQrPayload _wifi(String raw) {
    final fields = _escapedFields(raw.substring(raw.indexOf(':') + 1));
    if (fields == null) {
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.wifi,
        action: QrRouteAction.none,
        title: 'Unrecognized Wi-Fi code',
        primaryText: 'The Wi-Fi details could not be parsed. Scan a new code.',
        sensitiveLabel: 'Wi-Fi content',
        sensitiveValue: raw,
      );
    }
    final rawSsid = fields['S'];
    final hasSsid = rawSsid != null && rawSsid.isNotEmpty;
    final ssid = hasSsid ? rawSsid : '(unnamed network)';
    final security = fields['T'];
    final hidden = fields['H']?.toLowerCase() == 'true';
    return ClassifiedQrPayload(
      rawPayload: raw,
      type: QrContentType.wifi,
      action: hasSsid ? QrRouteAction.configureWifi : QrRouteAction.none,
      title: 'Wi-Fi network',
      primaryText: ssid,
      details: [
        if (security != null && security.isNotEmpty) 'Security: $security',
        if (hidden) 'Hidden network',
      ],
      routeArguments: fields,
      sensitiveLabel: fields.containsKey('P') ? 'Password' : null,
      sensitiveValue: fields['P'],
    );
  }

  ClassifiedQrPayload _vCard(String raw, String body) {
    final fields = _lineFields(body);
    if (['FN', 'N'].any((key) => (fields[key]?.length ?? 0) > 1)) {
      return _text(raw);
    }
    final name = _first(fields, 'FN') ?? _first(fields, 'N') ?? 'New contact';
    final phones = (fields['TEL'] ?? const <String>[])
        .where((value) => value.trim().isNotEmpty)
        .toList();
    final emails = (fields['EMAIL'] ?? const <String>[])
        .where((value) => value.trim().isNotEmpty)
        .toList();
    final hasContactData =
        (_first(fields, 'FN')?.trim().isNotEmpty ?? false) ||
        (_first(fields, 'N')?.trim().isNotEmpty ?? false) ||
        phones.isNotEmpty ||
        emails.isNotEmpty;
    return ClassifiedQrPayload(
      rawPayload: raw,
      type: QrContentType.contact,
      action: hasContactData ? QrRouteAction.addContact : QrRouteAction.none,
      title: 'Contact',
      primaryText: name,
      details: [...phones, ...emails],
      routeArguments: {
        'name': name,
        if (phones.isNotEmpty) 'phone': phones.first,
        if (emails.isNotEmpty) 'email': emails.first,
      },
    );
  }

  ClassifiedQrPayload _calendar(String raw, String body) {
    final fields = _lineFields(body);
    if ([
          'DTSTART',
          'DTEND',
          'SUMMARY',
          'LOCATION',
          'DESCRIPTION',
        ].any((key) => (fields[key]?.length ?? 0) > 1) ||
        RegExp(
          r'^DT(?:START|END)[^:\r\n]*;TZID=',
          caseSensitive: false,
          multiLine: true,
        ).hasMatch(body) ||
        [
          'DURATION',
          'RRULE',
          'RDATE',
          'EXDATE',
          'RECURRENCE-ID',
        ].any(fields.containsKey)) {
      return _text(raw);
    }
    final title = _first(fields, 'SUMMARY') ?? 'New event';
    final startValue = _first(fields, 'DTSTART');
    final endValue = _first(fields, 'DTEND');
    final start = _calendarDate(startValue);
    final end = _calendarDate(endValue);
    if (start == null ||
        (fields.containsKey('DTEND') &&
            (end == null ||
                end.isBefore(start) ||
                startValue!.length != endValue!.length))) {
      return _text(raw);
    }
    if (startValue!.length == 8) {
      // Native handoff supplies timestamps, not an all-day flag.
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.calendarEvent,
        action: QrRouteAction.none,
        title: 'Calendar event',
        primaryText: title,
        details: [
          'All-day event: $startValue${endValue == null ? '' : ' to $endValue (exclusive end)'}.',
          'All-day calendar handoff is not supported.',
        ],
      );
    }
    final location = _first(fields, 'LOCATION');
    final description = _first(fields, 'DESCRIPTION');
    return ClassifiedQrPayload(
      rawPayload: raw,
      type: QrContentType.calendarEvent,
      action: QrRouteAction.addCalendarEvent,
      title: 'Calendar event',
      primaryText: title,
      details: [start.toLocal().toString(), ?location],
      routeArguments: {
        'title': title,
        'startMillis': start.millisecondsSinceEpoch,
        if (end != null) 'endMillis': end.millisecondsSinceEpoch,
        'location': ?location,
        'description': ?description,
      },
    );
  }

  static List<String> _queryDetails(Uri uri, List<String> keys) => [
    for (final key in keys)
      if (uri.queryParameters[key] case final value?)
        '${key[0].toUpperCase()}${key.substring(1)}: $value',
  ];

  static Map<String, String>? _escapedFields(String value) {
    final result = <String, String>{};
    final part = StringBuffer();
    final parts = <String>[];
    var escaped = false;
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      if (escaped) {
        if (!r'\;,:"'.contains(char)) return null;
        part.write(char);
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == ';') {
        parts.add(part.toString());
        part.clear();
      } else {
        part.write(char);
      }
    }
    if (escaped) return null;
    if (part.isNotEmpty) parts.add(part.toString());
    for (final entry in parts) {
      final separator = entry.indexOf(':');
      if (separator > 0) {
        final key = entry.substring(0, separator).toUpperCase();
        if (result.containsKey(key)) return null;
        result[key] = entry.substring(separator + 1);
      } else if (entry.isNotEmpty) {
        return null;
      }
    }
    return result;
  }

  static Map<String, List<String>> _lineFields(String raw) {
    final unfolded = raw.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final result = <String, List<String>>{};
    for (final line in unfolded.split(RegExp(r'\r?\n'))) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final name = line.substring(0, separator).split(';').first.toUpperCase();
      final value = _unescape(line.substring(separator + 1));
      result.putIfAbsent(name, () => []).add(value);
    }
    return result;
  }

  static bool _containsComponent(String raw, String component) {
    return RegExp(
      '^BEGIN:$component\\s*\$',
      caseSensitive: false,
      multiLine: true,
    ).hasMatch(raw);
  }

  static String? _componentBody(String raw, String component) {
    var lines = raw.trim().split(RegExp(r'\r?\n'));
    final upper = lines.map((line) => line.toUpperCase()).toList();
    final begin = 'BEGIN:$component';
    final end = 'END:$component';
    if (upper.where((line) => line == begin).length != 1 ||
        upper.where((line) => line == end).length != 1) {
      return null;
    }
    final first = upper.indexOf(begin);
    final last = upper.indexOf(end);
    if (first >= last) return null;
    final wrapped =
        component == 'VEVENT' &&
        upper.first == 'BEGIN:VCALENDAR' &&
        upper.last == 'END:VCALENDAR';
    if (!wrapped && (first != 0 || last != lines.length - 1)) return null;
    final outside = wrapped
        ? [
            ...upper.sublist(1, first),
            ...upper.sublist(last + 1, upper.length - 1),
          ]
        : <String>[];
    lines = lines.sublist(first + 1, last);
    if ([
      ...lines.map((line) => line.toUpperCase()),
      ...outside,
    ].any((line) => line.startsWith('BEGIN:') || line.startsWith('END:'))) {
      return null;
    }
    return lines.join('\n').replaceAll(RegExp(r'\r?\n[ \t]'), '');
  }

  static String? _first(Map<String, List<String>> fields, String key) {
    final values = fields[key];
    return values == null || values.isEmpty ? null : values.first;
  }

  static String _unescape(String value) => value.replaceAllMapped(
    RegExp(r'\\([nN,;\\])'),
    (match) => match[1]!.toLowerCase() == 'n' ? '\n' : match[1]!,
  );

  static DateTime? _calendarDate(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?(Z)?$',
    ).firstMatch(value);
    if (match == null) return null;
    final parts = [for (var index = 1; index <= 6; index++) match[index]];
    final values = parts.map((part) => int.tryParse(part ?? '') ?? 0).toList();
    final isUtc = match[7] != null;
    if (values[0] < 1 || (isUtc && match[4] == null)) return null;
    final date = isUtc
        ? DateTime.utc(
            values[0],
            values[1],
            values[2],
            values[3],
            values[4],
            values[5],
          )
        : DateTime(
            values[0],
            values[1],
            values[2],
            values[3],
            values[4],
            values[5],
          );
    // DateTime normalizes impossible dates/times; never silently accept them.
    if (date.year != values[0] ||
        date.month != values[1] ||
        date.day != values[2] ||
        date.hour != values[3] ||
        date.minute != values[4] ||
        date.second != values[5]) {
      return null;
    }
    return date;
  }
}
