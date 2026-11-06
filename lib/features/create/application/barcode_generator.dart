import 'dart:convert';
import '../../scan/domain/authenticator_payload.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/oned.dart' as oned;
import 'package:zxing_lib/zxing.dart' as zx;

import '../../scan/domain/scanned_code.dart';

final class GeneratedBarcode {
  const GeneratedBarcode({
    required this.value,
    required this.format,
    required this.png,
    required this.width,
    required this.height,
  });
  final String value;
  final ScannedCodeFormat format;
  final Uint8List png;
  final int width;
  final int height;
}

abstract final class BarcodeGenerator {
  static final formats = List<ScannedCodeFormat>.unmodifiable(
    ScannedCodeFormat.values.where((f) => f != ScannedCodeFormat.unknown),
  );

  static String help(ScannedCodeFormat format) => switch (format) {
    ScannedCodeFormat.qrCode => 'Text, links, and other QR content.',
    ScannedCodeFormat.upcA =>
      'Exactly 12 digits, including a valid check digit.',
    ScannedCodeFormat.upcE =>
      'Exactly 8 digits, including number system 0 or 1 and a valid check digit.',
    ScannedCodeFormat.ean8 =>
      'Exactly 8 digits, including a valid check digit.',
    ScannedCodeFormat.ean13 =>
      'Exactly 13 digits, including a valid check digit.',
    ScannedCodeFormat.itf14 =>
      'Exactly 14 digits, including a valid GTIN check digit.',
    ScannedCodeFormat.code39 || ScannedCodeFormat.code93 =>
      'Uppercase A–Z, digits, spaces, and - . \$ / + %. Maximum 80 characters.',
    ScannedCodeFormat.code128 =>
      'ASCII text, up to 80 characters. Content is preserved exactly.',
    ScannedCodeFormat.codabar =>
      'Start and end with A, B, C, or D. Inside use digits and - \$ : / . +. Maximum 80 characters.',
    ScannedCodeFormat.dataMatrix =>
      'Latin-1 text up to 1,200 characters. Use QR, PDF417, or Aztec for other languages and emoji.',
    _ =>
      'Text up to 1,200 UTF-8 bytes. Content is preserved exactly; capacity varies by format.',
  };

  static Future<GeneratedBarcode> generate(
    String value,
    ScannedCodeFormat format,
  ) {
    validate(value, format);
    return compute(_renderBarcode, (value, format));
  }

  static void validate(String value, ScannedCodeFormat format) {
    if (EphemeralCodePolicy.isAuthenticator(value)) {
      throw const FormatException('Authenticator setup codes are scan-only.');
    }
    if (format == ScannedCodeFormat.qrCode ||
        format == ScannedCodeFormat.unknown) {
      throw const FormatException('Choose a supported barcode format.');
    }
    if (value.isEmpty) {
      throw const FormatException('Enter content for the code.');
    }
    final length = switch (format) {
      ScannedCodeFormat.upcA => 12,
      ScannedCodeFormat.upcE || ScannedCodeFormat.ean8 => 8,
      ScannedCodeFormat.ean13 => 13,
      ScannedCodeFormat.itf14 => 14,
      _ => null,
    };
    if (length != null) {
      if (value.length != length || !RegExp(r'^[0-9]+$').hasMatch(value)) {
        throw FormatException(
          '${format.label} requires exactly $length digits, including the check digit.',
        );
      }
      var checked = value;
      if (format == ScannedCodeFormat.upcE) {
        if (!'01'.contains(value[0])) {
          throw const FormatException('UPC-E number system must be 0 or 1.');
        }
        final canonical = switch (value[6]) {
          '3' => int.parse(value[3]) >= 3,
          '4' => value[4] != '0',
          '5' || '6' || '7' || '8' || '9' => value[5] != '0',
          _ => true,
        };
        if (!canonical) {
          throw const FormatException(
            'This UPC-E value does not follow canonical zero-suppression rules.',
          );
        }
        checked = oned.UPCEReader.convertUPCEtoUPCA(value);
      }
      if (!oned.UPCEANReader.checkStandardUPCEANChecksum(checked)) {
        throw FormatException(
          '${format.label} has an invalid check digit. Enter the complete identifier.',
        );
      }
      return;
    }
    final twoD = [
      ScannedCodeFormat.dataMatrix,
      ScannedCodeFormat.pdf417,
      ScannedCodeFormat.aztec,
    ].contains(format);
    if (twoD) {
      if (value.length > 1200) {
        throw const FormatException('Use 1,200 encoded bytes or fewer.');
      }
      if (format == ScannedCodeFormat.dataMatrix &&
          value.runes.any((r) => r > 0xff)) {
        throw const FormatException(
          'Data Matrix supports Latin-1 text. Choose QR, PDF417, or Aztec for this content.',
        );
      }
      if (format != ScannedCodeFormat.dataMatrix &&
          utf8.encode(value).length > 1200) {
        throw const FormatException('Use 1,200 UTF-8 bytes or fewer.');
      }
      // Reject unpaired surrogates rather than silently substituting U+FFFD.
      if (utf8.decode(utf8.encode(value)) != value) {
        throw const FormatException(
          'The content contains an invalid Unicode character.',
        );
      }
      return;
    }
    if (value.length > 80) {
      throw const FormatException(
        'Use 80 characters or fewer for this barcode.',
      );
    }
    final valid = switch (format) {
      ScannedCodeFormat.code128 => value.codeUnits.every((c) => c <= 127),
      ScannedCodeFormat.code39 || ScannedCodeFormat.code93 => RegExp(
        r'^[A-Z0-9 .\-$/+%]+$',
      ).hasMatch(value),
      ScannedCodeFormat.codabar => RegExp(
        r'^[A-D][0-9\-$:/.+]+[A-D]$',
      ).hasMatch(value),
      _ => false,
    };
    if (!valid) throw FormatException(help(format));
  }
}

GeneratedBarcode _renderBarcode((String, ScannedCodeFormat) request) {
  final (value, format) = request;
  final type = switch (format) {
    ScannedCodeFormat.upcA => zx.BarcodeFormat.upcA,
    ScannedCodeFormat.upcE => zx.BarcodeFormat.upcE,
    ScannedCodeFormat.ean8 => zx.BarcodeFormat.ean8,
    ScannedCodeFormat.ean13 => zx.BarcodeFormat.ean13,
    ScannedCodeFormat.code128 => zx.BarcodeFormat.code128,
    ScannedCodeFormat.code39 => zx.BarcodeFormat.code39,
    ScannedCodeFormat.code93 => zx.BarcodeFormat.code93,
    ScannedCodeFormat.codabar => zx.BarcodeFormat.codabar,
    ScannedCodeFormat.itf14 => zx.BarcodeFormat.itf,
    ScannedCodeFormat.dataMatrix => zx.BarcodeFormat.dataMatrix,
    ScannedCodeFormat.pdf417 => zx.BarcodeFormat.pdf417,
    ScannedCodeFormat.aztec => zx.BarcodeFormat.aztec,
    _ => throw const FormatException('Unsupported barcode format.'),
  };
  try {
    final matrix = zx.MultiFormatWriter().encode(
      value,
      type,
      0,
      0,
      zx.EncodeHint(
        margin: 0,
        // ML Kit treats the Data Matrix ECI assignment as content. Latin-1
        // uses the standard default encoding without an ECI marker.
        characterSet: format == ScannedCodeFormat.dataMatrix ? null : 'UTF-8',
      ),
    );
    final linear = ![
      ScannedCodeFormat.dataMatrix,
      ScannedCodeFormat.pdf417,
      ScannedCodeFormat.aztec,
    ].contains(format);
    final quiet = linear ? 10 : 4;
    final bearer = format == ScannedCodeFormat.itf14 ? 5 : 0;
    final padding = quiet + bearer;
    final horizontalPadding = padding + (bearer > 0 ? quiet : 0);
    final moduleHeight = linear ? 60 : matrix.height;
    final columns = matrix.width + 2 * horizontalPadding;
    final rows = moduleHeight + 2 * padding;
    final scale = math.max(2, math.min(8, 1024 ~/ math.max(columns, rows)));
    final width = columns * scale, height = rows * scale;
    if (width > 4096 || height > 4096 || width * height > 4 * 1024 * 1024) {
      throw const FormatException(
        'This code is too large. Shorten the content.',
      );
    }
    final image = img.Image(width: width, height: height, numChannels: 3);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final black = img.ColorRgb8(0, 0, 0);
    for (var y = 0; y < matrix.height; y++) {
      for (var x = 0; x < matrix.width; x++) {
        if (!matrix.get(x, y)) continue;
        final left = (x + horizontalPadding) * scale;
        final top = (y + padding) * scale;
        img.fillRect(
          image,
          x1: left,
          y1: top,
          x2: left + scale - 1,
          y2: top + (linear ? moduleHeight : 1) * scale - 1,
          color: black,
        );
      }
    }
    if (bearer > 0) {
      final a = quiet * scale, b = (quiet + bearer) * scale;
      img.fillRect(
        image,
        x1: a,
        y1: a,
        x2: width - a - 1,
        y2: b - 1,
        color: black,
      );
      img.fillRect(
        image,
        x1: a,
        y1: height - b,
        x2: width - a - 1,
        y2: height - a - 1,
        color: black,
      );
      img.fillRect(
        image,
        x1: a,
        y1: a,
        x2: b - 1,
        y2: height - a - 1,
        color: black,
      );
      img.fillRect(
        image,
        x1: width - b,
        y1: a,
        x2: width - a - 1,
        y2: height - a - 1,
        color: black,
      );
    }
    return GeneratedBarcode(
      value: value,
      format: format,
      png: Uint8List.fromList(img.encodePng(image)),
      width: width,
      height: height,
    );
  } on FormatException {
    rethrow;
  } on Object {
    throw FormatException(
      'This content cannot be encoded as ${format.label}. Check its characters or shorten it.',
    );
  }
}
