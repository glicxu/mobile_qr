import 'package:punycoder/punycoder.dart';

final class PublicSuffixList {
  PublicSuffixList._(this._exact, this._wildcard, this._exceptions);

  factory PublicSuffixList.parse(String source) {
    final exact = <String>{};
    final wildcard = <String>{};
    final exceptions = <String>{};

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('//')) continue;
      if (line.startsWith('!')) {
        exceptions.add(_asciiRule(line.substring(1)));
      } else if (line.startsWith('*.')) {
        wildcard.add(_asciiRule(line.substring(2)));
      } else {
        exact.add(_asciiRule(line));
      }
    }
    return PublicSuffixList._(exact, wildcard, exceptions);
  }

  final Set<String> _exact;
  final Set<String> _wildcard;
  final Set<String> _exceptions;

  static String _asciiRule(String rule) {
    final lower = rule.toLowerCase();
    final isAscii = lower.codeUnits.every((codeUnit) => codeUnit <= 0x7f);
    return isAscii ? lower : domainToAscii(lower);
  }

  /// Returns the eTLD+1 using the prevailing-rule algorithm from the PSL.
  /// Private rules are included because tenants such as `user.github.io`
  /// must not share one Secure QR domain fingerprint.
  String? registrableDomain(String asciiHost) {
    final host = asciiHost.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (host.isEmpty || _isIpAddress(host)) return null;

    final labels = host.split('.');
    if (labels.any((label) => label.isEmpty)) return null;
    if (labels.length == 1) return null;

    var prevailingRuleLength = 1; // The implicit "*" rule.
    var exceptionRuleLength = 0;

    for (var index = 0; index < labels.length; index++) {
      final candidate = labels.sublist(index).join('.');
      final candidateLength = labels.length - index;
      if (_exceptions.contains(candidate) &&
          candidateLength > exceptionRuleLength) {
        exceptionRuleLength = candidateLength;
      }
      if (_exact.contains(candidate) &&
          candidateLength > prevailingRuleLength) {
        prevailingRuleLength = candidateLength;
      }
      if (index + 1 < labels.length) {
        final wildcardSuffix = labels.sublist(index + 1).join('.');
        if (_wildcard.contains(wildcardSuffix) &&
            candidateLength > prevailingRuleLength) {
          prevailingRuleLength = candidateLength;
        }
      }
    }

    if (exceptionRuleLength > 0) {
      prevailingRuleLength = exceptionRuleLength - 1;
    }
    if (labels.length <= prevailingRuleLength) return null;
    return labels.sublist(labels.length - prevailingRuleLength - 1).join('.');
  }

  static bool _isIpAddress(String host) {
    if (host.contains(':')) return true; // IPv6 is returned without brackets.
    final parts = host.split('.');
    if (parts.length != 4) return false;
    return parts.every((part) {
      final value = int.tryParse(part);
      return value != null && value >= 0 && value <= 255;
    });
  }
}
