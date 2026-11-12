import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/pacer_logo.dart';
import 'package:pacer/src/ui/widgets.dart';

Widget darkPreviewWrapper(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: PacerTheme.dark(),
    home: Scaffold(
      backgroundColor: PacerDark.scaffold,
      body: Center(child: Padding(padding: const EdgeInsets.all(16), child: child)),
    ),
  );
}

Widget lightPreviewWrapper(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: PacerTheme.light(),
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: Padding(padding: const EdgeInsets.all(16), child: child)),
    ),
  );
}

// ---------------------------------------------------------------------------
// 1. Logo & Mark Previews
// ---------------------------------------------------------------------------

@Preview(name: 'Pacer Logo (Dark Mode)', group: 'Brand', wrapper: darkPreviewWrapper)
Widget previewPacerLogoDark() => const PacerLogoLockup(width: 220, style: PacerLogoStyle.onDark);

@Preview(name: 'Pacer Logo (Light Mode)', group: 'Brand', wrapper: lightPreviewWrapper)
Widget previewPacerLogoLight() => const PacerLogoLockup(width: 220, style: PacerLogoStyle.onLight);

@Preview(name: 'Pacer Logo (Gradient)', group: 'Brand', wrapper: darkPreviewWrapper)
Widget previewPacerLogoGradient() => const PacerLogoLockup(width: 220, style: PacerLogoStyle.gradient);

@Preview(name: 'Pacer Mark (App Icon)', group: 'Brand', wrapper: darkPreviewWrapper)
Widget previewPacerMark() => const PacerMark(width: 64);

// ---------------------------------------------------------------------------
// 2. Component Previews
// ---------------------------------------------------------------------------

@Preview(name: 'Streak Card (Active 5 Days)', group: 'Dashboard', wrapper: darkPreviewWrapper)
Widget previewStreakCardActive() {
  return StreakCard(
    count: 5,
    done: const [true, true, true, true, true, false, false],
    todayIndex: 4,
    status: StreakStatus.active,
  );
}

@Preview(name: 'Streak Card (Rest / At Risk)', group: 'Dashboard', wrapper: darkPreviewWrapper)
Widget previewStreakCardAtRisk() {
  return StreakCard(
    count: 3,
    done: const [true, true, true, false, false, false, false],
    todayIndex: 3,
    status: StreakStatus.atRisk,
  );
}

@Preview(name: 'Run Session Card', group: 'Activity', wrapper: darkPreviewWrapper)
Widget previewRunSessionCard() {
  return const RunSessionCard(
    title: 'Lari Pagi',
    date: 'Hari ini, 06:30',
    time: '28:45',
    pace: "5'24\" /km",
    distance: '5.2 km',
  );
}

@Preview(name: 'Team Card', group: 'Teams', wrapper: darkPreviewWrapper)
Widget previewTeamCard() {
  return const SizedBox(
    width: 260,
    height: 140,
    child: TeamCard(
      name: 'Garuda Runners',
      location: 'Jakarta',
    ),
  );
}

@Preview(name: 'Bottom Nav Pill', group: 'Navigation', wrapper: darkPreviewWrapper)
Widget previewBottomNavPill() {
  return BottomNavPill(
    index: 0,
    onTap: (_) {},
    onStart: () {},
  );
}
