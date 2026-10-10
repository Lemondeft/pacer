import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pacer/core/responsive/responsive.dart';

import 'app_theme.dart';
import 'app_strings.dart';

/// The ONE app logo: rounded gradient tile + PACER wordmark (Fugaz One).
/// Used on Loading, GetStarted, and the Home header at different sizes.
class PacerLogo extends StatelessWidget {
  final double width;
  final double fontSize;
  const PacerLogo({super.key, this.width = 198, this.fontSize = 40});

  @override
  Widget build(BuildContext context) {
    final height = width * 108 / 198;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PacerColors.primary, PacerColors.lime],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        'PACER',
        style: PacerText.fugazBrand.copyWith(
          fontSize: fontSize,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Blue primary CTA. Full shell width; subtle shadow per dump (no heavy drop).
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

/// White auth field 315x50 r5 with leading icon.
/// Inset shadow approximated with top inner darkening strip.
class AuthField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  const AuthField({
    super.key,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: PacerColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 8,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: PacerText.button,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: PacerText.hint,
                border: InputBorder.none,
                prefixIcon: Icon(icon, color: Colors.black54, size: 20),
                suffixIcon: obscure
                    ? const Icon(Icons.visibility_off_outlined, size: 20)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Run session card. Fills its parent width (grid cell or column);
/// flexible internals — no fixed pixel size.
class RunSessionCard extends StatelessWidget {
  final String title;
  final String date;
  final String time;
  final String pace;
  final String distance;
  final bool limePill;
  const RunSessionCard({
    super.key,
    this.title = 'Monday Morning Run',
    this.date = '16/7/2024',
    this.time = '15.00',
    this.pace = "5'00''",
    this.distance = '3,00 Km',
    this.limePill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 23, 20, 18),
      decoration: BoxDecoration(
        color: PacerColors.runCardBg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.directions_run, size: 34, color: PacerColors.ink),
          const SizedBox(width: 8),
          // Left pane (3) / right pane (2): both flex so wide text can
          // never push the row past the card edge.
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: PacerText.cardDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: PacerText.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(time, style: PacerText.cardTime),
                          Text(S.time, style: PacerText.cardSub),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pace, style: PacerText.cardPace),
                          Text(S.pace, style: PacerText.cardSub),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(distance, style: PacerText.cardDistance),
                ),
                const SizedBox(height: 12),
                // Pace pill spans the pane width — scales with the card.
                Container(
                  height: 12.5,
                  decoration: BoxDecoration(
                    color: (limePill ? PacerColors.lime : PacerColors.primary)
                        .withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Team tile — fills its parent (grid cell or column); [width] only for
/// fixed-width slots like the home carousel. Gradient + location pin +
/// Fugaz name (no invented avatar). [location] is optional: the teams table
/// has no location column, so live rows pass nothing.
class TeamCard extends StatelessWidget {
  final String name;
  final String location;
  final double? width;
  const TeamCard({
    super.key,
    required this.name,
    this.location = '',
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2B2B), PacerColors.streakBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            name,
            style: PacerText.teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 19, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location,
                  style: PacerText.teamLoc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section header row with "See all" (Outfit 500/20 + 15).
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Title flexes and scales instead of overflowing with long
        // translations (e.g. "Lihat semua" + long section names).
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
            ),
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Text(
            S.seeAll,
            style: const TextStyle(color: PacerColors.ink, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

/// Outfit 800/32 page title.
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Text(title, style: PacerText.pageTitle);
}

/// 48x48 back circle + optional Fugaz title.
/// [onBack] overrides the default Navigator.maybePop — required on screens
/// that are not pushed routes (root-switched auth screens), where maybePop
/// would silently do nothing.
class PageHeader extends StatelessWidget {
  final String? title;
  final VoidCallback? onBack;
  const PageHeader({super.key, this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: BackButton(
            color: PacerColors.ink,
            // Null falls back to Navigator.maybePop (correct on pushed routes).
            onPressed: onBack,
          ),
        ),
        if (title != null) ...[
          const SizedBox(width: 12),
          Text(title!, style: PacerText.fugazBrand),
        ],
      ],
    );
  }
}

/// Initials avatar replacing all photo avatars (copyright-free).
class InitialAvatar extends StatelessWidget {
  final String initials;
  final double size;
  const InitialAvatar(this.initials, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2C),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(color: Colors.white, fontSize: size * 0.4),
      ),
    );
  }
}

/// Purple streak hero card. Fills its parent width; intrinsic height.
/// Decorative circles clip at the card bounds. [count] overrides the
/// demo number when live data is available.
class StreakCard extends StatelessWidget {
  final int? count;
  const StreakCard({super.key, this.count});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final circle = fluid(MediaQuery.sizeOf(context).width, 26, 32);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: PacerColors.streakBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: 144,
                height: 144,
                decoration: BoxDecoration(
                  color: const Color(0x1ADFE900),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 8,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: const Color(0x1A10FFA0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x99343538),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: PacerColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          S.activeStreak,
                          style: PacerText.mono.copyWith(
                            color: PacerColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${count ?? 24}',
                                  style: PacerText.giantNum(56)
                                      .copyWith(color: PacerColors.streakNum),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        S.daysStreak,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: PacerColors.streakLabel,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department,
                                    size: 11,
                                    color: Color(0xFFDFE900),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    S.personalRecord,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF090A09),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 55,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xCC292A2D),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.local_fire_department,
                          size: 36,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(7, (i) {
                      final last = i == 6;
                      return Expanded(
                        child: Column(
                          children: [
                            Text(
                              dayLabels[i],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: last
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: last
                                    ? PacerColors.neon
                                    : const Color(0xFF090A09),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: circle,
                              height: circle,
                              decoration: BoxDecoration(
                                color: PacerColors.neon,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0x5910FFA0),
                                    blurRadius: last ? 14 : 12,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check,
                                size: circle * 0.375,
                                color: const Color(0xFF007144),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating dark blurred nav pill + central START circle. Authored at the
/// fixed 377x80.7 design size; MainShell scales it via fluid(w, 377, 480)
/// (capped at ~480 and centered on wide screens per the nav rules).
class BottomNavPill extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onStart;
  const BottomNavPill({
    super.key,
    required this.index,
    required this.onTap,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.emoji_events_outlined,
      Icons.leaderboard_outlined,
      Icons.groups_outlined,
      Icons.local_fire_department_outlined,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          // Fixed 377x80.7 DESIGN size — MainShell wraps this in a FittedBox
          // scaled by fluid(w, 377, 480) so the pill grows moderately on
          // bigger screens but never balloons.
          width: 377,
          height: 80.7,
          decoration: BoxDecoration(
            color: PacerColors.bottomBar,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 2; i++)
                SizedBox(
                  width: 50,
                  height: 49,
                  child: IconButton(
                    onPressed: () => onTap(i),
                    icon: Icon(
                      icons[i],
                      size: 30,
                      color: index == i ? PacerColors.lime : Colors.white,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: onStart,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: PacerColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  // Fugaz One 20 "START" is ~75px wide — scale to the circle
                  // instead of wrapping on narrow screens.
                  padding: const EdgeInsets.all(8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'START',
                      style: PacerText.fugazBrand.copyWith(
                        fontSize: 20,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              for (var i = 2; i < 4; i++)
                SizedBox(
                  width: 50,
                  height: 49,
                  child: IconButton(
                    onPressed: () => onTap(i),
                    icon: Icon(
                      icons[i],
                      size: 30,
                      color: index == i ? PacerColors.lime : Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular run action (tracker). Size passed in as a fluid() value.
class CircleAction extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final double labelSize;
  final double size;
  final VoidCallback? onTap;
  const CircleAction({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.labelSize = 20,
    this.size = 98,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: PacerColors.lime,
            width: bg == Colors.white ? 2 : 0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: PacerText.fugazBrand.copyWith(color: fg, fontSize: labelSize),
        ),
      ),
    );
  }
}

/// Circular mini-map button (tracker slot 1). Size passed in as fluid().
class MapCircleButton extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  const MapCircleButton({super.key, this.size = 98, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
          ),
          border: Border.fromBorderSide(BorderSide.none),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.map_outlined, size: 36, color: PacerColors.ink),
      ),
    );
  }
}

/// Tracker stat column: bottom-aligned avatar + value + label.
class TrackerStatColumn extends StatelessWidget {
  final double avatarSize;
  final String initials;
  final String value;
  final String label;
  const TrackerStatColumn({
    super.key,
    required this.avatarSize,
    required this.initials,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialAvatar(initials, size: avatarSize),
        const SizedBox(height: 6),
        Text(value, style: PacerText.statValue),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w300,
            fontSize: 15,
            color: Color(0x99000000),
          ),
        ),
      ],
    );
  }
}

/// GPS pill 91x43 r30 #E5F0C5.
class GpsPill extends StatelessWidget {
  const GpsPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 91,
      height: 43,
      decoration: BoxDecoration(
        color: PacerColors.gpsPill,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi, size: 20, color: Colors.black),
          SizedBox(width: 6),
          Text('GPS', style: TextStyle(fontSize: 16, color: Colors.black)),
        ],
      ),
    );
  }
}

/// Lime summary card (finish screen). Fills parent width; fluid height.
class SummaryLimeCard extends StatelessWidget {
  final String distance;
  final String duration;
  final String pace;
  const SummaryLimeCard({
    super.key,
    this.distance = '0,00 Km',
    this.duration = '00.00',
    this.pace = "0'00''",
  });

  Widget _col(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: PacerText.statValue),
        ),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w300,
              fontSize: 15,
              color: Color(0x99000000),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return Container(
          height: fluid(c.maxWidth, 92, 120),
          padding: const EdgeInsets.fromLTRB(30, 18, 30, 0),
          decoration: BoxDecoration(
            color: PacerColors.lime,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _col(distance, 'Distance')),
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: const Color(0x40000000),
              ),
              Expanded(child: _col(duration, 'Duration')),
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: const Color(0x40000000),
              ),
              Expanded(child: _col(pace, 'Avg Pace')),
            ],
          ),
        );
      },
    );
  }
}

/// Metric card (finish screen). Fills parent width; fluid height.
class MetricCard extends StatelessWidget {
  final String title;
  final String sub;
  final String? value;
  final String? unit;
  const MetricCard({
    super.key,
    required this.title,
    required this.sub,
    this.value,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return Container(
          height: fluid(c.maxWidth, 75, 96),
          padding: const EdgeInsets.fromLTRB(30, 16, 30, 0),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFD),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        color: PacerColors.ink,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 12,
                        color: Color(0x99000000),
                      ),
                    ),
                  ],
                ),
              ),
              if (value != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value!, style: PacerText.statValue),
                    Text(
                      unit ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 12,
                        color: Color(0x99000000),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Session-goal chip h32 r8 (setup screen).
class GoalChip extends StatelessWidget {
  final String label;
  final bool selected;
  const GoalChip({super.key, required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 23),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.black : const Color(0xFFC4C7C8),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF181C22),
        ),
      ),
    );
  }
}

/// Lime action bar. Fills parent width, 48 tall, r10.
class LimeActionBar extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const LimeActionBar(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: PacerColors.lime,
          foregroundColor: PacerColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
    );
  }
}

/// Clubs search field. Fills parent width, r12 #F8FAFC.
class SearchField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  const SearchField({
    super.key,
    this.hint = 'Cari klub, kota, atau teman...',
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: PacerColors.slate400, fontSize: 14),
        prefixIcon: const Icon(Icons.search, size: 14),
        filled: true,
        fillColor: PacerColors.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PacerColors.slate200),
        ),
      ),
    );
  }
}

/// Gradient grid replacing all map/photo fills.
class MapPlaceholder extends StatelessWidget {
  final double height;
  final String label;
  const MapPlaceholder({
    super.key,
    this.height = 180,
    this.label = 'Peta rute — placeholder bebas hak cipta',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: PacerColors.navy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route, color: PacerColors.lime, size: 40),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scrollable page body built on PageShell: fluid gutters, wide max content
/// width (1100 for dashboards/lists, 720 for forms/settings via [maxWidth]),
/// NATIVE rendering at every size — no phone-column scaling, no centered
/// dead space. [padding] carries vertical-only extras from the screen
/// (horizontal gutters come from PageShell's fluid() value).
class ResponsiveScroll extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;
  final double maxWidth;
  final bool centerContent;
  const ResponsiveScroll({
    super.key,
    this.padding = EdgeInsets.zero,
    required this.child,
    this.maxWidth = 1100,
    this.centerContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final e = padding.resolve(Directionality.of(context));
    Widget body = Padding(
      padding: EdgeInsets.only(top: e.top, bottom: e.bottom),
      child: child,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (centerContent && constraints.maxHeight.isFinite) {
          body = ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: body),
          );
        }
        return SingleChildScrollView(
          child: PageShell(maxWidth: maxWidth, child: body),
        );
      },
    );
  }
}
