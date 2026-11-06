import 'package:flutter/material.dart';

import '../domain/gs1_digital_link.dart';

final class Gs1Details extends StatelessWidget {
  const Gs1Details({required this.link, super.key});
  final Gs1DigitalLink link;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'GS1 Digital Link fields',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const Text('GTIN (01) — check digit matches'),
      SelectableText(link.gtin),
      for (final entry in link.fields.entries) ...[
        const SizedBox(height: 8),
        Text(switch (entry.key) {
          '22' => 'Consumer product variant (22)',
          '10' => 'Batch / lot (10)',
          '21' => 'Serial number (21)',
          '17' => 'Expiry field (17), raw YYMMDD',
          _ => entry.key,
        }),
        SelectableText(entry.value),
      ],
      const SizedBox(height: 8),
      const Text(
        'Parsed locally. These fields do not confirm a product, issuer, authenticity, or current expiry status.',
      ),
      const Text('Online resolution is unavailable.'),
    ],
  );
}
