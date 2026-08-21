import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract final class QrShare {
  static Future<void> sharePng({
    required Uint8List bytes,
    required String payload,
    Rect? sharePositionOrigin,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/dali-secure-qr.png');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: payload,
        subject: 'Dali Secure QR',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
