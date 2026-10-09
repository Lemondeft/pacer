// Render-only probe: captures real widget pixels to PNG for visual inspection.
// Run: flutter test test/render_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/main.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:pacer/src/ui/screens.dart';

Future<void> _shot(WidgetTester tester, String name, Widget screen) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: RepaintBoundary(key: key, child: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary =
      tester.element(find.byKey(key)).renderObject as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('/tmp/shots/$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
}

void main() {
  testWidgets('render shots', (WidgetTester tester) async {
    await _shot(
      tester,
      'probe-getstarted',
      GetStartedScreen(onSignIn: () {}, onLogIn: () {}),
    );
    await _shot(tester, 'probe-account', const AccountScreen());
    await _shot(
      tester,
      'probe-home',
      HomeScreen(onSeeTeams: () {}, onSeeHistory: () {}),
    );
    await tester.pumpWidget(const PacerApp());
    await tester.pumpAndSettle();
    expect(find.text('Pacer, siap membantu!'), findsOneWidget);
  });
}
