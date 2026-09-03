import 'dart:typed_data';

import 'package:dali_qr/features/create/application/custom_center_image_store.dart';
import 'package:dali_qr/features/create/presentation/generated_qr_page.dart';
import 'package:dali_qr/features/monetization/application/customization_entitlement.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:dali_qr/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MockImagePicker extends ImagePicker {
  _MockImagePicker({this.pickedBytes});

  final Uint8List? pickedBytes;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (pickedBytes == null) return null;
    return XFile.fromData(pickedBytes!, mimeType: 'image/png');
  }
}

final class _UnlockedEntitlement extends ChangeNotifier
    implements CustomizationEntitlement {
  @override
  bool get isUnlocked => true;
  @override
  bool get isStoreAvailable => true;
  @override
  bool get isBusy => false;
  @override
  String? get message => null;
  @override
  String? get price => r'$1.99';
  @override
  Future<void> purchase() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> restore() async {}
}

final _samplePng = Uint8List.fromList([
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  10,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  0,
  1,
  0,
  0,
  5,
  0,
  1,
  13,
  10,
  45,
  180,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

void main() {
  test('CustomCenterImageStore saves and clears image', () async {
    final storage = InMemoryCustomImageStorage();
    final store = CustomCenterImageStore(storage: storage);
    expect(store.hasCustomImage, isFalse);

    await store.initialize();
    expect(store.hasCustomImage, isFalse);

    final testBytes = Uint8List.fromList([1, 2, 3, 4]);
    await store.setImage(testBytes);
    expect(store.hasCustomImage, isTrue);
    expect(store.customImageBytes, equals(testBytes));

    // A fresh store instance recovers the persisted image
    final secondStore = CustomCenterImageStore(storage: storage);
    await secondStore.initialize();
    expect(secondStore.hasCustomImage, isTrue);
    expect(secondStore.customImageBytes, equals(testBytes));

    await store.clearImage();
    expect(store.hasCustomImage, isFalse);
    expect(store.customImageBytes, isNull);
  });

  testWidgets('SettingsPage allows choosing and removing custom image', (
    tester,
  ) async {
    final store = CustomCenterImageStore(storage: InMemoryCustomImageStorage());
    await store.initialize();

    final mockPicker = _MockImagePicker(pickedBytes: _samplePng);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          customizationEntitlement: _UnlockedEntitlement(),
          customCenterImageStore: store,
          imagePicker: mockPicker,
          packageInfo: Future.value(
            PackageInfo(
              appName: 'Dali Secure QR',
              packageName: 'com.dalifin.qr',
              version: '1.1.0',
              buildNumber: '1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QR Center Image'), findsOneWidget);
    expect(find.text('Default Dali icon'), findsOneWidget);
    expect(find.text('Choose image'), findsOneWidget);

    // Tap Choose image -> opens ImageCropPage
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();

    expect(find.text('Crop Center Image'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);

    // Apply crop
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(store.hasCustomImage, isTrue);
    expect(find.text('Custom image active'), findsOneWidget);
    expect(find.text('Change image'), findsOneWidget);
    expect(find.text('Crop'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    // Tap Remove
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(store.hasCustomImage, isFalse);
    expect(find.text('Default Dali icon'), findsOneWidget);
    expect(find.text('Choose image'), findsOneWidget);
  });

  testWidgets(
    'QrGenerationSpikePage uses custom image from store when available',
    (tester) async {
      final store = CustomCenterImageStore(
        storage: InMemoryCustomImageStorage(),
      );
      await store.initialize();

      final secureQrService = SecureQrService(PublicSuffixList.parse('com'));
      await tester.pumpWidget(
        MaterialApp(
          home: QrGenerationSpikePage(
            secureQrService: secureQrService,
            customizationEntitlement: _UnlockedEntitlement(),
            customCenterImageStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate QR code'));
      await tester.pumpAndSettle();

      expect(find.byType(GeneratedQrPage), findsOneWidget);
    },
  );
}
