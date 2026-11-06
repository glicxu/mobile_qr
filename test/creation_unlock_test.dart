import 'package:dali_qr/features/create/application/barcode_generator.dart';
import 'package:dali_qr/features/create/domain/structured_qr_payload.dart';
import 'package:dali_qr/features/create/presentation/generated_barcode_page.dart';
import 'package:dali_qr/features/create/presentation/generated_qr_page.dart';
import 'package:dali_qr/features/monetization/application/customization_entitlement.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:dali_qr/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final format in BarcodeGenerator.formats.where(
    (format) => format != ScannedCodeFormat.qrCode,
  )) {
    testWidgets('${format.label} creation requires lifetime access', (
      tester,
    ) async {
      var recorded = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: QrGenerationSpikePage(
            secureQrService: SecureQrService(PublicSuffixList.parse('com')),
            customizationEntitlement: _Access(),
            onBarcodeCreated: (_) async {
              recorded++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<ScannedCodeFormat>));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(format.label),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(format.label).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '123456789012');
      await tester.ensureVisible(find.text('Generate ${format.label}'));
      await tester.tap(find.text('Generate ${format.label}'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock more code types'), findsOneWidget);
      expect(find.byType(GeneratedBarcodePage), findsNothing);
      expect(recorded, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('123456789012'), findsOneWidget);
    });
  }

  for (final type in QrCreationType.values.where(
    (t) => t != QrCreationType.text,
  )) {
    testWidgets('${type.label} QR form requires lifetime access', (
      tester,
    ) async {
      var recorded = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: QrGenerationSpikePage(
            secureQrService: SecureQrService(PublicSuffixList.parse('com')),
            customizationEntitlement: _Access(),
            onCreated:
                ({
                  required payload,
                  verificationCode,
                  registrableDomain,
                  required qrPngBytes,
                }) async {
                  recorded++;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<QrCreationType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(type.label).last);
      await tester.pumpAndSettle();
      if (type == QrCreationType.wifi) {
        await tester.enterText(find.byType(TextField).first, 'Guest network');
      }
      await tester.scrollUntilVisible(
        find.text('Generate QR code'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Generate QR code'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock more code types'), findsOneWidget);
      expect(find.byType(GeneratedQrPage), findsNothing);
      expect(recorded, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Generate QR code'), findsOneWidget);
    });
  }

  for (final restore in [false, true]) {
    testWidgets('${restore ? 'Restore' : 'Purchase'} resumes Wi-Fi creation', (
      tester,
    ) async {
      final access = _Access();
      var recorded = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: QrGenerationSpikePage(
            secureQrService: SecureQrService(PublicSuffixList.parse('com')),
            customizationEntitlement: access,
            onCreated:
                ({
                  required payload,
                  verificationCode,
                  registrableDomain,
                  required qrPngBytes,
                }) async {
                  recorded++;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<QrCreationType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wi-Fi network').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Guest network');
      await tester.enterText(find.byType(TextField).last, 'secret123');
      await tester.scrollUntilVisible(
        find.text('Generate QR code'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Generate QR code'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(restore ? 'Restore purchase' : r'Unlock for $3.99'),
      );
      for (
        var i = 0;
        i < 100 && find.byType(GeneratedQrPage).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      final page = tester.widget<GeneratedQrPage>(find.byType(GeneratedQrPage));
      expect(page.payload.value, contains('S:Guest network;P:secret123;'));
      expect(recorded, 1);
      expect(find.text('Unlock more code types'), findsNothing);
      expect(restore ? access.restores : access.purchases, 1);
    });
  }
}

final class _Access extends CustomizationEntitlement {
  bool unlocked = false;
  int purchases = 0;
  int restores = 0;
  @override
  bool get isUnlocked => unlocked;
  @override
  bool get isStoreAvailable => true;
  @override
  bool get isBusy => false;
  @override
  String? get price => r'$3.99';
  @override
  String? get message => null;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> purchase() async {
    purchases++;
    unlocked = true;
    notifyListeners();
  }

  @override
  Future<void> restore() async {
    restores++;
    unlocked = true;
    notifyListeners();
  }
}
