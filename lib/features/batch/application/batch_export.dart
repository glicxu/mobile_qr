import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/batch_session.dart';
import '../../scan/domain/authenticator_payload.dart';

abstract final class BatchCsv {
  static String cell(String value) {
    // Neutralize formulas even when spreadsheet software ignores initial controls.
    final dangerous = RegExp(
      r"^[\s\x00-\x20\x7f-\x9f\u200b-\u200f\u202a-\u202e\u2060-\u206f\ufeff']*[=+\-@＝＋－＠]",
    ).hasMatch(value);
    final literal = dangerous ? "'\t$value" : value;
    return '"${literal.replaceAll('"', '""')}"';
  }

  static String encode(List<BatchItem> items) {
    if (items.any(
      (item) => EphemeralCodePolicy.blocksPersistence(item.value),
    )) {
      throw StateError(
        'Authenticator and passkey setup codes cannot be exported.',
      );
    }
    final rows = [
      [
        'value',
        'format',
        'quantity',
        'first_source',
        'first_capture_utc',
        'last_capture_utc',
      ].map(cell).join(','),
      for (final item in items)
        [
          item.value,
          item.formatKey,
          item.quantity.toString(),
          item.sourceKey,
          item.firstSeenUtc.toIso8601String(),
          item.lastSeenUtc.toIso8601String(),
        ].map(cell).join(','),
    ];
    return '${rows.join('\r\n')}\r\n';
  }
}

final class BatchExport {
  const BatchExport();
  static Future<Directory> _directory() async => Directory(
    '${(await getTemporaryDirectory()).path}/dali_batch_exports',
  ).create(recursive: true);

  static Future<void> cleanupStale({
    Directory? temporaryDirectory,
    DateTime? now,
  }) async {
    final temporary = temporaryDirectory ?? await getTemporaryDirectory();
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(hours: 24));
    // Android's share plugin copies our file into its own cache. Sweep only
    // our named CSV copies there; leave unrelated images/files untouched.
    for (final directory in [
      Directory('${temporary.path}/dali_batch_exports'),
      Directory('${temporary.path}/share_plus'),
    ]) {
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File &&
            entity.uri.pathSegments.last.startsWith('dali_batch_') &&
            entity.path.endsWith('.csv') &&
            (await entity.lastModified()).isBefore(cutoff)) {
          await entity.delete();
        }
      }
    }
  }

  Future<void> share(
    List<BatchItem> items, {
    Rect? origin,
    Future<void> Function(File)? shareFile,
    Directory? directory,
  }) async {
    final target = directory ?? await _directory();
    final file = File(
      '${target.path}/dali_batch_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}.csv',
    );
    try {
      await file.writeAsBytes(
        utf8.encode('\ufeff${BatchCsv.encode(items)}'),
        flush: true,
      );
      if (shareFile != null) {
        await shareFile(file);
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'text/csv')],
            sharePositionOrigin: origin,
          ),
        );
      }
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}
