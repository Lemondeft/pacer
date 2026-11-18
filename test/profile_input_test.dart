import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/auth/profile_input.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/more_screens.dart';

void main() {
  test('parseDecimal accepts comma and dot, rejects junk', () {
    expect(parseDecimal('170,5'), 170.5);
    expect(parseDecimal(' 64 '), 64);
    expect(parseDecimal(''), isNull);
    expect(parseDecimal('abc'), isNull);
  });

  test('parseIsoDate is strict', () {
    expect(parseIsoDate('2006-05-14'), DateTime.utc(2006, 5, 14));
    expect(parseIsoDate('2024-02-31'), isNull);
    expect(parseIsoDate('14/05/2006'), isNull);
  });

  test('height/weight mirror DB checks; regions are unique', () {
    expect(validHeightCm(300), isFalse);
    expect(validHeightCm(170), isTrue);
    expect(validWeightKg(0), isFalse);
    expect(validWeightKg(64), isTrue);
    expect(indonesianRegions.toSet().length, indonesianRegions.length);
  });

  test('validateUsername enforces required, no whitespace, and min length 3', () {
    expect(validateUsername(''), UsernameError.required);
    expect(validateUsername('   '), UsernameError.required);
    expect(validateUsername('andi wijaya'), UsernameError.hasWhitespace);
    expect(validateUsername('ab'), UsernameError.tooShort);
    expect(validateUsername('andi_wijaya'), isNull);
    expect(validateUsername('  pacer1  '), isNull);
  });

  testWidgets('AboutMe (demo) shows data and edit dialog validates', (t) async {
    t.view.physicalSize = const Size(720, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(theme: PacerTheme.dark(), home: const AboutMeScreen()),
    );
    await t.pumpAndSettle();
    expect(find.text('pacer_demo'), findsOneWidget);
    expect(find.text('DKI Jakarta'), findsOneWidget);

    await t.tap(find.byType(ElevatedButton));
    await t.pumpAndSettle();
    // Spaced username → inline error, dialog stays open.
    await t.enterText(find.byType(TextField).at(0), 'bad name');
    await t.tap(find.byType(TextButton).last);
    await t.pumpAndSettle();
    expect(find.byType(ProfileEditDialog), findsOneWidget);
    await t.enterText(find.byType(TextField).at(0), 'pacer_demo');
    // Bad height → inline error, dialog stays open.
    await t.enterText(find.byType(TextField).at(1), '999');
    await t.tap(find.byType(TextButton).last);
    await t.pumpAndSettle();
    expect(find.byType(ProfileEditDialog), findsOneWidget);
    expect(find.textContaining('cm'), findsWidgets);

    // Fix it → saves, closes cleanly (no disposed-controller error).
    await t.enterText(find.byType(TextField).at(1), '175,5');
    await t.tap(find.byType(TextButton).last);
    await t.pumpAndSettle();
    expect(find.byType(ProfileEditDialog), findsNothing);
    expect(find.text('175.5 cm'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
