import 'package:flutter_test/flutter_test.dart';
import 'package:boosterdose_admin_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BoosterDoseAdminApp());
    expect(find.byType(BoosterDoseAdminApp), findsOneWidget);
  }, skip: true); // Skips full app integration test requiring live HTTP/SharedPreferences
}
