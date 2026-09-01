import 'package:dali_qr/features/monetization/application/customization_entitlement.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:dali_qr/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('custom QR previews freely but gates export and history', (
    tester,
  ) async {
    final icon = await rootBundle.load('assets/dali_smart_code_icon.png');
    final entitlement = _TestEntitlement();
    var recorded = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: QrGenerationSpikePage(
          secureQrService: SecureQrService(PublicSuffixList.parse('com')),
          customizationEntitlement: entitlement,
          imagePicker: _MemoryImagePicker(icon.buffer.asUint8List()),
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

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate QR code'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('QR code for https://example.com/'), findsOne);
    expect(recorded, 0);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy QR image'));
    await tester.pumpAndSettle();

    expect(find.text('Custom QR lifetime'), findsOne);
    expect(find.text('Unlock for \$3.99'), findsOne);
    expect(find.text('Restore purchase'), findsOne);
    expect(find.text('Unlock for testing'), findsOne);
    expect(recorded, 0);

    await tester.tap(find.text('Unlock for testing'));
    await tester.pumpAndSettle();

    expect(entitlement.isUnlocked, isTrue);
    expect(recorded, 1);
  });

  testWidgets('successful lifetime unlock releases custom export', (
    tester,
  ) async {
    final icon = await rootBundle.load('assets/dali_smart_code_icon.png');
    final entitlement = _TestEntitlement();
    var recorded = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: QrGenerationSpikePage(
          secureQrService: SecureQrService(PublicSuffixList.parse('com')),
          customizationEntitlement: entitlement,
          imagePicker: _MemoryImagePicker(icon.buffer.asUint8List()),
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

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate QR code'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy QR image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock for \$3.99'));
    await tester.pumpAndSettle();

    expect(entitlement.isUnlocked, isTrue);
    expect(recorded, 1);
  });
}

final class _MemoryImagePicker extends ImagePicker {
  _MemoryImagePicker(this.bytes);

  final Uint8List bytes;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return XFile.fromData(bytes, mimeType: 'image/png', name: 'emblem.png');
  }

  @override
  Future<LostDataResponse> retrieveLostData() {
    throw UnimplementedError();
  }
}

final class _TestEntitlement extends CustomizationEntitlement
    implements DebugCustomizationEntitlement {
  bool _unlocked = false;

  @override
  bool get isBusy => false;

  @override
  bool get isStoreAvailable => true;

  @override
  bool get isUnlocked => _unlocked;

  @override
  String? get message => null;

  @override
  String? get price => '\$3.99';

  @override
  Future<void> refresh() async {}

  @override
  Future<void> purchase() async {
    _unlocked = true;
    notifyListeners();
  }

  @override
  Future<void> restore() async {}

  @override
  Future<void> unlockForTesting() => purchase();
}
