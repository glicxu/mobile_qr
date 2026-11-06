import '../../scan/domain/link_inspection.dart';

/// Deliberately limited, uncompressed GTIN Digital Link interpretation.
/// This is syntax/check-digit recognition, never resolver or issuer validation.
final class Gs1DigitalLink {
  Gs1DigitalLink({
    required this.originalValue,
    required this.gtin,
    required Map<String, String> fields,
  }) : fields = Map.unmodifiable(fields);

  final String originalValue;
  final String gtin;
  final Map<String, String> fields;
}

final class Gs1DigitalLinkParser {
  const Gs1DigitalLinkParser();

  static final _digits14 = RegExp(r'^[0-9]{14}$');
  static final _xchar = RegExp(r'''^[A-Za-z0-9!"%&'()*+,\-./:;<=>?_]{1,20}$''');
  static final _structure = RegExp(
    r'^https?://[^/?#]+(/[^?#]*)?(?:\?([^#]*))?$',
    caseSensitive: false,
  );
  static const _qualifiers = ['22', '10', '21'];

  Gs1DigitalLink? parse(String raw) {
    if (raw.length > 8192) return null;
    final inspection = const LinkInspector().inspect(raw);
    if (!inspection.canOpen || inspection.uri!.userInfo.isNotEmpty) return null;
    // Read the raw path: Uri normalizes dot segments. Never let that hide
    // malformed or ambiguous identifier components during recognition.
    final match = _structure.firstMatch(raw);
    if (match == null) return null;
    try {
      final path = (match.group(1) ?? '').split('/').skip(1).toList();
      if (path.isNotEmpty && path.last.isEmpty) path.removeLast();
      final primary = path.indexOf('01');
      if (primary < 0 || primary + 1 >= path.length) return null;
      if (path
          .take(primary)
          .any((part) => !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(part))) {
        return null;
      }
      final gtin = path[primary + 1];
      if (!_digits14.hasMatch(gtin) || !_checkDigit(gtin)) return null;
      final fields = <String, String>{};
      var lastQualifier = -1;
      for (var i = primary + 2; i < path.length; i += 2) {
        if (i + 1 >= path.length) return null;
        final ai = path[i];
        final order = _qualifiers.indexOf(ai);
        if (order <= lastQualifier) return null;
        final value = Uri.decodeComponent(path[i + 1]);
        if (!_xchar.hasMatch(value) || value == '.' || value == '..') {
          return null;
        }
        fields[ai] = value;
        lastQualifier = order;
      }
      final query = match.group(2);
      if (query != null) {
        // Unknown, repeated, or misplaced AIs fall back to ordinary URL review.
        final parts = query.split('=');
        if (parts.length != 2 || parts.first != '17') return null;
        final expiry = Uri.decodeComponent(parts.last);
        if (!_expiry(expiry)) return null;
        fields['17'] = expiry;
      }
      return Gs1DigitalLink(originalValue: raw, gtin: gtin, fields: fields);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static bool _checkDigit(String value) {
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      sum += (value.codeUnitAt(i) - 48) * (i.isEven ? 3 : 1);
    }
    return (10 - sum % 10) % 10 == value.codeUnitAt(13) - 48;
  }

  static bool _expiry(String value) {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) return false;
    final month = int.parse(value.substring(2, 4));
    final day = int.parse(value.substring(4));
    final year = int.parse(value.substring(0, 2));
    // DD=00 is a GS1 month-only value. No century or expiry status is inferred.
    const days = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return month >= 1 &&
        month <= 12 &&
        day <= days[month - 1] &&
        !(month == 2 && day == 29 && year % 4 != 0);
  }
}
