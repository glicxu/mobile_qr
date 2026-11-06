import 'dart:convert';

import 'package:integration_test/integration_test.dart';

import '../test/universal_scanner_flow_test.dart' as flows;
import 'barcode_fixture_data.g.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The zero-prefixed EAN-13/UPC-A pair is deliberately tested separately in
  // the main target. Also validate a native EAN-13 result without that alias.
  flows.registerUniversalScannerFlows([
    (jsonDecode(scannerFixturesJson) as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((fixture) => fixture['id'] == 'ean13_book'),
  ]);
}
