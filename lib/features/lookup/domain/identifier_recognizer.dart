import '../../scan/domain/scanned_code.dart';

enum IdentifierKind {
  upcA('UPC-A'),
  upcE('UPC-E'),
  ean8('EAN-8'),
  ean13('EAN-13'),
  isbn10('ISBN-10'),
  isbn13('ISBN-13');

  const IdentifierKind(this.label);
  final String label;

  bool get isIsbn => this == isbn10 || this == isbn13;
}

enum IdentifierValidation {
  checkDigitMatches,
  invalidCheckDigit,
  invalidStructure,
  unsupported,
}

/// A local candidate, not evidence of an assigned identifier or a catalog match.
final class IdentifierRecognition {
  const IdentifierRecognition({
    required this.originalValue,
    required this.originalFormat,
    required this.kind,
    required this.validation,
    this.normalizedValue,
    this.derivedLookupValue,
    this.normalizationNote,
    this.detail,
  });

  final String originalValue;
  final ScannedCodeFormat originalFormat;
  final IdentifierKind kind;
  final IdentifierValidation validation;

  /// A separately represented candidate; never replaces the scanned value.
  final String? normalizedValue;

  /// Preparation for a future provider contract only. This enables no service.
  /// Present only when the supported structure and check digit both match.
  final String? derivedLookupValue;
  final String? normalizationNote;
  final String? detail;
}

final class IdentifierRecognizer {
  const IdentifierRecognizer();

  static final _digits = RegExp(r'^[0-9]+$');
  static final _isbnLabel = RegExp(
    r'^ISBN(?:-(10|13))?(?:: *| +)(.*)$',
    caseSensitive: false,
  );
  static final _isbnText = RegExp(r'^[0-9Xx]+(?:[ -][0-9Xx]+)*$');

  IdentifierRecognition? recognize({
    required String value,
    required ScannedCodeFormat format,
  }) {
    final retailKind = switch (format) {
      ScannedCodeFormat.upcA => IdentifierKind.upcA,
      ScannedCodeFormat.upcE => IdentifierKind.upcE,
      ScannedCodeFormat.ean8 => IdentifierKind.ean8,
      ScannedCodeFormat.ean13 => IdentifierKind.ean13,
      _ => null,
    };
    IdentifierRecognition result(
      IdentifierKind kind,
      IdentifierValidation validation, {
      String? normalized,
      String? lookup,
      String? note,
      String? detail,
    }) => IdentifierRecognition(
      originalValue: value,
      originalFormat: format,
      kind: kind,
      validation: validation,
      normalizedValue: normalized,
      derivedLookupValue: lookup,
      normalizationNote: note,
      detail: detail,
    );

    if (retailKind != null) {
      final length = switch (retailKind) {
        IdentifierKind.upcA => 12,
        IdentifierKind.ean13 => 13,
        _ => 8,
      };
      if (value.length != length || !_digits.hasMatch(value)) {
        return result(
          retailKind,
          IdentifierValidation.invalidStructure,
          detail:
              'Expected exactly $length ASCII digits. The scanned value has not been changed.',
        );
      }
      if (retailKind == IdentifierKind.upcE) {
        if (value[0] != '0') {
          return result(
            retailKind,
            IdentifierValidation.unsupported,
            detail:
                'Only UPC-E number system 0 is supported for identifier validation.',
          );
        }
        if (!_canonicalUpcE(value)) {
          return result(
            retailKind,
            IdentifierValidation.invalidStructure,
            detail:
                'This value does not follow the supported UPC-E zero-suppression rules.',
          );
        }
        final expanded = _expandUpcE(value);
        final matches = _gtinMatches(expanded);
        return result(
          retailKind,
          matches
              ? IdentifierValidation.checkDigitMatches
              : IdentifierValidation.invalidCheckDigit,
          normalized: value,
          lookup: matches ? expanded : null,
          note: matches
              ? 'Expanded UPC-E to UPC-A as a separate derived value. The scan is unchanged.'
              : null,
        );
      }
      final kind = retailKind == IdentifierKind.ean13 && _isbnPrefix(value)
          ? IdentifierKind.isbn13
          : retailKind;
      final matches = _gtinMatches(value);
      return result(
        kind,
        matches
            ? IdentifierValidation.checkDigitMatches
            : IdentifierValidation.invalidCheckDigit,
        normalized: value,
        lookup: matches ? value : null,
      );
    }

    // ITF-14 and arbitrary numeric values are outside this recognition scope.
    if (format == ScannedCodeFormat.itf14 || value.length > 128) return null;
    final label = _isbnLabel.firstMatch(value);
    final body = label?.group(2) ?? value;
    if (!_isbnText.hasMatch(body)) return null;
    final compact = body.replaceAll(RegExp('[ -]'), '').toUpperCase();
    final requestedLength = int.tryParse(label?.group(1) ?? '');
    final length = requestedLength ?? compact.length;
    if (length != 10 && length != 13) return null;
    // Without an explicit label, ten digits could be an account or other ID.
    // Bare ISBN-13 candidates require a book prefix; other numeric text is inert.
    if (label == null && (length != 13 || !_isbnPrefix(compact))) return null;
    final kind = length == 10 ? IdentifierKind.isbn10 : IdentifierKind.isbn13;
    final validShape =
        compact.length == length &&
        (length == 10
            ? RegExp(r'^[0-9]{9}[0-9X]$').hasMatch(compact)
            : _digits.hasMatch(compact) && _isbnPrefix(compact));
    if (!validShape) {
      return result(
        kind,
        IdentifierValidation.invalidStructure,
        detail:
            'This value does not match the supported ${kind.label} structure or prefix.',
      );
    }
    final matches = length == 10
        ? _isbn10Matches(compact)
        : _gtinMatches(compact);
    final lookup = !matches
        ? null
        : length == 10
        ? _withGtinCheckDigit('978${compact.substring(0, 9)}')
        : compact;
    final notes = <String>[
      if (label != null) 'Removed the ISBN label in the normalized identifier.',
      if (body.contains('-') || body.contains(' '))
        'Removed ISBN separators in the normalized identifier.',
      if (body.contains('x')) 'Uppercased the ISBN check character.',
      if (matches && length == 10)
        'Converted ISBN-10 to a separate ISBN-13 value.',
    ];
    return result(
      kind,
      matches
          ? IdentifierValidation.checkDigitMatches
          : IdentifierValidation.invalidCheckDigit,
      normalized: compact,
      lookup: lookup,
      note: notes.isEmpty ? null : notes.join(' '),
    );
  }

  // 979-0 identifies printed music (ISMN), not ISBN. Registration-group and
  // publisher allocations are deliberately not inferred without a registry.
  static bool _isbnPrefix(String value) =>
      value.startsWith('978') ||
      (value.startsWith('979') && !value.startsWith('9790'));

  static bool _gtinMatches(String value) =>
      _withGtinCheckDigit(value.substring(0, value.length - 1)) == value;

  static String _withGtinCheckDigit(String body) {
    var sum = 0;
    var weight = 3;
    for (var index = body.length - 1; index >= 0; index--) {
      sum += (body.codeUnitAt(index) - 48) * weight;
      weight = 4 - weight;
    }
    return '$body${(10 - sum % 10) % 10}';
  }

  static bool _isbn10Matches(String value) {
    var sum = 0;
    for (var index = 0; index < 10; index++) {
      final digit = value[index] == 'X' ? 10 : value.codeUnitAt(index) - 48;
      sum += digit * (10 - index);
    }
    return sum % 11 == 0;
  }

  static bool _canonicalUpcE(String value) => switch (value[6]) {
    '3' => int.parse(value[3]) >= 3,
    '4' => value[4] != '0',
    '5' || '6' || '7' || '8' || '9' => value[5] != '0',
    _ => true,
  };

  static String _expandUpcE(String value) {
    final digits = value.substring(1, 7);
    final body = switch (digits[5]) {
      '0' || '1' || '2' =>
        '${digits.substring(0, 2)}${digits[5]}0000${digits.substring(2, 5)}',
      '3' => '${digits.substring(0, 3)}00000${digits.substring(3, 5)}',
      '4' => '${digits.substring(0, 4)}00000${digits[4]}',
      _ => '${digits.substring(0, 5)}0000${digits[5]}',
    };
    return '0$body${value[7]}';
  }
}
