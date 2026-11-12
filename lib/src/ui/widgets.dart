
import 'package:flutter/material.dart';
import 'package:pacer/core/responsive/responsive.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';

import 'app_theme.dart';
import 'app_strings.dart';
import 'pacer_logo.dart';
import 'pacer_glass.dart';

/// The ONE app logo: skewed "p" mark with speed cuts + italic "acer"
/// wordmark, in Pacer's brand gradient (sky blue → lime). Used on Loading,
/// GetStarted, and the Home header at different sizes; wordmark colour
/// follows the theme unless [style] is given. See pacer_logo.dart.
class PacerLogo extends StatelessWidget {
  final double width;
  final PacerLogoStyle? style;
  const PacerLogo({super.key, this.width = 198, this.style});

  @override
  Widget build(BuildContext context) =>
      PacerLogoLockup(width: width, style: style);
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
        boxShadow: [PacerScheme.of(context).shadowBox],
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
    final scheme = PacerScheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: scheme.authField,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: scheme.border),
        boxShadow: [scheme.shadowBox],
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
              style: PacerText.button.copyWith(color: scheme.ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: PacerText.hintOf(context),
                border: InputBorder.none,
                prefixIcon: Icon(icon, color: scheme.subtle, size: 20),
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
    final scheme = PacerScheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: scheme.runCard,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [scheme.shadowBox],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.directions_run, size: 34, color: scheme.ink),
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
                  style: PacerText.cardDateOf(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: PacerText.cardTitleOf(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
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
                          Text(time, style: PacerText.cardTimeOf(context)),
                          Text(S.time, style: PacerText.cardSubOf(context)),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pace, style: PacerText.cardPaceOf(context)),
                          Text(S.pace, style: PacerText.cardSubOf(context)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    distance,
                    style: PacerText.cardDistanceOf(context),
                  ),
                ),
                const SizedBox(height: 16),
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
          colors: [PacerColors.teamShade, PacerColors.streakBg],
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
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          child: Text(
            S.seeAll,
            style: TextStyle(color: PacerScheme.of(context).ink, fontSize: 15),
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
  Widget build(BuildContext context) =>
      Text(title, style: PacerText.pageTitleOf(context));
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
    final scheme = PacerScheme.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.card,
            shape: BoxShape.circle,
            boxShadow: [scheme.shadowBox],
          ),
          child: BackButton(
            color: scheme.ink,
            // Null falls back to Navigator.maybePop (correct on pushed routes).
            onPressed: onBack,
          ),
        ),
        if (title != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title!,
              style: PacerText.fugazOf(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
        color: PacerColors.avatarBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Sporty streak hero card: count, live week strip, and a status line read
/// as one unit on a navy surface. Fills its parent width; intrinsic height.
///
/// The accent follows the streak state and animates between them:
/// - active (ran today): lime, glowing flame.
/// - at risk (ran yesterday, not yet today): amber, outlined flame.
/// - inactive (no streak / broken): muted slate.
///
/// DATA: [done] holds 7 Mon..Sun flags (true = workout that day);
/// [todayIndex] (0..6) marks today. [count] must be the *effective* streak
/// (see `effectiveStreak`). [status] is derived from [done]/[count] when
/// omitted. Nulls render an honest empty week.
class StreakCard extends StatelessWidget {
  final int? count;
  final List<bool>? done;
  final int? todayIndex;
  final StreakStatus? status;
  const StreakCard({
    super.key,
    this.count,
    this.done,
    this.todayIndex,
    this.status,
  });

  static const _dayLabelsId = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _dayLabelsEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _anim = Duration(milliseconds: 350);

  /// Accent color for a streak state (exposed for tests and callers).
  static Color accentFor(StreakStatus s) => switch (s) {
    StreakStatus.active => PacerColors.lime,
    StreakStatus.atRisk => PacerColors.streakAmber,
    StreakStatus.inactive => PacerColors.slate400,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final flags = done;
    final today = todayIndex ?? now.weekday - 1;
    final n = count ?? 0;
    bool isDone(int i) => flags != null && i < flags.length && flags[i];
    final s =
        status ??
        (isDone(today)
            ? StreakStatus.active
            : n > 0
            ? StreakStatus.atRisk
            : StreakStatus.inactive);
    final accent = accentFor(s);
    final live = s != StreakStatus.inactive;
    final circle = fluid(MediaQuery.sizeOf(context).width, 30, 36);
    const labelWhite = Color(0xFFF8FAFC);
    final labels = langNotifier.value == Lang.en ? _dayLabelsEn : _dayLabelsId;
    final (pillText, message) = switch (s) {
      StreakStatus.active => (S.activeStreak, S.streakActiveMsg),
      StreakStatus.atRisk => (S.streakAtRisk, S.streakAtRiskMsg(n)),
      StreakStatus.inactive => (S.noStreak, S.streakInactiveMsg),
    };
    final base = scheme.streakCardBg;

    return Semantics(
      container: true,
      label: '$n ${S.daysStreak}. $pillText. $message',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: _anim,
          curve: Curves.easeOut,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, Color.lerp(base, accent, live ? 0.16 : 0.04)!],
            ),
            border: Border.all(
              color: live
                  ? accent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              scheme.shadowBox,
              if (s == StreakStatus.active)
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Stack(
            children: [
              // Oversized ghost flame, clipped at the card edge.
              Positioned(
                right: -32,
                top: -40,
                child: Icon(
                  Icons.local_fire_department,
                  size: 168,
                  color: accent.withValues(alpha: live ? 0.08 : 0.04),
                ),
              ),
              // Accent kick bar along the top edge.
              Positioned(
                left: 20,
                right: 20,
                top: 0,
                child: AnimatedContainer(
                  duration: _anim,
                  height: 3,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: live ? 1 : 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: AnimatedContainer(
                            key: const ValueKey('streak-pill'),
                            duration: _anim,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    pillText,
                                    overflow: TextOverflow.ellipsis,
                                    style: PacerText.mono.copyWith(
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedContainer(
                          key: const ValueKey('streak-flame'),
                          duration: _anim,
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.45),
                            ),
                            boxShadow: s == StreakStatus.active
                                ? [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.45),
                                      blurRadius: 16,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            s == StreakStatus.active
                                ? Icons.local_fire_department
                                : Icons.local_fire_department_outlined,
                            size: 24,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$n',
                          style: PacerText.giantNum(56).copyWith(
                            color: live
                                ? labelWhite
                                : labelWhite.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                S.daysStreak,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: _StreakDay(
                              size: circle,
                              done: isDone(i),
                              isToday: i == today,
                              isFuture: i > today,
                              accent: accent,
                              label: labels[i],
                              date:
                                  '${DateTime(monday.year, monday.month, monday.day + i).day}',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          s == StreakStatus.atRisk
                              ? Icons.schedule
                              : s == StreakStatus.active
                              ? Icons.check_circle
                              : Icons.directions_run,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One day bubble of the streak week strip.
class _StreakDay extends StatelessWidget {
  final double size;
  final bool done;
  final bool isToday;
  final bool isFuture;
  final Color accent;
  final String label;
  final String date;
  const _StreakDay({
    required this.size,
    required this.done,
    required this.isToday,
    required this.isFuture,
    required this.accent,
    required this.label,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    const labelWhite = Color(0xFFF8FAFC);
    final dim = isFuture ? 0.35 : 0.60;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: StreakCard._anim,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? accent
                : Colors.white.withValues(alpha: isFuture ? 0.04 : 0.10),
            border: Border.all(
              color: done || isToday
                  ? accent
                  : Colors.white.withValues(alpha: isFuture ? 0.10 : 0.24),
              width: isToday ? 2 : 1.5,
            ),
            boxShadow: isToday && done
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.40),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: done
              ? Icon(Icons.check, size: size * 0.45, color: PacerColors.navy)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? accent : Colors.white.withValues(alpha: dim),
          ),
        ),
        Text(
          date,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isToday
                ? accent
                : labelWhite.withValues(alpha: isFuture ? 0.45 : 1),
          ),
        ),
      ],
    );
  }
}

/// Floating frosted-glass nav pill + central START circle. Authored at the
/// fixed 377x80.7 design size; MainShell scales it via fluid(w, 377, 480)
/// (capped at ~480 and centered on wide screens per the nav rules).
///
/// Glass: strong backdrop blur over the scrolling page, a translucent tint
/// with a top-light gradient, a hairline highlight border, and a soft drop
/// shadow outside the clip.
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

  static const blurSigma = 18.0;

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Per-tab glyphs matching the nav rail: outlined idle, filled selected.
    final tabs = [
      (Icons.home_outlined, Icons.home, S.home),
      (Icons.directions_run_outlined, Icons.directions_run, S.running),
      (Icons.groups_outlined, Icons.groups, S.teams),
      (Icons.leaderboard_outlined, Icons.leaderboard, S.leaderboard),
    ];
    final tint = dark ? const Color(0xFF1E293B) : scheme.navBar;

    // Slot index mapping across 5 slots: [0: Home, 1: Run, 2: START, 3: Teams, 4: Rank]
    final slotIndex = index < 2 ? index : index + 1;
    final alignX = -1.0 + (slotIndex * 0.5);

    Widget tab(int i) {
      final selected = index == i;
      return PacerGlassPress(
        radius: 24,
        child: Semantics(
          selected: selected,
          button: true,
          label: tabs[i].$3,
          // Tap lives here (not on the excluded InkResponse) so screen
          // readers can still activate the tab.
          onTap: () => onTap(i),
          child: ExcludeSemantics(
            child: Tooltip(
              message: tabs[i].$3,
              child: InkResponse(
                onTap: () => onTap(i),
                radius: 28,
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? tabs[i].$2 : tabs[i].$1,
                        size: 24,
                        color: selected ? PacerColors.lime : scheme.navIcon,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tabs[i].$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? PacerColors.lime : scheme.navIcon,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 377,
      height: 80.7,
      child: PacerGlass.navigation(
        radius: 36,
        tintColor: tint,
        tintOpacity: PacerGlassTheme.navigationOpacity(context),
        blurSigmaOverride: blurSigma,
        child: SizedBox(
          width: 377,
          height: 80.7,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Sliding illuminated selection pill (Mornye specification)
                // Shares the exact same 5-slot coordinate system as the Expanded Row items.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(alignX, 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / 5,
                        heightFactor: 1.0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: PacerColors.lime.withValues(
                                alpha: dark ? 0.16 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: PacerColors.lime.withValues(alpha: 0.35),
                                width: 0.75,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: PacerColors.lime.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 12,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Navigation items + prominent center START action in 5 equal slots
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Center(child: tab(0))),
                    Expanded(child: Center(child: tab(1))),
                    Expanded(
                      child: Center(
                        child: PacerGlassPress(
                          radius: 33,
                          child: Semantics(
                            button: true,
                            label: 'START',
                            onTap: onStart,
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: onStart,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF5CE7FF),
                                      PacerColors.primary,
                                      Color(0xFF00A6CE),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: PacerColors.primary.withValues(
                                        alpha: 0.50,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                    const BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(8),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'START',
                                    style: PacerText.fugazBrand.copyWith(
                                      fontSize: 18,
                                      letterSpacing: 0.8,
                                      color: const Color(0xFF0B132B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: Center(child: tab(2))),
                    Expanded(child: Center(child: tab(3))),
                  ],
                ),
              ],
            ),
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
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: PacerText.fugazBrand.copyWith(
                color: fg,
                fontSize: labelSize,
              ),
            ),
          ),
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              PacerScheme.of(context).softBorder,
              PacerScheme.of(context).mapBtnB,
            ],
          ),
          border: const Border.fromBorderSide(BorderSide.none),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.map_outlined,
          size: 36,
          color: PacerScheme.of(context).ink,
        ),
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
        const SizedBox(height: 8),
        Text(
          value,
          style: PacerText.statValueOf(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 15,
            color: PacerScheme.of(context).muted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
          SizedBox(width: 8),
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

  /// Overflow-proof: the outer scaleDown guarantees the column fits its
  /// tight Expanded cell at any font scale (device log: +8px RenderFlex).
  Widget _col(String value, String label) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: PacerText.statValue),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 15,
              color: PacerColors.slate800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return Container(
          height: fluid(c.maxWidth, 92, 120),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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
                color: PacerColors.limeDivider,
              ),
              Expanded(child: _col(duration, 'Duration')),
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: PacerColors.limeDivider,
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
    final scheme = PacerScheme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        return Container(
          constraints: BoxConstraints(minHeight: fluid(c.maxWidth, 75, 96)),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          decoration: BoxDecoration(
            color: scheme.card,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [scheme.shadowBox],
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
                      style: TextStyle(fontSize: 15, color: scheme.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sub,
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: scheme.soft,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (value != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value!, style: PacerText.statValueOf(context)),
                    Text(
                      unit ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: scheme.soft,
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
    final scheme = PacerScheme.of(context);
    // Visual stays a 32-tall chip; the 48-tall box guarantees a 48px
    // touch target without changing the setup screen's look.
    // Selected chip is ink-on-light, lime-on-dark (brand in both modes).
    return SizedBox(
      height: 48,
      child: Center(
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 23),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.chipSelBg : scheme.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? scheme.chipSelBg : scheme.chipBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.chipSelFg : scheme.chipFg,
            ),
          ),
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
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: PacerColors.ink,
          ),
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
    final scheme = PacerScheme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: scheme.soft, fontSize: 14),
        prefixIcon: Icon(Icons.search, size: 20, color: scheme.soft),
        filled: true,
        fillColor: scheme.searchBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.softBorder),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route, color: PacerColors.lime, size: 40),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered empty state: muted icon + message in [PacerText.emptyBody].
/// The message string is passed through untouched — only styled here.
class PacerEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  /// Compact variant for fixed-height slots (e.g. the 150px home carousel).
  final bool compact;
  const PacerEmptyState(
    this.message, {
    super.key,
    this.icon = Icons.inbox_outlined,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 20 : 32, color: scheme.emptyIcon),
            SizedBox(height: compact ? 6 : 12),
            Text(
              message,
              style: PacerText.emptyBody.copyWith(color: scheme.soft),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered loading spinner with consistent vertical rhythm.
class PacerLoading extends StatelessWidget {
  const PacerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: CircularProgressIndicator(color: PacerScheme.of(context).accent),
      ),
    );
  }
}

/// Auth/form error row: error icon + message in [PacerText.errorBody].
/// The message string is passed through untouched — only styled here.
class AuthErrorText extends StatelessWidget {
  final String message;
  const AuthErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 20, color: scheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: PacerText.errorBody.copyWith(color: scheme.error),
          ),
        ),
      ],
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
  final RefreshCallback? onRefresh;
  const ResponsiveScroll({
    super.key,
    this.padding = EdgeInsets.zero,
    required this.child,
    this.maxWidth = 1100,
    this.centerContent = false,
    this.onRefresh,
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
        Widget scroll = SingleChildScrollView(
          physics: onRefresh != null
              ? const AlwaysScrollableScrollPhysics()
              : null,
          child: PageShell(maxWidth: maxWidth, child: body),
        );
        if (onRefresh != null) {
          scroll = RefreshIndicator(onRefresh: onRefresh!, child: scroll);
        }
        return scroll;
      },
    );
  }
}
