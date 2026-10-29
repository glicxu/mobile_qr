import 'package:dali_qr/features/history/application/history_controller.dart';
import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:dali_qr/features/monetization/application/customization_entitlement.dart';
import 'package:dali_qr/main.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  testWidgets('generates and displays a QR code', (tester) async {
    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final secureQrService = SecureQrService(PublicSuffixList.parse('com'));
    final historyController = HistoryController(
      DriftQrHistoryRepository(
        HistoryDatabase.forTesting(NativeDatabase.memory()),
      ),
      _MemoryHistorySettings(),
    );
    await historyController.initialize();
    addTearDown(historyController.dispose);
    await tester.pumpWidget(
      DaliQrApp(
        secureQrService: secureQrService,
        historyController: historyController,
        customizationEntitlement: _TestEntitlement(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Dali QR',
    );

    expect(find.text('Scan QR code or barcode'), findsOneWidget);
    final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
    expect(scanner.controller?.autoStart, isTrue);
    expect(scanner.controller?.facing, CameraFacing.back);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate QR code'));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('QR code for https://example.com/'),
      findsOneWidget,
    );
    expect(find.text('https://example.com/'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(find.text('Plain'), findsNothing);
    expect(find.text('Code'), findsNothing);
    expect(find.text('Dali'), findsNothing);
    expect(find.text('Custom'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Generate QR code'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('XIH-000'), findsOneWidget);
    expect(find.text('Secure QR - example.com'), findsNothing);
    expect(find.text('Copy QR image'), findsNothing);
    expect(find.text('Share QR image'), findsOneWidget);
    expect(find.byTooltip('Copy verification code'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy verification code'));
    await tester.pump();
    expect(copiedText, 'XIH-000');
    expect(find.text('Verification code copied.'), findsOneWidget);
    expect(find.textContaining('UTF-8 bytes'), findsNothing);
    expect(find.textContaining('full-payload'), findsNothing);
    expect(find.textContaining('mask '), findsNothing);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Keep a local QR history?'), findsOneWidget);

    await tester.tap(find.text('Enable local history'));
    await tester.pumpAndSettle();
    expect(
      find.text('Created and scanned codes will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate QR code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('example.com'), findsOneWidget);

    await tester.tap(find.text('example.com'));
    await tester.pumpAndSettle();
    expect(find.text('Created QR'), findsOneWidget);
    expect(find.text('Verification code'), findsOneWidget);
    expect(find.text('XIH-000'), findsOneWidget);
    expect(find.text('Copy QR image'), findsOneWidget);
    expect(find.byTooltip('Copy verification code'), findsOneWidget);
    expect(find.byTooltip('Copy payload'), findsOneWidget);
    expect(find.text('Open in browser'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<bool>),
        matching: find.text('Saved'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('example.com'), findsOneWidget);
  });

  testWidgets('generates URLs without a domain as unverified QR content', (
    tester,
  ) async {
    final secureQrService = SecureQrService(PublicSuffixList.parse('com'));
    await tester.pumpWidget(
      MaterialApp(
        home: QrGenerationSpikePage(
          secureQrService: secureQrService,
          customizationEntitlement: _TestEntitlement(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'http://192.0.2.10/path');
    await tester.tap(find.text('Generate QR code'));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('QR code for http://192.0.2.10/path'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('No verification code'), findsOneWidget);
    expect(
      find.text('This URL does not have a registrable domain.'),
      findsOneWidget,
    );
  });

  testWidgets('generates non-web payloads with a content comparison code', (
    tester,
  ) async {
    final secureQrService = SecureQrService(PublicSuffixList.parse('com'));
    await tester.pumpWidget(
      MaterialApp(
        home: QrGenerationSpikePage(
          secureQrService: secureQrService,
          customizationEntitlement: _TestEntitlement(),
        ),
      ),
    );

    const wifiPayload = 'WIFI:T:WPA;S:GuestNetwork;P:password123;;';
    await tester.enterText(find.byType(TextField), wifiPayload);
    await tester.tap(find.text('Generate QR code'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('QR code for $wifiPayload'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('041-AVZ'), findsOneWidget);
    expect(find.text('Content comparison code'), findsNothing);
    expect(find.text(wifiPayload), findsOneWidget);
  });

  testWidgets('clears QR content from the text field clear button', (
    tester,
  ) async {
    final secureQrService = SecureQrService(PublicSuffixList.parse('com'));
    await tester.pumpWidget(
      MaterialApp(
        home: QrGenerationSpikePage(
          secureQrService: secureQrService,
          customizationEntitlement: _TestEntitlement(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Clear QR content'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear QR content'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);
    expect(find.byTooltip('Clear QR content'), findsNothing);
  });

  testWidgets('dismisses the QR content keyboard when tapping outside input', (
    tester,
  ) async {
    final secureQrService = SecureQrService(PublicSuffixList.parse('com'));
    await tester.pumpWidget(
      MaterialApp(
        home: QrGenerationSpikePage(
          secureQrService: secureQrService,
          customizationEntitlement: _TestEntitlement(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    await tester.tap(find.text('Generate QR code'));
    await tester.pump();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
  });
}

final class _TestEntitlement extends CustomizationEntitlement {
  @override
  bool get isBusy => false;

  @override
  bool get isStoreAvailable => false;

  @override
  bool get isUnlocked => false;

  @override
  String? get message => null;

  @override
  String? get price => null;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> purchase() async {}

  @override
  Future<void> restore() async {}
}

final class _MemoryHistorySettings implements HistorySettingsStore {
  @override
  Future<bool> historyEnabled() async => false;

  @override
  Future<void> setHistoryEnabled(bool enabled) async {}
}
