import 'dart:typed_data';

enum QrCenterDecorationMode { none, verificationCode, daliIcon }

final class QrCenterDecoration {
  const QrCenterDecoration.verificationCode(this.verificationCode)
    : mode = QrCenterDecorationMode.verificationCode,
      iconPngBytes = null;

  const QrCenterDecoration.daliIcon(this.iconPngBytes)
    : mode = QrCenterDecorationMode.daliIcon,
      verificationCode = null;

  final QrCenterDecorationMode mode;
  final String? verificationCode;
  final Uint8List? iconPngBytes;
}

enum QrEncodingStrength { standard, decorated }
