// Smoke test for the Figma-derived Pacer frontend (copyright-free placeholders).
import 'package:flutter_test/flutter_test.dart';

import 'package:pacer/main.dart';

void main() {
  testWidgets('GetStarted screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PacerApp());
    await tester.pumpAndSettle();
    expect(find.text('Pacer, siap membantu!'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
