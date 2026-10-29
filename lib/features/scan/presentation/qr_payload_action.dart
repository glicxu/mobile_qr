import 'package:flutter/material.dart';

import '../../secure_qr/presentation/verification_prompt.dart';
import '../application/qr_payload_router.dart';
import '../domain/qr_payload_classifier.dart';

extension QrPayloadPresentation on ClassifiedQrPayload {
  IconData get icon => switch (type) {
    QrContentType.passkey => Icons.key,
    QrContentType.webUrl => Icons.language,
    QrContentType.email => Icons.email_outlined,
    QrContentType.phone => Icons.phone_outlined,
    QrContentType.sms => Icons.sms_outlined,
    QrContentType.location => Icons.map_outlined,
    QrContentType.wifi => Icons.wifi,
    QrContentType.contact => Icons.person_add_alt,
    QrContentType.calendarEvent => Icons.event_outlined,
    QrContentType.deepLink => Icons.open_in_new,
    QrContentType.text => Icons.text_snippet_outlined,
  };

  String get actionLabel => switch (action) {
    QrRouteAction.authenticatePasskey => 'Continue with passkey',
    QrRouteAction.openUrl => 'Open',
    QrRouteAction.composeEmail => 'Compose email',
    QrRouteAction.call => 'Call number',
    QrRouteAction.composeSms => 'Compose message',
    QrRouteAction.openLocation => 'Open in maps',
    QrRouteAction.configureWifi => 'Open Wi-Fi settings',
    QrRouteAction.addContact => 'Add contact',
    QrRouteAction.addCalendarEvent => 'Add to calendar',
    QrRouteAction.openDeepLink => 'Open app link',
    QrRouteAction.none => 'No action',
  };

  String get failureMessage => switch (action) {
    QrRouteAction.authenticatePasskey =>
      'Could not start passkey sign-in. Try your phone’s system Camera or '
          'Code Scanner with a fresh QR code.',
    QrRouteAction.configureWifi =>
      'Wi-Fi configuration is not available on this device.',
    QrRouteAction.addContact => 'A contacts app could not open this contact.',
    QrRouteAction.addCalendarEvent =>
      'A calendar app could not open this event.',
    _ => 'No installed app could handle this content.',
  };
}

final class QrSensitiveDetail extends StatefulWidget {
  const QrSensitiveDetail({required this.payload, super.key});

  final ClassifiedQrPayload payload;

  @override
  State<QrSensitiveDetail> createState() => _QrSensitiveDetailState();
}

class _QrSensitiveDetailState extends State<QrSensitiveDetail> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.payload.sensitiveLabel;
    final value = widget.payload.sensitiveValue;
    if (label == null || value == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(child: Text('$label: ${_visible ? value : '********'}')),
        IconButton(
          onPressed: () => setState(() => _visible = !_visible),
          tooltip: _visible ? 'Hide $label' : 'Reveal $label',
          icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
        ),
      ],
    );
  }
}

Future<void> routeQrPayload(
  BuildContext context,
  ClassifiedQrPayload payload, {
  String? comparisonCode,
}) async {
  if (!payload.canRoute) return;

  if (payload.action != QrRouteAction.openUrl) {
    if (comparisonCode != null && payload.type != QrContentType.passkey) {
      final outcome = await showVerificationPrompt(
        context,
        code: comparisonCode,
        registrableDomain: payload.primaryText,
        unverifiedActionLabel: 'Continue unverified',
        matchedActionLabel: 'Code matches - Continue',
      );
      if (outcome == VerificationPromptOutcome.cancel || !context.mounted) {
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(payload.icon),
          title: Text(payload.actionLabel),
          content: Text(
            payload.type == QrContentType.passkey
                ? '${payload.primaryText}\n\n${payload.details.join('\n\n')}'
                : payload.primaryText,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
  }

  var opened = false;
  try {
    opened = await const QrPayloadRouter().route(payload);
  } on Object {
    // A platform may reject a recognized scheme when no matching app exists.
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(payload.failureMessage)));
  }
}
