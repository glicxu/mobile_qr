import '../../secure_qr/domain/secure_qr_service.dart';
import '../domain/scanned_code.dart';

QrVerificationResult? verificationForScannedCode(
  SecureQrService service,
  ScannedCode code,
) {
  if (code.format != ScannedCodeFormat.qrCode) return null;
  return service.calculateForPayload(code.value);
}
