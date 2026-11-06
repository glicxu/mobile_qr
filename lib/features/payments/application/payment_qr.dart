import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../create/data/dart_qr_encoder.dart';
import '../../create/data/qr_png_renderer.dart';
import '../../create/application/qr_png_validator.dart';
import '../../scan/domain/link_inspection.dart';
import '../domain/payment_workspace.dart';

final class PaymentQrArtifact {
  const PaymentQrArtifact({
    required this.link,
    required this.qrPng,
    required this.cardPng,
  });
  final String link;
  final Uint8List qrPng, cardPng;
}

abstract final class PaymentQr {
  static Future<PaymentQrArtifact> render(
    PaymentTemplate template, {
    bool sample = false,
  }) async {
    final link = PaymentPolicy.link(template.link);
    final qr = const QrPngRenderer()
        .render(const DartQrEncoder().encode(link), size: 512)
        .bytes;
    final codec = await ui.instantiateImageCodec(qr);
    final frame = await codec.getNextFrame();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    void text(
      String value,
      double y,
      double size, {
      FontWeight weight = FontWeight.normal,
      int lines = 2,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: Colors.black,
            fontSize: size,
            fontWeight: weight,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: lines,
        ellipsis: '…',
      )..layout(maxWidth: 576);
      painter.paint(canvas, Offset((640 - painter.width) / 2, y));
      painter.dispose();
    }

    text(
      sample ? 'DEMO · NOT FOR PAYMENT' : 'Payment link',
      24,
      22,
      weight: FontWeight.bold,
    );
    text(template.label, 65, 28, weight: FontWeight.bold);
    text(const LinkInspector().inspect(link).asciiHost!, 142, 18, lines: 1);
    canvas.drawImage(
      frame.image,
      const Offset(64, 170),
      Paint()..filterQuality = FilterQuality.none,
    );
    text('Confirm recipient and amount at checkout.', 710, 18);
    text('Dali QR', 765, 16);
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(640, 820);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Payment card could not be rendered.');
      final card = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (!const QrPngValidator().containsExactPayload(qr, link) ||
          !const QrPngValidator().containsExactPayload(card, link)) {
        throw StateError('The payment QR could not be validated.');
      }
      return PaymentQrArtifact(link: link, qrPng: qr, cardPng: card);
    } finally {
      image?.dispose();
      picture.dispose();
      frame.image.dispose();
      codec.dispose();
    }
  }
}
