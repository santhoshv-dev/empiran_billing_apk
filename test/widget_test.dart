import 'package:empiran/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows auth entry point', (tester) async {
    await tester.pumpWidget(const EmpiranApp());
    expect(find.text('EMPIRAN TRADERS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
  });
}
