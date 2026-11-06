import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing_lib/common.dart' as common;
import 'package:zxing_lib/multi.dart' as multi;
import 'package:zxing_lib/zxing.dart' as zx;

import '../domain/scanned_code.dart';

final class ImageDecodeException implements Exception {
  const ImageDecodeException(this.message);
  final String message;
}

/// Runs only on still images, off the UI isolate, with a killable time budget.
/// Native scanning remains the live-camera decoder. No remote service is used.
final class OfflineImageDecoder {
  const OfflineImageDecoder({this.timeout = const Duration(seconds: 6)});
  final Duration timeout;
  static const maxBytes = 25 * 1024 * 1024;
  static const maxPixels = 16 * 1024 * 1024;
  static const maxDecodeSide = 1600;

  Future<List<ScannedCode>> decodeFile(
    String path, {
    required ScanSource source,
  }) async {
    final file = File(path);
    if (await file.length() > maxBytes) {
      throw const ImageDecodeException('Choose an image smaller than 25 MB.');
    }
    return decodeBytes(await file.readAsBytes(), source: source);
  }

  Future<List<ScannedCode>> decodeBytes(
    Uint8List bytes, {
    required ScanSource source,
  }) async {
    if (bytes.length > maxBytes) {
      throw const ImageDecodeException('Choose an image smaller than 25 MB.');
    }
    final receive = ReceivePort();
    Isolate? worker;
    try {
      worker = await Isolate.spawn(_decode, (receive.sendPort, bytes, source));
      final response = await receive.first.timeout(timeout);
      if (response is List<ScannedCode>) return response;
      throw ImageDecodeException(response as String);
    } on TimeoutException {
      throw const ImageDecodeException(
        'Image reading timed out. Crop the image closer to the code and try again.',
      );
    } finally {
      worker?.kill(priority: Isolate.immediate);
      receive.close();
    }
  }

  static void _decode((SendPort, Uint8List, ScanSource) input) {
    final (port, bytes, source) = input;
    try {
      final decoder = img.findDecoderForData(bytes);
      final info = decoder?.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) {
        port.send(
          'This image could not be read. Choose a PNG, JPEG, or another supported image.',
        );
        return;
      }
      if (info.width * info.height > maxPixels ||
          max(info.width, info.height) > 16384) {
        port.send(
          'This image is too large to read safely. Crop or resize it to 16 megapixels or less.',
        );
        return;
      }
      var image = decoder!.decodeFrame(0);
      if (image == null) {
        port.send('This image could not be read.');
        return;
      }
      image = img.bakeOrientation(image);
      if (max(image.width, image.height) > maxDecodeSide) {
        image = img.copyResize(
          image,
          width: image.width >= image.height ? maxDecodeSide : null,
          height: image.height > image.width ? maxDecodeSide : null,
          interpolation: img.Interpolation.average,
        );
      }
      final luminance = Uint8List(image.width * image.height);
      for (final pixel in image) {
        // Composite transparency over white; do not turn a transparent quiet
        // zone into a black frame around the barcode.
        final alpha = pixel.aNormalized;
        final gray = (pixel.r + 2 * pixel.g + pixel.b) / 4;
        luminance[pixel.y * image.width + pixel.x] =
            (gray * alpha + 255 * (1 - alpha)).round().clamp(0, 255);
      }
      final bitmap = zx.BinaryBitmap(
        common.HybridBinarizer(
          zx.RGBLuminanceSource.orig(image.width, image.height, luminance),
        ),
      );
      final codes = <ScannedCode>[];
      final regions = <zx.BinaryBitmap>[bitmap];
      // Both native and ZXing Data Matrix detectors favor centered symbols.
      // Bounded overlapping strips recover common off-center/mixed layouts.
      for (final fraction in [0.4, 0.25]) {
        if (image.width >= 400) {
          final width = (image.width * fraction).ceil();
          for (var i = 0; i < 3; i++) {
            regions.add(
              bitmap.crop(
                (image.width - width) * i ~/ 2,
                0,
                width,
                image.height,
              ),
            );
          }
        }
        if (image.height >= 400) {
          final height = (image.height * fraction).ceil();
          for (var i = 0; i < 3; i++) {
            regions.add(
              bitmap.crop(
                0,
                (image.height - height) * i ~/ 2,
                image.width,
                height,
              ),
            );
          }
        }
      }
      // Separate readers preserve equal text encoded in different formats.
      for (final entry in const {
        zx.BarcodeFormat.dataMatrix: ScannedCodeFormat.dataMatrix,
        zx.BarcodeFormat.pdf417: ScannedCodeFormat.pdf417,
        zx.BarcodeFormat.aztec: ScannedCodeFormat.aztec,
      }.entries) {
        final values = <String>{};
        for (final region in regions) {
          if (values.length >= 10) break;
          try {
            final results =
                multi.GenericMultipleBarcodeReader(
                  zx.MultiFormatReader(),
                ).decodeMultiple(
                  region,
                  zx.DecodeHint(possibleFormats: [entry.key], tryHarder: true),
                );
            for (final result in results) {
              if (values.length >= 10) break;
              if (result.text.isEmpty || !values.add(result.text)) continue;
              codes.add(
                ScannedCode(
                  value: result.text,
                  format: entry.value,
                  source: source,
                ),
              );
              // ZXing's rawBytes is decoder data, not necessarily original payload
              // bytes. Do not mislabel or persist it as the source byte stream.
            }
          } on zx.ReaderException {
            // Absence in one region must not hide other results.
          }
        }
      }
      port.send(orderScannedCodes(codes));
    } on Object {
      port.send(
        'This image could not be read. Try another image or crop closer to the code.',
      );
    }
  }
}
