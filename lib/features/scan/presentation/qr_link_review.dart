import 'package:flutter/material.dart';

import '../domain/link_inspection.dart';

final class QrLinkReview extends StatelessWidget {
  const QrLinkReview({required this.inspection, super.key});

  final LinkInspection inspection;

  static String _warning(LinkWarning warning) => switch (warning) {
    LinkWarning.http => 'HTTP does not encrypt the connection.',
    LinkWarning.userInfo =>
      'Text before @ is user information, not the destination host.',
    LinkWarning.internationalizedHost =>
      'This host uses international characters or Punycode. Check its ASCII spelling.',
    LinkWarning.unusualPort => 'This destination uses a nonstandard port.',
    LinkWarning.numericHost =>
      'This host is an IP address or numeric name. Other apps may interpret numeric names differently.',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Link review', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        'Scheme: ${inspection.scheme.isEmpty ? 'Unknown' : inspection.scheme}',
      ),
      if (inspection.asciiHost case final host?)
        Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText('Host: $host'),
        ),
      const SizedBox(height: 8),
      const Text('Full destination'),
      Directionality(
        textDirection: TextDirection.ltr,
        child: SelectableText(inspection.rawValue),
      ),
      if (inspection.problem case final problem?) ...[
        const SizedBox(height: 8),
        Text(problem),
      ],
      for (final warning in inspection.warnings) ...[
        const SizedBox(height: 8),
        Text(_warning(warning)),
      ],
      const SizedBox(height: 8),
      const Text(
        'Local checks and comparison codes do not establish site safety. '
        'Dali has not contacted this destination.',
      ),
    ],
  );
}
