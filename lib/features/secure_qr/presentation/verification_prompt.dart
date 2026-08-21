import 'package:flutter/material.dart';

enum VerificationPromptOutcome { cancel, openUnverified, codeMatches }

Future<VerificationPromptOutcome> showVerificationPrompt(
  BuildContext context, {
  required String code,
  required String registrableDomain,
  String unverifiedActionLabel = 'Open unverified',
  String matchedActionLabel = 'Code matches - Open',
}) async {
  final outcome = await showDialog<VerificationPromptOutcome>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.fact_check_outlined),
      title: const Text('Verify if available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'If a trusted verification code is printed beside the QR, compare '
            'it with the code calculated by Dali QR.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            code,
            style: Theme.of(dialogContext).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(registrableDomain),
          const SizedBox(height: 16),
          const Text(
            'Dali QR cannot tell whether a trusted comparison code is '
            'available or whether the codes match.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, VerificationPromptOutcome.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            VerificationPromptOutcome.openUnverified,
          ),
          child: Text(unverifiedActionLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            VerificationPromptOutcome.codeMatches,
          ),
          child: Text(matchedActionLabel),
        ),
      ],
    ),
  );
  return outcome ?? VerificationPromptOutcome.cancel;
}
