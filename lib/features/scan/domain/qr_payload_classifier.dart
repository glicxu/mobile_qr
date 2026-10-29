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

  bool get canRoute => action != QrRouteAction.none;
}

final class QrPayloadClassifier {
  const QrPayloadClassifier();

  ClassifiedQrPayload classify(String raw) {
    final uri = Uri.tryParse(raw);
    final scheme = uri?.scheme.toLowerCase();

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

    if ((scheme == 'http' || scheme == 'https') && uri!.host.isNotEmpty) {
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.webUrl,
        action: QrRouteAction.openUrl,
        title: 'Website',
        primaryText: uri.host,
        launchUri: uri,
      );
    }
    if (scheme == 'mailto' && uri!.path.isNotEmpty) {
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.email,
        action: QrRouteAction.composeEmail,
        title: 'Email',
        primaryText: uri.path,
        details: _queryDetails(uri, const ['subject', 'body']),
        launchUri: uri,
      );
    }
    if (scheme == 'tel' && uri!.path.isNotEmpty) {
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.phone,
        action: QrRouteAction.call,
        title: 'Phone number',
        primaryText: uri.path,
        launchUri: uri,
      );
    }
    if ((scheme == 'sms' || scheme == 'smsto') && uri!.path.isNotEmpty) {
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
    if (scheme == 'geo' && uri!.path.isNotEmpty) {
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

    if (raw.toUpperCase().startsWith('WIFI:')) return _wifi(raw);
    if (_containsComponent(raw, 'VCARD')) return _vCard(raw);
    if (_containsComponent(raw, 'VEVENT')) return _calendar(raw);

    if (uri != null &&
        uri.scheme.isNotEmpty &&
        RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:\S+$').hasMatch(raw)) {
      return ClassifiedQrPayload(
        rawPayload: raw,
        type: QrContentType.deepLink,
        action: QrRouteAction.none,
        title: 'App link',
        primaryText: uri.scheme,
        launchUri: uri,
      );
    }
    return ClassifiedQrPayload(
      rawPayload: raw,
      type: QrContentType.text,
      action: QrRouteAction.none,
      title: 'Text',
      primaryText: raw,
    );
  }

  ClassifiedQrPayload _wifi(String raw) {
    final fields = _escapedFields(raw.substring(raw.indexOf(':') + 1));
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

  ClassifiedQrPayload _vCard(String raw) {
    final fields = _lineFields(raw);
    final name = _first(fields, 'FN') ?? _first(fields, 'N') ?? 'New contact';
    final phones = fields['TEL'] ?? const [];
    final emails = fields['EMAIL'] ?? const [];
    final hasContactData =
        fields.containsKey('FN') ||
        fields.containsKey('N') ||
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

  ClassifiedQrPayload _calendar(String raw) {
    final fields = _lineFields(raw);
    final title = _first(fields, 'SUMMARY') ?? 'New event';
    final start = _calendarDate(_first(fields, 'DTSTART'));
    final end = _calendarDate(_first(fields, 'DTEND'));
    final location = _first(fields, 'LOCATION');
    final description = _first(fields, 'DESCRIPTION');
    return ClassifiedQrPayload(
      rawPayload: raw,
      type: QrContentType.calendarEvent,
      action: start != null
          ? QrRouteAction.addCalendarEvent
          : QrRouteAction.none,
      title: 'Calendar event',
      primaryText: title,
      details: [if (start != null) start.toLocal().toString(), ?location],
      routeArguments: {
        'title': title,
        if (start != null) 'startMillis': start.millisecondsSinceEpoch,
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

  static Map<String, String> _escapedFields(String value) {
    final result = <String, String>{};
    final part = StringBuffer();
    final parts = <String>[];
    var escaped = false;
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      if (escaped) {
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
    if (part.isNotEmpty) parts.add(part.toString());
    for (final entry in parts) {
      final separator = entry.indexOf(':');
      if (separator > 0) {
        result[entry.substring(0, separator).toUpperCase()] = entry.substring(
          separator + 1,
        );
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

  static String? _first(Map<String, List<String>> fields, String key) {
    final values = fields[key];
    return values == null || values.isEmpty ? null : values.first;
  }

  static String _unescape(String value) => value
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\');

  static DateTime? _calendarDate(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?(Z)?$',
    ).firstMatch(value);
    if (match == null) return null;
    final parts = [for (var index = 1; index <= 6; index++) match[index]];
    final values = parts.map((part) => int.tryParse(part ?? '') ?? 0).toList();
    final isUtc = match[7] != null;
    return isUtc
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
  }
}
