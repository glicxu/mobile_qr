import 'dart:typed_data';

import 'package:dali_qr/features/create/application/custom_center_image_store.dart';
import 'package:dali_qr/features/create/presentation/generated_qr_page.dart';
import 'package:dali_qr/features/create/presentation/image_crop_page.dart';
import 'package:dali_qr/features/monetization/application/customization_entitlement.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:dali_qr/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
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

final class _LockedEntitlement extends ChangeNotifier
    implements CustomizationEntitlement {
  var purchaseCalls = 0;
  var restoreCalls = 0;
  var _unlocked = false;

  @override
  bool get isUnlocked => _unlocked;
  @override
  bool get isStoreAvailable => true;
  @override
  bool get isBusy => false;
  @override
  String? get message => null;
  @override
  String? get price => r'$1.99';
  @override
  Future<void> refresh() async {}
  @override
  Future<void> purchase() async {
    purchaseCalls++;
    _unlocked = true;
    notifyListeners();
  }

  @override
  Future<void> restore() async {
    restoreCalls++;
  }
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

Uint8List _horizontalBandsPng() {
  final source = image_lib.Image(width: 900, height: 300);
  image_lib.fillRect(
    source,
    x1: 0,
    y1: 0,
    x2: 299,
    y2: 299,
    color: image_lib.ColorRgb8(255, 0, 0),
  );
  image_lib.fillRect(
    source,
    x1: 300,
    y1: 0,
    x2: 599,
    y2: 299,
    color: image_lib.ColorRgb8(0, 255, 0),
  );
  image_lib.fillRect(
    source,
    x1: 600,
    y1: 0,
    x2: 899,
    y2: 299,
    color: image_lib.ColorRgb8(0, 0, 255),
  );
  return Uint8List.fromList(image_lib.encodePng(source));
}

void main() {
  testWidgets('crop preview pans and exports the visible source pixels', (
    tester,
  ) async {
    Uint8List? cropResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  cropResult = await ImageCropPage.crop(
                    context,
                    imageBytes: _horizontalBandsPng(),
                  );
                },
                child: const Text('Open crop'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open crop'));
    await tester.pumpAndSettle();

    final viewerFinder = find.byType(InteractiveViewer);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    expect(viewer.constrained, isFalse);
    final controller = viewer.transformationController!;
    final initialTranslation = controller.value.getTranslation().x;

    // Moving the image right reveals the red band to the left of the green
    // center band. This gesture was ignored when the child was constrained.
    await tester.drag(viewerFinder, const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(
      controller.value.getTranslation().x,
      greaterThan(initialTranslation),
    );

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final cropped = image_lib.decodePng(cropResult!);
    expect(cropped, isNotNull);
    expect(cropped!.width, 512);
    expect(cropped.height, 512);
    final left = cropped.getPixel(48, 256);
    final right = cropped.getPixel(464, 256);
    expect(left.r, greaterThan(240));
    expect(left.g, lessThan(15));
    expect(right.g, greaterThan(240));
    expect(right.r, lessThan(15));
  });

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

  testWidgets('SettingsPage explains customization and offers purchase paths', (
    tester,
  ) async {
    final entitlement = _LockedEntitlement();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          customizationEntitlement: entitlement,
          packageInfo: Future.value(
            PackageInfo(
              appName: 'Dali QR',
              packageName: 'com.dalifin.qr',
              version: '1.2.0',
              buildNumber: '1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dali QR Custom'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Benefits'), findsOneWidget);
    expect(find.text('Add your own image or logo to QR codes'), findsOneWidget);
    expect(
      find.text('Save, copy, and share your personalized QR codes'),
      findsOneWidget,
    );
    expect(
      find.text('Keep and access your QR history for longer than one week'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Restore purchases'));
    await tester.tap(find.text('Restore purchases'));
    await tester.pump();
    expect(entitlement.restoreCalls, 1);

    await tester.tap(find.text(r'Unlock for $1.99'));
    await tester.pump();
    expect(entitlement.purchaseCalls, 1);
    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.text('Lifetime customization unlocked'), findsOneWidget);
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
              appName: 'Dali QR',
              packageName: 'com.dalifin.qr',
              version: '1.2.0',
              buildNumber: '1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QR Center Image'), findsOneWidget);
    expect(find.text('Default Dali icon'), findsOneWidget);
    expect(find.bySemanticsLabel('Default Dali center icon'), findsOneWidget);
    expect(find.text('Choose image'), findsOneWidget);

    // Tap Choose image -> opens ImageCropPage
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
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
    await tester.ensureVisible(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(store.hasCustomImage, isFalse);
    expect(find.text('Default Dali icon'), findsOneWidget);
    expect(find.bySemanticsLabel('Default Dali center icon'), findsOneWidget);
    expect(find.text('Choose image'), findsOneWidget);
  });

  testWidgets('center image actions wrap on a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = CustomCenterImageStore(storage: InMemoryCustomImageStorage());
    await store.initialize();
    await store.setImage(_samplePng);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          customizationEntitlement: _UnlockedEntitlement(),
          customCenterImageStore: store,
          imagePicker: _MockImagePicker(pickedBytes: _samplePng),
          packageInfo: Future.value(
            PackageInfo(
              appName: 'Dali QR',
              packageName: 'com.dalifin.qr',
              version: '1.2.0',
              buildNumber: '1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Remove'), 300);
    await tester.pumpAndSettle();

    expect(find.text('Change image'), findsOneWidget);
    expect(find.text('Crop'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
