import 'package:flutter/material.dart';

import '../domain/identifier_recognizer.dart';

final class IdentifierDetails extends StatelessWidget {
  const IdentifierDetails({required this.recognition, super.key});

  final IdentifierRecognition recognition;

  @override
  Widget build(BuildContext context) {
    final item = recognition;
    final status = switch (item.validation) {
      IdentifierValidation.checkDigitMatches => 'Check digit matches.',
      IdentifierValidation.invalidCheckDigit => 'Check digit does not match.',
      IdentifierValidation.invalidStructure =>
        'Identifier structure could not be validated.',
      IdentifierValidation.unsupported =>
        'Identifier validation is not supported for this value.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Identifier check',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text('${item.kind.label} candidate'),
        const SizedBox(height: 4),
        const Text('Scanned value'),
        SelectableText(item.originalValue),
        const SizedBox(height: 8),
        Text(status),
        if (item.detail case final detail?) Text(detail),
        if (item.normalizedValue case final normalized?
            when normalized != item.originalValue) ...[
          const SizedBox(height: 8),
          const Text('Normalized identifier'),
          SelectableText(normalized),
        ],
        if (item.derivedLookupValue case final derived?
            when derived != item.normalizedValue) ...[
          const SizedBox(height: 8),
          Text(
            item.kind == IdentifierKind.upcE
                ? 'Derived UPC-A'
                : 'Equivalent ISBN-13',
          ),
          SelectableText(derived),
        ],
        if (item.normalizationNote case final note?) ...[
          const SizedBox(height: 8),
          Text(note),
        ],
        const SizedBox(height: 8),
        const Text(
          'A matching check digit does not confirm an assigned product or book, or prove authenticity.',
        ),
        Text(
          item.kind.isIsbn
              ? 'Online book details are unavailable.'
              : 'Online product details are unavailable.',
        ),
      ],
    );
  }
}
