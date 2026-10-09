import 'package:integration_test/integration_test.dart';

import '../test/performance_flow_scenarios.dart';

/// Device / emulator run of the Performance flow:
///   flutter test integration_test/performance_flow_test.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  definePerformanceFlowTests();
}
