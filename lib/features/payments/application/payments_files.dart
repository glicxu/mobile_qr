import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract final class PaymentsFiles {
  static Future<void> cleanup() async {
    final temporary = await getTemporaryDirectory();
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    for (final dir in [
      Directory('${temporary.path}/dali_payments_exports'),
      Directory('${temporary.path}/share_plus'),
    ]) {
      if (!await dir.exists()) continue;
      await for (final file in dir.list(followLinks: false)) {
        if (file is File &&
            file.uri.pathSegments.last.startsWith('dali_payments_') &&
            (await file.lastModified()).isBefore(cutoff)) {
          await file.delete();
        }
      }
    }
  }

  static Future<void> share(
    Uint8List bytes, {
    required bool records,
    Rect? origin,
  }) async {
    final temporary = await getTemporaryDirectory();
    final directory = await Directory(
      '${temporary.path}/dali_payments_exports',
    ).create(recursive: true);
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    final file = File(
      '${directory.path}/dali_payments_$id.${records ? 'json' : 'png'}',
    );
    try {
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: records ? 'application/json' : 'image/png',
            ),
          ],
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}
