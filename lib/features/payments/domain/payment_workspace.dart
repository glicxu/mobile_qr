import 'dart:convert';
import '../../scan/domain/link_inspection.dart';

enum PaymentTemplateState { draft, ready, archived }

final class PaymentProfile {
  const PaymentProfile({
    required this.id,
    required this.label,
    required this.link,
    required this.notes,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  final String id, label, link, notes;
  final DateTime createdAtUtc, updatedAtUtc;
}

final class PaymentTemplate {
  const PaymentTemplate({
    required this.id,
    required this.profileId,
    required this.label,
    required this.link,
    required this.state,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  final String id, profileId, label, link;
  final PaymentTemplateState state;
  final DateTime createdAtUtc, updatedAtUtc;
}

abstract interface class PaymentsRepository {
  Future<List<PaymentProfile>> profiles();
  Future<List<PaymentTemplate>> templates();
  Future<void> putProfile(PaymentProfile profile);
  Future<void> putTemplate(PaymentTemplate template);
  Future<void> deleteProfile(String id);
  Future<void> deleteTemplate(String id);
  Future<void> clear();
  Future<void> close();
}

abstract final class PaymentPolicy {
  static const sampleLink = 'https://example.com/dali-payments-demo';
  static String text(
    String value,
    String field, {
    int max = 80,
    bool required = true,
  }) {
    final result = value.trim();
    if ((required && result.isEmpty) ||
        result.length > max ||
        RegExp(
          r'[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]',
        ).hasMatch(result)) {
      throw FormatException(
        'Enter $field using ${required ? '1' : '0'}–$max characters without control characters.',
      );
    }
    return result;
  }

  static String link(String raw) {
    final inspection = const LinkInspector().inspect(raw);
    final uri = inspection.uri;
    if (raw.length > 2000 ||
        utf8.encode(raw).length > 2000 ||
        !inspection.canOpen ||
        inspection.scheme != 'https' ||
        uri == null ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443) {
      throw const FormatException(
        'Enter an HTTPS checkout link without login credentials or a custom port.',
      );
    }
    final host = inspection.asciiHost!.toLowerCase().replaceFirst(
      RegExp(r'\.$'),
      '',
    );
    if (!host.contains('.') ||
        host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.contains(':') ||
        RegExp(r'^[0-9.]+$').hasMatch(host)) {
      throw const FormatException(
        'Use a public HTTPS website, not a local host or IP address.',
      );
    }
    return raw; // Never trim, rebuild, append amount parameters, or fetch it.
  }
}
