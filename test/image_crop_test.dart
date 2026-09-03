import 'dart:typed_data';

import 'package:dali_qr/features/create/presentation/image_crop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

Uint8List _createTestImageBytes({required int width, required int height}) {
  final img = image_lib.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      img.setPixelRgba(x, y, (x * 255) ~/ width, (y * 255) ~/ height, 128, 255);
    }
  }
  return Uint8List.fromList(image_lib.encodePng(img));
}

void main() {
  testWidgets('ImageCropPage displays crop viewport and toolbar controls', (
    tester,
  ) async {
    final testBytes = _createTestImageBytes(width: 300, height: 150);

    await tester.pumpWidget(
      MaterialApp(
        home: ImageCropPage(imageBytes: testBytes),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Crop Center Image'), findsOneWidget);
    expect(
      find.text('Pan and pinch to frame the center emblem area of your QR code.'),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Rotate 90°'), findsOneWidget);
    expect(find.byTooltip('Reset Framing'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('ImageCropPage rotate and reset buttons function without error', (
    tester,
  ) async {
    final testBytes = _createTestImageBytes(width: 400, height: 200);

    await tester.pumpWidget(
      MaterialApp(
        home: ImageCropPage(imageBytes: testBytes),
      ),
    );
    await tester.pumpAndSettle();

    // Tap rotate
    await tester.tap(find.byTooltip('Rotate 90°'));
    await tester.pumpAndSettle();

    // Tap reset
    await tester.tap(find.byTooltip('Reset Framing'));
    await tester.pumpAndSettle();

    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('ImageCropPage Apply returns 512x512 square cropped PNG', (
    tester,
  ) async {
    final testBytes = _createTestImageBytes(width: 400, height: 300);
    Uint8List? croppedResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                croppedResult = await ImageCropPage.crop(
                  context,
                  imageBytes: testBytes,
                );
              },
              child: const Text('Open Cropper'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Cropper'));
    await tester.pumpAndSettle();

    expect(find.text('Crop Center Image'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(croppedResult, isNotNull);
    final decoded = image_lib.decodeImage(croppedResult!);
    expect(decoded, isNotNull);
    expect(decoded!.width, equals(512));
    expect(decoded.height, equals(512));
  });

  testWidgets('ImageCropPage Cancel returns null', (tester) async {
    final testBytes = _createTestImageBytes(width: 200, height: 200);
    Uint8List? croppedResult = Uint8List(0);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                croppedResult = await ImageCropPage.crop(
                  context,
                  imageBytes: testBytes,
                );
              },
              child: const Text('Open Cropper'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Cropper'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(croppedResult, isNull);
  });
}
