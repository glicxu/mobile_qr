import 'package:flutter/services.dart';

import '../domain/public_suffix_list.dart';
import '../domain/secure_qr_service.dart';

final class SecureQrLoader {
  const SecureQrLoader._();

  static Future<SecureQrService> load() async {
    final source = await rootBundle.loadString('assets/public_suffix_list.dat');
    return SecureQrService(PublicSuffixList.parse(source));
  }
}
