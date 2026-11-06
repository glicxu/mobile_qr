import 'dart:convert';

import 'package:integration_test/integration_test.dart';

import '../test/universal_scanner_flow_test.dart' as flows;
import 'barcode_fixture_data.g.dart';
import 'optional_format_data.g.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final formats = <String>{};
  final fixtures = <Map<String, dynamic>>[];
  for (final fixture in [
    ...jsonDecode(scannerFixturesJson) as List,
    ...jsonDecode(optionalFormatFixturesJson) as List,
  ]) {
    final map = fixture as Map<String, dynamic>;
    final format = (map['symbolFormat'] ?? map['format']) as String;
    if (formats.add(format)) fixtures.add(map);
  }
  flows.registerUniversalScannerFlows(fixtures);
}
