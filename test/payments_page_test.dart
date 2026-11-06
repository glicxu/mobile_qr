import 'package:dali_qr/features/payments/presentation/payments_page.dart';
import 'package:dali_qr/features/payments/application/payments_controller.dart';
import 'package:dali_qr/features/payments/application/payments_entitlement.dart';
import 'package:dali_qr/features/payments/data/local_payments_repository.dart';
import 'package:dali_qr/features/payments/data/payments_database.dart';
import 'package:dali_qr/features/payments/domain/payment_workspace.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/payments_test_access.dart';

Future<void> waitFor(WidgetTester tester, bool Function() done) async {
  final timer = Stopwatch()..start();
  while (!done() && timer.elapsed < const Duration(seconds: 10)) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(done(), isTrue);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'unconfigured access is explicit and sample does not open protected storage',
    (tester) async {
      final access = UnconfiguredPaymentsEntitlement();
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentsPage(
            entitlement: access,
            openRepository: () async {
              opens++;
              throw StateError('Should not open');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Unlock Payments'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Restore Payments'),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('not configured'), findsOneWidget);
      await tester.tap(find.text('Explore sample workspace'));
      await waitFor(
        tester,
        () => find.text('Payments sample').evaluate().isNotEmpty,
      );
      expect(opens, 0);
      await tester.tap(find.text('Review QR card'));
      await waitFor(tester, () => find.byType(Image).evaluate().isNotEmpty);
      await tester.scrollUntilVisible(
        find.text('Copy payment QR'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Copy payment QR'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text('Sample preview only. Export is disabled.'),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      access.dispose();
    },
  );
  testWidgets(
    'owned workspace creates profiles and draft templates, validates and copies exact QR',
    (tester) async {
      final access = TestPaymentsAccess();
      final c = PaymentsController(
        repository: LocalPaymentsRepository(
          PaymentsDatabase(NativeDatabase.memory()),
        ),
        entitlement: access,
      );
      await tester.runAsync(c.refresh);
      Map? copied;
      const channel = MethodChannel('dali_qr/clipboard');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        copied = call.arguments as Map;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        MaterialApp(home: PaymentWorkspacePage(controller: c)),
      );
      await tester.tap(find.text('Profiles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New profile'));
      await tester.pumpAndSettle();
      const link = 'https://checkout.example.com/pay?ref=0001%2B02';
      await tester.enterText(find.byType(TextField).at(0), 'Shop');
      await tester.enterText(find.byType(TextField).at(1), link);
      await tester.tap(find.text('Save profile'));
      await waitFor(tester, () => c.profiles.isNotEmpty);
      await tester.tap(find.text('Templates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New template'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Invoice 0001');
      await tester.tap(find.text('Save draft'));
      await waitFor(tester, () => c.templates.isNotEmpty);
      expect(c.templates.single.state, PaymentTemplateState.draft);
      await tester.tap(find.text('Review QR card'));
      await waitFor(tester, () => find.byType(Image).evaluate().isNotEmpty);
      await tester.scrollUntilVisible(
        find.text('Validate and mark Ready'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Validate and mark Ready'));
      await waitFor(
        tester,
        () => c.templates.single.state == PaymentTemplateState.ready && !c.busy,
      );
      await tester.scrollUntilVisible(
        find.text('Copy payment QR'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Copy payment QR'));
      await waitFor(tester, () => copied != null);
      expect(copied!['payload'], link);
      access.change(PaymentsAccessState.locked);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Copy payment QR'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(c.close);
      access.dispose();
    },
  );
  testWidgets(
    'Payments access screen fits large text without a fake price or purchase',
    (tester) async {
      final access = UnconfiguredPaymentsEntitlement();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: PaymentsPage(entitlement: access),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining(r'$'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      access.dispose();
    },
  );
}
