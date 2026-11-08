// Smoke test for the Figma-derived Pacer frontend (copyright-free placeholders).
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/ui/widgets.dart';

import 'package:pacer/main.dart';

void main() {
  testWidgets('Loading splash shows then transitions to GetStarted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PacerApp());
    // Splash: real PACER logo.
    expect(find.byType(PacerLogo), findsOneWidget);
    // After the 1.2s progress bar, GetStarted appears (Indonesian default).
    await tester.pumpAndSettle();
    expect(find.text('Pacer, siap membantu!'), findsOneWidget);
    expect(find.text('Daftar'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });
}
