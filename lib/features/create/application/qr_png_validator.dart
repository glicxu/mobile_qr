import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;
import 'package:zxing2/qrcode.dart';

final class QrPngValidator {
  const QrPngValidator();

  bool containsExactPayload(Uint8List pngBytes, String expectedPayload) {
    try {
      return _decode(pngBytes) == expectedPayload;
    } on Object {
      try {
        return _decode(pngBytes, pure: true) == expectedPayload;
      } on Object {
        return false;
      }
    }
  }

  String _decode(Uint8List pngBytes, {bool pure = false}) {
    final decodedImage = image_lib.decodePng(pngBytes);
    if (decodedImage == null) throw const FormatException('Invalid QR PNG.');
    final rgba = decodedImage
        .convert(numChannels: 4)
        .getBytes(order: image_lib.ChannelOrder.rgba);
    final source = RGBLuminanceSource(
      decodedImage.width,
      decodedImage.height,
      rgba.buffer.asInt32List(rgba.offsetInBytes, rgba.lengthInBytes ~/ 4),
    );
    final hints = DecodeHints();
    if (pure) hints.put(DecodeHintType.pureBarcode);
    final result = QRCodeReader().decode(
      BinaryBitmap(HybridBinarizer(source)),
      hints: hints,
    );
    if (!result.text.contains('\u{fffd}')) return result.text;

    final byteSegments =
        result.resultMetadata[ResultMetadataType.byteSegments]
            as List<Int8List>?;
    if (byteSegments == null) return result.text;
    return byteSegments
        .map(
          (segment) => utf8.decode(segment.map((byte) => byte & 0xff).toList()),
        )
        .join();
  }
}
