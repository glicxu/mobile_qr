import 'package:flutter/material.dart';

import '../../secure_qr/presentation/verification_prompt.dart';
import '../application/qr_payload_router.dart';
import '../domain/qr_payload_classifier.dart';
import '../domain/link_inspection.dart';
import 'wifi_join_dialog.dart';

extension QrPayloadPresentation on ClassifiedQrPayload {
  IconData get icon => switch (type) {
    QrContentType.authenticator => Icons.security,
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
    QrRouteAction.setupAuthenticator => 'Open authenticator',
    QrRouteAction.authenticatePasskey => 'Continue with passkey',
    QrRouteAction.openUrl => 'Open',
    QrRouteAction.composeEmail => 'Compose email',
    QrRouteAction.call => 'Call number',
    QrRouteAction.composeSms => 'Compose message',
    QrRouteAction.openLocation => 'Open in maps',
    QrRouteAction.configureWifi => 'Join network',
    QrRouteAction.addContact => 'Add contact',
    QrRouteAction.addCalendarEvent => 'Add to calendar',
    QrRouteAction.openDeepLink => 'Open app link',
    QrRouteAction.none => 'No action',
  };

  String get failureMessage => switch (action) {
    QrRouteAction.setupAuthenticator =>
      'No compatible authenticator could be opened. Import this setup code directly in your trusted authenticator.',
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
  void didUpdateWidget(covariant QrSensitiveDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload.rawPayload != widget.payload.rawPayload) {
      _visible = false;
    }
  }

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

/// Raw Wi-Fi codes contain passwords too, so expanding Details is not a reveal.
final class QrRawContent extends StatefulWidget {
  const QrRawContent({required this.payload, super.key});
  final ClassifiedQrPayload payload;
  @override
  State<QrRawContent> createState() => _QrRawContentState();
}

class _QrRawContentState extends State<QrRawContent> {
  bool _visible = false;
  @override
  void didUpdateWidget(covariant QrRawContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload.rawPayload != widget.payload.rawPayload) {
      _visible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authenticator = widget.payload.type == QrContentType.authenticator;
    if (widget.payload.type != QrContentType.wifi && !authenticator) {
      return SelectableText(widget.payload.rawPayload);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_visible)
          SelectableText(widget.payload.rawPayload)
        else
          Text(
            authenticator
                ? 'Authenticator credentials hidden.'
                : 'Wi-Fi credentials hidden.',
          ),
        TextButton.icon(
          onPressed: () => setState(() => _visible = !_visible),
          icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
          label: Text(
            authenticator
                ? (_visible
                      ? 'Hide authenticator code'
                      : 'Reveal authenticator code')
                : (_visible ? 'Hide Wi-Fi code' : 'Reveal Wi-Fi code'),
          ),
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
  if (payload.action == QrRouteAction.configureWifi) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          WifiJoinDialog(payload: payload, comparisonCode: comparisonCode),
    );
    return;
  }

  if (payload.action == QrRouteAction.openUrl) {
    final inspection = const LinkInspector().inspect(payload.rawPayload);
    if (!inspection.canOpen) return;
  } else {
    if (comparisonCode != null && !payload.isEphemeral) {
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
            payload.isEphemeral
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
