import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:dali_qr/features/scan/presentation/qr_scanner_page.dart';
import 'package:dali_qr/features/secure_qr/domain/public_suffix_list.dart';
import 'package:dali_qr/features/secure_qr/domain/secure_qr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = SecureQrService(PublicSuffixList.parse('com'));

  test('Secure QR verification is calculated for QR results', () {
    const code = ScannedCode(
      value: 'https://example.com',
      format: ScannedCodeFormat.qrCode,
      source: ScanSource.camera,
    );

    expect(verificationForScannedCode(service, code), isA<SecureQrResult>());
  });

  test('Secure QR verification is never applied to a 1D barcode', () {
    const code = ScannedCode(
      value: 'https://example.com',
      format: ScannedCodeFormat.code128,
      source: ScanSource.sharedImage,
    );

    expect(verificationForScannedCode(service, code), isNull);
  });
}
