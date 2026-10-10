// Verifies the language toggle mechanism: tapping an option flips
// langNotifier and S.* getters resolve to the new language on rebuild.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/more_screens.dart';

void main() {
  testWidgets('language toggle switches S strings', (
    WidgetTester tester,
  ) async {
    langNotifier.value = Lang.id;
    await tester.pumpWidget(
      // Mirror production: main.dart rebuilds MaterialApp on langNotifier.
      ValueListenableBuilder<Lang>(
        valueListenable: langNotifier,
        builder: (context, _, _) => MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Builder(builder: (context) => Text(S.signIn)),
                const Expanded(child: LanguageSettingsScreen()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(langNotifier.value, Lang.id);
    expect(find.text('Daftar'), findsOneWidget);

    // Tap the English option.
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(langNotifier.value, Lang.en);
    expect(find.text('Sign In'), findsOneWidget);

    // Tap back to Indonesian.
    await tester.tap(find.text('Bahasa Indonesia'));
    await tester.pumpAndSettle();
    expect(langNotifier.value, Lang.id);
    expect(find.text('Daftar'), findsOneWidget);
  });
}
