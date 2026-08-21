import 'package:qr/qr.dart';

import '../application/qr_encoder.dart';
import '../domain/qr_center_decoration.dart';
import '../domain/qr_matrix.dart';

final class DartQrEncoder implements QrEncoder {
  const DartQrEncoder();

  @override
  QrMatrix encode(
    String payload, {
    QrEncodingStrength strength = QrEncodingStrength.standard,
  }) {
    final qrPayload = QrPayload()
      ..addECI(QrEciValue.utf8)
      ..addString(payload);
    final QrCode code;
    try {
      code = QrCode(
        payload: qrPayload,
        errorCorrectLevel: strength == QrEncodingStrength.decorated
            ? QrErrorCorrectLevel.high
            : QrErrorCorrectLevel.medium,
      );
    } on InputTooLongException {
      throw const QrPayloadTooLongException();
    }
    final image = QrImage(code);

    return QrMatrix(
      version: code.typeNumber,
      maskPattern: image.maskPattern,
      moduleCount: image.moduleCount,
      modules: <bool>[
        for (var row = 0; row < image.moduleCount; row++)
          for (var column = 0; column < image.moduleCount; column++)
            image.isDark(row, column),
      ],
    );
  }
}
