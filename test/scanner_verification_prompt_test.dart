import 'package:dali_qr/features/secure_qr/presentation/verification_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explains that verification needs an available trusted code', (
    tester,
  ) async {
    VerificationPromptOutcome? outcome;
    await tester.pumpWidget(
      _PromptHarness(onResult: (value) => outcome = value),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Verify if available'), findsOneWidget);
    expect(find.text('XIH-000'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('Code matches - Open'), findsOneWidget);
    expect(find.text('Open unverified'), findsOneWidget);

    await tester.tap(find.text('Code matches - Open'));
    await tester.pumpAndSettle();
    expect(outcome, VerificationPromptOutcome.codeMatches);
  });

  testWidgets('canceling the prompt does not approve opening', (tester) async {
    VerificationPromptOutcome? outcome;
    await tester.pumpWidget(
      _PromptHarness(onResult: (value) => outcome = value),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(outcome, VerificationPromptOutcome.cancel);
  });

  testWidgets('allows an explicit unverified open when no code is available', (
    tester,
  ) async {
    VerificationPromptOutcome? outcome;
    await tester.pumpWidget(
      _PromptHarness(onResult: (value) => outcome = value),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open unverified'));
    await tester.pumpAndSettle();
    expect(outcome, VerificationPromptOutcome.openUnverified);
  });
}

final class _PromptHarness extends StatelessWidget {
  const _PromptHarness({required this.onResult});

  final ValueChanged<VerificationPromptOutcome> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => FilledButton(
          onPressed: () async {
            onResult(
              await showVerificationPrompt(
                context,
                code: 'XIH-000',
                registrableDomain: 'example.com',
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    );
  }
}
