import 'package:integration_test/integration_test.dart';

import '../test/link_review_flow_test.dart' as flows;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Reuse the review/cancellation contract on-device, with external launches
  // stubbed so these tests never open a browser or send decoded contents.
  // The device test runner uses network transport for reporting. The unit
  // version separately rejects HTTP clients while exercising the same UI.
  flows.registerLinkReviewTests(rejectNetwork: false);
}
