import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/pacer_logo.dart';

void main() {
  test('mark geometry has holes: bounds sane, counter not filled', () {
    final path = pacerMarkPath();
    final b = path.getBounds();
    expect(b.left, greaterThan(0));
    expect(b.right, lessThan(130));
    expect(b.top, closeTo(20, 0.5));
    expect(b.bottom, closeTo(100, 0.5));
    // A point inside the skewed stem is filled; one inside the counter isn't.
    expect(path.contains(const Offset(60, 30)), isTrue);
    expect(path.contains(const Offset(80, 44)), isFalse);
  });

  for (final dark in [true, false]) {
    testWidgets('lockup renders (${dark ? 'dark' : 'light'}) at 3 widths', (t) async {
      for (final w in [112.0, 260.0, 400.0]) {
        await t.pumpWidget(
          MaterialApp(
            theme: dark ? PacerTheme.dark() : PacerTheme.light(),
            home: Scaffold(body: Center(child: PacerLogoLockup(width: w))),
          ),
        );
        await t.pump();
        final size = t.getSize(find.byType(PacerLogoLockup));
        expect(size.width, w);
        expect(size.height, closeTo(w * 0.3, 0.01));
        expect(t.takeException(), isNull);
      }
    });
  }

  testWidgets('every style + PacerMark build', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            for (final s in PacerLogoStyle.values)
              PacerLogoLockup(width: 200, style: s),
            const PacerMark(width: 64),
          ],
        ),
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
