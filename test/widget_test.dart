import 'package:flutter_test/flutter_test.dart';
import 'package:proctor/main.dart';

void main() {
  testWidgets('shows login screen on startup', (WidgetTester tester) async {
    await tester.pumpWidget(const ProctorBootstrap());
    await tester.pumpAndSettle();

    expect(find.text('Proctor App'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });
}
