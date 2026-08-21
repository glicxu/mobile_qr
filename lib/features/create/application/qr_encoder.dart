import '../domain/qr_matrix.dart';
import '../domain/qr_center_decoration.dart';

final class QrPayloadTooLongException implements Exception {
  const QrPayloadTooLongException();
}

abstract interface class QrEncoder {
  QrMatrix encode(
    String payload, {
    QrEncodingStrength strength = QrEncodingStrength.standard,
  });
}
