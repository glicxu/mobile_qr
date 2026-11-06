import 'package:dali_qr/features/create/domain/structured_qr_payload.dart';
import 'package:dali_qr/features/create/presentation/generated_qr_page.dart';
import 'package:dali_qr/features/scan/domain/qr_payload_classifier.dart';
import 'package:dali_qr/main.dart';
import 'package:dali_qr/features/create/domain/qr_center_decoration.dart';
import 'package:dali_qr/features/create/presentation/generated_barcode_page.dart';
import 'package:dali_qr/features/history/application/history_controller.dart';
import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:dali_qr/features/history/presentation/saved_page.dart';
import 'package:dali_qr/features/monetization/application/customization_entitlement.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:dali_qr/features/scan/application/inbound_image_share.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final forms = <QrCreationType, Map<String, String>>{
    QrCreationType.contact: {
      'name': 'Ari; Dev',
      'phone': '+15550100001',
      'email': 'ari+qr@example.com',
    },
    QrCreationType.event: {
      'title': 'Meet; plan',
      'location': 'Room 3',
      'description': 'Bring notes\nThanks',
    },
    QrCreationType.location: {'latitude': '-33.8600', 'longitude': '151.2100'},
    QrCreationType.email: {
      'email': 'ari+qr@example.com',
      'subject': 'Hi + & %',
      'body': 'Hello\nWorld',
    },
    QrCreationType.phone: {'phone': '+15550100001'},
    QrCreationType.sms: {'phone': '+15550100001', 'body': 'Meet + & %'},
  };
  for (final entry in forms.entries) {
    testWidgets(
      'Create ${entry.key.label} produces a QR with reviewed native action',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: QrGenerationSpikePage(
              secureQrService: SecureQrService(PublicSuffixList.parse('com')),
              customizationEntitlement: _Entitlement(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<QrCreationType>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key.label).last);
        await tester.pumpAndSettle();
        for (final field in entry.value.entries) {
          final finder = find.byKey(ValueKey('structured-${field.key}'));
          await tester.ensureVisible(finder);
          await tester.enterText(finder, field.value);
          await tester.pumpAndSettle();
        }
        if (entry.key == QrCreationType.event) {
          for (final start in [true, false]) {
            final button = find.text(
              start ? 'Start date and time' : 'End date and time',
            );
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            await tester.tap(find.text('OK').last);
            await tester.pumpAndSettle();
            final fields = find.descendant(
              of: find.byType(TimePickerDialog),
              matching: find.byType(TextField),
            );
            await tester.enterText(fields.at(0), start ? '9' : '10');
            await tester.enterText(fields.at(1), '30');
            await tester.tap(find.text('OK').last);
            await tester.pumpAndSettle();
          }
        }
        await tester.scrollUntilVisible(
          find.text('Generate QR code'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Generate QR code'));
        await _wait(
          tester,
          () => find.byType(GeneratedQrPage).evaluate().isNotEmpty,
        );
        final page = tester.widget<GeneratedQrPage>(
          find.byType(GeneratedQrPage),
        );
        final parsed = const QrPayloadClassifier().classify(page.payload.value);
        expect(parsed.canRoute, isTrue);
        expect(parsed.type, switch (entry.key) {
          QrCreationType.contact => QrContentType.contact,
          QrCreationType.event => QrContentType.calendarEvent,
          QrCreationType.location => QrContentType.location,
          QrCreationType.email => QrContentType.email,
          QrCreationType.phone => QrContentType.phone,
          QrCreationType.sms => QrContentType.sms,
          _ => throw StateError('Unexpected test type'),
        });
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(GeneratedQrPage), findsNothing);
        await tester.scrollUntilVisible(
          find.byType(DropdownButtonFormField<QrCreationType>),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(entry.key.label), findsOneWidget);
      },
    );
  }
  testWidgets('Create Wi-Fi form generates a masked, decodable QR', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QrGenerationSpikePage(
          secureQrService: SecureQrService(PublicSuffixList.parse('com')),
          customizationEntitlement: _Entitlement(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<QrCreationType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wi-Fi network').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Guest hotspot');
    await tester.enterText(find.byType(TextField).last, 'guestPass123');
    await tester.scrollUntilVisible(
      find.text('Generate QR code'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Generate QR code'));
    await _wait(
      tester,
      () => find.text('Wi-Fi credentials hidden.').evaluate().isNotEmpty,
    );
    expect(find.textContaining('guestPass123'), findsNothing);
    await tester.tap(find.text('Reveal Wi-Fi code'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'WIFI:T:WPA;S:Guest hotspot;P:guestPass123;H:false;;',
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'QR defaults, format validation, exact barcode export/save and Saved recreation',
    (tester) async {
      final controller = (await tester.runAsync(() async {
        final c = HistoryController(
          DriftQrHistoryRepository(
            HistoryDatabase.forTesting(NativeDatabase.memory()),
          ),
          _Settings(),
        );
        await c.initialize();
        return c;
      }))!;
      addTearDown(controller.dispose);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      String? copied;
      Map? imageCopy;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      const channel = MethodChannel('dali_qr/clipboard');
      messenger.setMockMethodCallHandler(channel, (call) async {
        imageCopy = call.arguments as Map;
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        messenger.setMockMethodCallHandler(channel, null);
      });
      await tester.pumpWidget(
        DaliQrApp(
          secureQrService: SecureQrService(PublicSuffixList.parse('com')),
          customizationEntitlement: _Entitlement(),
          historyController: controller,
          inboundImageShare: _NoShare(),
          initialSharedLaunch: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      final dropdown = find.byType(DropdownButtonFormField<ScannedCodeFormat>);
      expect(
        tester
            .widget<DropdownButtonFormField<ScannedCodeFormat>>(dropdown)
            .initialValue,
        ScannedCodeFormat.qrCode,
      );
      expect(find.text('Generate QR code'), findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      expect(find.text('UPC-A'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Generate QR code'), findsOneWidget);
      expect(find.text('UPC-A'), findsNothing);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('UPC-A').last);
      await tester.pumpAndSettle();
      expect(
        find.byType(SegmentedButton<QrCenterDecorationMode>),
        findsNothing,
      );
      await tester.enterText(find.byType(TextField), '012345678906');
      await tester.tap(find.text('Generate UPC-A'));
      await tester.pumpAndSettle();
      expect(find.textContaining('invalid check digit'), findsOneWidget);
      expect(find.byType(GeneratedBarcodePage), findsNothing);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code 128').last);
      await tester.pumpAndSettle();
      const value = '  DALI-00123  ';
      await tester.enterText(find.byType(TextField), value);
      await tester.tap(find.text('Generate Code 128'));
      await _wait(
        tester,
        () => find.byType(GeneratedBarcodePage).evaluate().isNotEmpty,
      );
      final page = tester.widget<GeneratedBarcodePage>(
        find.byType(GeneratedBarcodePage),
      );
      expect(page.code.value, value);
      expect(page.code.format, ScannedCodeFormat.code128);
      expect(controller.items, isEmpty, reason: 'Automatic History is off.');
      await tester.tap(find.text('Copy contents'));
      await tester.pumpAndSettle();
      expect(copied, value);
      await tester.ensureVisible(find.text('Copy image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy image'));
      await tester.pumpAndSettle();
      expect(imageCopy!['payload'], value);
      expect(imageCopy!['bytes'], page.code.png);
      await tester.ensureVisible(find.text('Save to Saved'));
      await tester.tap(find.text('Save to Saved'));
      await _wait(tester, () => controller.savedItems.isNotEmpty);
      final item = controller.savedItems.single;
      expect(item.rawPayload, value);
      expect(item.codeFormat, ScannedCodeFormat.code128);
      expect(item.activityKind, QrActivityKind.created);
      expect(item.source, QrActivitySource.manual);
      expect(item.qrPngBytes, isNull);
      expect(item.verificationCode, isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(GeneratedBarcodePage), findsNothing);
      expect(find.text('Generate Code 128'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(home: SavedPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View barcode'));
      await _wait(
        tester,
        () => find.byType(GeneratedBarcodePage).evaluate().isNotEmpty,
      );
      expect(
        tester
            .widget<GeneratedBarcodePage>(find.byType(GeneratedBarcodePage))
            .code
            .format,
        ScannedCodeFormat.code128,
      );
      expect(
        tester
            .widget<GeneratedBarcodePage>(find.byType(GeneratedBarcodePage))
            .code
            .value,
        value,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  final timer = Stopwatch()..start();
  while (!ready() && timer.elapsed < const Duration(seconds: 15)) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
  }
  expect(ready(), isTrue);
  await tester.pumpAndSettle();
}

final class _Settings implements HistorySettingsStore {
  @override
  Future<bool> historyEnabled() async => false;
  @override
  Future<void> setHistoryEnabled(bool enabled) async {}
}

final class _NoShare implements InboundImageShareSource {
  @override
  Future<void> start(SharedImageHandler onSharedImage) async {}
  @override
  void dispose() {}
}

final class _Entitlement extends CustomizationEntitlement {
  @override
  bool get isUnlocked => true;
  @override
  bool get isStoreAvailable => false;
  @override
  bool get isBusy => false;
  @override
  String? get price => null;
  @override
  String? get message => null;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> purchase() async {}
  @override
  Future<void> restore() async {}
}
