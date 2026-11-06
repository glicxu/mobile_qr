import 'package:integration_test/integration_test.dart';

import '../test/identifier_details_test.dart' as flows;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The runner needs its debug network transport. The unit version separately
  // rejects HTTP clients. Both versions reject every external launch.
  flows.registerIdentifierDetailsTests(rejectNetwork: false);
}
