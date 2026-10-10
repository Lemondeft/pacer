// Dumps the ancestor chain of PacerLogo with sizes + constraints to find
// who clamps the design viewport to 393x852 (scale 1.0) at desktop size.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/ui/screens.dart';
import 'package:pacer/src/ui/widgets.dart';

void main() {
  testWidgets('dump ancestor chain of PacerLogo', (tester) async {
    tester.view.physicalSize = const Size(949 * 2, 1028 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: GetStartedScreen(onSignIn: () {}, onLogIn: () {}),
      ),
    );
    await tester.pumpAndSettle();
    RenderObject? node = tester
        .renderObject<RenderBox>(find.byType(PacerLogo).first)
        .parent;
    var depth = 0;
    while (node != null && depth < 14) {
      final box = node as RenderBox?; // ignore: avoid_as
      if (box != null && box.hasSize) {
        debugPrint(
          '#$depth ${node.runtimeType} '
          'size=${box.size} constraints=${box.constraints}',
        );
      } else {
        debugPrint('#$depth ${node.runtimeType} (no size)');
      }
      node = node.parent;
      depth++;
    }
  });
}
