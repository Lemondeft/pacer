import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pacer/core/responsive/responsive.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';

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

/// Machined squircle surface matching BottomNavPill's optical rim language
/// without adding extra BackdropFilter blur passes.
class PacerSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool highlighted;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final double pressedScale;

  const PacerSurface({
    super.key,
    required this.child,
    this.radius = PacerRadii.lg,
    this.color,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.highlighted = false,
    this.shadows,
    this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final base = color ?? scheme.card;
    final edge =
        borderColor ?? (highlighted ? scheme.accent : scheme.border);
    final rim = highlighted
        ? scheme.accent.withValues(alpha: scheme.isDark ? 0.55 : 0.45)
        : scheme.cardTopRim;
    final boxGradient =
        gradient ??
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(base, scheme.surfaceSheen, 0.55)!, base],
        );

    Widget content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    Widget surface = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: ShapeDecoration(
        gradient: gradient != null || color == null ? boxGradient : null,
        color: gradient == null && color != null ? base : null,
        shadows: shadows ?? [scheme.shadowBox],
        shape: PacerSquircleBorder(
          radius,
          side: BorderSide(color: edge, width: borderWidth),
          rimColor: rim,
        ),
      ),
      child: ClipPath.shape(
        shape: PacerSquircleBorder(radius),
        child: content,
      ),
    );

    if (onTap == null) return surface;
    return PacerTapScale(
      pressedScale: pressedScale,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: surface,
      ),
    );
  }
}

/// Unified grouped list panel with hairline inset dividers between rows.
class PacerGroupedPanel extends StatelessWidget {
  final List<Widget> children;
  final double radius;
  final EdgeInsetsGeometry dividerIndent;

  const PacerGroupedPanel({
    super.key,
    required this.children,
    this.radius = PacerRadii.lg,
    this.dividerIndent = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return PacerSurface(
      radius: radius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: dividerIndent,
                child: Container(height: 0.8, color: scheme.groupedDivider),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Subtle -16° Pacer velocity speed-cut stripes for hero & onboarding canvases.
class PacerTrackLinesPainter extends CustomPainter {
  final Color color;
  final int count;
  const PacerTrackLinesPainter({required this.color, this.count = 4});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || color.a == 0) return;
    final skew = math.tan(-16 * math.pi / 180);
    final gap = size.width / (count + 1);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < count; i++) {
      final topX = gap * (i + 0.85);
      final bottomX = topX + size.height * skew;
      canvas.drawLine(Offset(topX, -12), Offset(bottomX, size.height + 12), paint);
    }
  }

  @override
  bool shouldRepaint(covariant PacerTrackLinesPainter oldDelegate) =>
      color != oldDelegate.color || count != oldDelegate.count;
}

/// Primary CTA. Full shell width; squircle radius with subtle top highlight.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return PacerTapScale(
      enabled: onPressed != null,
      pressedScale: 0.98,
      child: Container(
        width: double.infinity,
        decoration: ShapeDecoration(
          shape: const PacerSquircleBorder(PacerRadii.md),
          shadows: [
            scheme.shadowBox,
            BoxShadow(
              color: PacerColors.primary.withValues(alpha: scheme.isDark ? 0.20 : 0.24),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            shape: const PacerSquircleBorder(PacerRadii.md),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Squircle auth/form field with focus accent highlight and password toggle.
class AuthField extends StatefulWidget {
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
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: ShapeDecoration(
        color: scheme.authField,
        shadows: [scheme.shadowBox],
        shape: PacerSquircleBorder(
          14,
          side: BorderSide(
            color: _focused ? scheme.accent : scheme.border,
            width: _focused ? 1.5 : 1,
          ),
          rimColor: scheme.cardTopRim,
        ),
      ),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (_focused != hasFocus) setState(() => _focused = hasFocus);
        },
        child: TextField(
          controller: widget.controller,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          style: PacerText.button.copyWith(color: scheme.ink, fontSize: 15),
          decoration: InputDecoration(
            filled: false,
            hintText: widget.hint,
            hintStyle: PacerText.hintOf(context),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: Icon(
              widget.icon,
              color: _focused ? scheme.accent : scheme.subtle,
              size: 20,
            ),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: scheme.muted,
                    ),
                  )
                : null,
          ),
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
  final SyncState? syncState;
  final VoidCallback? onTap;
  const RunSessionCard({
    super.key,
    this.title = 'Monday Morning Run',
    this.date = '16/7/2024',
    this.time = '15.00',
    this.pace = "5'00''",
    this.distance = '3,00 Km',
    this.limePill = false,
    this.syncState,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final dark = scheme.isDark;
    final showBadge = syncState != null && syncState != SyncState.synced;
    final accentColor = limePill ? scheme.brandAccent : PacerColors.primary;
    final iconFg =
        limePill &&
            !dark &&
            ThemeData.estimateBrightnessForColor(accentColor) ==
                Brightness.light
        ? PacerColors.navy
        : accentColor;
    final card = PacerSurface(
      color: scheme.runCard,
      radius: PacerRadii.lg,
      borderColor: scheme.softBorder,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: ShapeDecoration(
              color: accentColor.withValues(alpha: dark ? 0.16 : 0.22),
              shape: PacerSquircleBorder(
                14,
                side: BorderSide(
                  color: accentColor.withValues(alpha: dark ? 0.32 : 0.38),
                ),
                rimColor: Colors.white.withValues(alpha: dark ? 0.15 : 0.65),
              ),
            ),
            child: Icon(Icons.directions_run, size: 24, color: iconFg),
          ),
          const SizedBox(width: 12),
          // Left pane (3) / right pane (2): both flex so wide text can
          // never push the row past the card edge.
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        date,
                        style: PacerText.cardDateOf(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showBadge) ...[
                      const SizedBox(width: 6),
                      SyncStateChip(state: syncState!),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: PacerText.cardTitleOf(context).copyWith(fontSize: 14),
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
                          Text(
                            time,
                            style: PacerText.cardTimeOf(context).copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(S.time, style: PacerText.cardSubOf(context)),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pace,
                            style: PacerText.cardPaceOf(context).copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(S.pace, style: PacerText.cardSubOf(context)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    distance,
                    style: PacerText.cardDistanceOf(context).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Sleek capsule accent bar under distance.
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: limePill
                          ? [
                              scheme.brandAccent,
                              Color.lerp(
                                scheme.brandAccent,
                                PacerColors.neon,
                                0.35,
                              )!,
                            ]
                          : [
                              PacerColors.primary,
                              PacerColors.primary.withValues(alpha: 0.45),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return PacerTapScale(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: card,
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
  final int? memberCount;
  final bool isJoined;
  final bool? isPrivate;
  const TeamCard({
    super.key,
    required this.name,
    this.location = '',
    this.width,
    this.memberCount,
    this.isJoined = false,
    this.isPrivate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final showBadges = isJoined || isPrivate != null;
    final showLoc = location.isNotEmpty || memberCount == null;
    return Container(
      width: width,
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: scheme.heroCardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: PacerSquircleBorder(
          PacerRadii.lg,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          rimColor: Colors.white.withValues(alpha: 0.35),
        ),
        shadows: [scheme.shadowBox],
      ),
      child: ClipPath.shape(
        shape: const PacerSquircleBorder(PacerRadii.lg),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: PacerTrackLinesPainter(
                    color: Colors.white.withValues(alpha: 0.08),
                    count: 3,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -18,
              bottom: -22,
              child: IgnorePointer(
                child: Icon(
                  Icons.groups_rounded,
                  size: 108,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: showBadges
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.end,
                children: [
                  if (showBadges)
                    Row(
                      children: [
                        if (isPrivate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPrivate! ? Icons.lock_outline : Icons.public,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isPrivate! ? S.privateBadge : S.publicBadge,
                                  style: PacerText.teamLoc.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isPrivate != null && isJoined)
                          const SizedBox(width: 6),
                        if (isJoined)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.brandAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              S.joinedBadge,
                              style: PacerText.teamLoc.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: scheme.onBrandAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (showBadges) const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                          if (showLoc)
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
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
                            ),
                          if (showLoc && memberCount != null)
                            const SizedBox(width: 8),
                          if (memberCount != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.group_outlined,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  S.membersCount(memberCount!),
                                  style: PacerText.teamLoc.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
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

/// Section header row with crisp typography, optional count pill, and "See all" CTA.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final int? count;
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                fontSize: 19,
                letterSpacing: -0.4,
                color: scheme.ink,
              ),
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: ShapeDecoration(
              color: scheme.card,
              shape: PacerSquircleBorder(
                999,
                side: BorderSide(color: scheme.border),
                rimColor: scheme.cardTopRim,
              ),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
        if (onSeeAll != null) ...[
          const SizedBox(width: 8),
          PacerTapScale(
            pressedScale: 0.95,
            child: TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 38),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.padded,
                backgroundColor: scheme.card,
                shape: PacerSquircleBorder(
                  PacerRadii.pill,
                  side: BorderSide(color: scheme.border),
                  rimColor: scheme.cardTopRim,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    S.seeAll,
                    style: GoogleFonts.spaceGrotesk(
                      color: scheme.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: scheme.accent,
                  ),
                ],
              ),
            ),
          ),
        ],
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
        PacerTapScale(
          pressedScale: 0.92,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.card,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.border),
              boxShadow: [scheme.shadowBox],
            ),
            child: BackButton(
              color: scheme.ink,
              onPressed: () {
                HapticFeedback.lightImpact();
                if (onBack != null) {
                  onBack!();
                } else {
                  Navigator.maybePop(context);
                }
              },
            ),
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
    final dark = scheme.isDark;
    final live = s != StreakStatus.inactive;
    final accent = accentFor(s);
    final textAccent = switch (s) {
      StreakStatus.active => dark ? PacerColors.lime : const Color(0xFF0D6B4A),
      StreakStatus.atRisk =>
        dark ? PacerColors.streakAmber : const Color(0xFF9A4004),
      StreakStatus.inactive => dark ? PacerColors.slate400 : scheme.muted,
    };
    final gradColors = dark
        ? [
            scheme.streakCardBg,
            Color.lerp(scheme.streakCardBg, accent, live ? 0.16 : 0.04)!,
          ]
        : switch (s) {
            StreakStatus.active => const [Color(0xFFE3F0FC), Color(0xFFCBE3F9)],
            StreakStatus.atRisk => const [Color(0xFFEBF2FA), Color(0xFFEDE2CE)],
            StreakStatus.inactive => const [
              Color(0xFFE2ECF7),
              Color(0xFFD5E1EE),
            ],
          };
    final circle = fluid(MediaQuery.sizeOf(context).width, 30, 36);
    final labelInk = dark ? const Color(0xFFF8FAFC) : scheme.ink;
    final dividerColor = dark
        ? Colors.white.withValues(alpha: 0.12)
        : scheme.border;
    final msgColor = dark ? Colors.white.withValues(alpha: 0.75) : scheme.bodyGray;
    final labels = langNotifier.value == Lang.en ? _dayLabelsEn : _dayLabelsId;
    final (pillText, message) = switch (s) {
      StreakStatus.active => (S.activeStreak, S.streakActiveMsg),
      StreakStatus.atRisk => (S.streakAtRisk, S.streakAtRiskMsg(n)),
      StreakStatus.inactive => (S.noStreak, S.streakInactiveMsg),
    };

    return Semantics(
      container: true,
      label: '$n ${S.daysStreak}. $pillText. $message',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: _anim,
          curve: Curves.easeOut,
          decoration: ShapeDecoration(
            shape: PacerSquircleBorder(
              PacerRadii.hero,
              side: BorderSide(
                color: live
                    ? (dark
                          ? accent.withValues(alpha: 0.35)
                          : textAccent.withValues(alpha: 0.32))
                    : (dark
                          ? Colors.white.withValues(alpha: 0.12)
                          : scheme.border),
              ),
              rimColor: scheme.cardTopRim,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradColors,
            ),
            shadows: [
              scheme.shadowBox,
              if (s == StreakStatus.active)
                BoxShadow(
                  color: accent.withValues(alpha: dark ? 0.18 : 0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: ClipPath.shape(
            shape: const PacerSquircleBorder(PacerRadii.hero),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: PacerTrackLinesPainter(
                        color: textAccent.withValues(alpha: live ? 0.08 : 0.04),
                        count: 4,
                      ),
                    ),
                  ),
                ),
              // Oversized ghost flame, clipped at the card edge.
              Positioned(
                right: -32,
                top: -40,
                child: Icon(
                  Icons.local_fire_department,
                  size: 168,
                  color: textAccent.withValues(alpha: live ? 0.09 : 0.05),
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
                    color: (dark ? accent : textAccent).withValues(
                      alpha: live ? 1 : 0.4,
                    ),
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
                              color: textAccent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: textAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    pillText,
                                    overflow: TextOverflow.ellipsis,
                                    style: PacerText.mono.copyWith(
                                      color: textAccent,
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
                            color: textAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: textAccent.withValues(alpha: 0.42),
                            ),
                            boxShadow: s == StreakStatus.active
                                ? [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.40),
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
                            color: textAccent,
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
                                ? labelInk
                                : labelInk.withValues(alpha: 0.55),
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
                                  color: textAccent,
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
                              textAccent: textAccent,
                              label: labels[i],
                              date:
                                  '${DateTime(monday.year, monday.month, monday.day + i).day}',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, color: dividerColor),
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
                          color: textAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: msgColor),
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
  final Color textAccent;
  final String label;
  final String date;
  const _StreakDay({
    required this.size,
    required this.done,
    required this.isToday,
    required this.isFuture,
    required this.accent,
    required this.textAccent,
    required this.label,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final dark = scheme.isDark;
    final labelInk = dark ? const Color(0xFFF8FAFC) : scheme.ink;
    final dim = isFuture ? 0.45 : 0.72;
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
                : (dark
                      ? Colors.white.withValues(alpha: isFuture ? 0.04 : 0.10)
                      : scheme.card.withValues(alpha: isFuture ? 0.48 : 0.85)),
            border: Border.all(
              color: done || isToday
                  ? (dark ? accent : textAccent)
                  : (dark
                        ? Colors.white.withValues(alpha: isFuture ? 0.10 : 0.24)
                        : scheme.border),
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
            color: isToday
                ? textAccent
                : (dark
                      ? Colors.white.withValues(alpha: isFuture ? 0.35 : 0.60)
                      : scheme.bodyGray.withValues(alpha: dim)),
          ),
        ),
        Text(
          date,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isToday
                ? textAccent
                : labelInk.withValues(alpha: isFuture ? 0.45 : 1),
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
    final tint = dark ? scheme.card : scheme.navBar;
    final pillAccent = dark ? scheme.accent : scheme.brandAccent;

    // Slot index mapping across 5 slots: [0: Home, 1: Run, 2: START, 3: Teams, 4: Rank]
    final slotIndex = index < 2 ? index : index + 1;
    final alignX = -1.0 + (slotIndex * 0.5);

    Widget tab(int i) {
      final selected = index == i;
      final selectedFg = dark ? scheme.accent : const Color(0xFF102A43);
      return PacerGlassPress(
        radius: 24,
        child: Semantics(
          selected: selected,
          button: true,
          label: tabs[i].$3,
          // Tap lives here (not on the excluded InkResponse) so screen
          // readers can still activate the tab.
          onTap: () {
            HapticFeedback.selectionClick();
            onTap(i);
          },
          child: ExcludeSemantics(
            child: Tooltip(
              message: tabs[i].$3,
              child: InkResponse(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(i);
                },
                radius: 28,
                child: SizedBox(
                  height: 58,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? tabs[i].$2 : tabs[i].$1,
                          size: 23,
                          color: selected ? selectedFg : scheme.navIcon,
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tabs[i].$3,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? selectedFg : scheme.navIcon,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
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
        lensBlurSigma: 2.8,
        refractionWidth: 12.0,
        refractionIndexOverride: 1.18,
        magnification: 1.02,
        dispersionOverride: 1.2,
        saturation: 1.08,
        continuousCorners: true,
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
                              color: pillAccent.withValues(
                                alpha: dark ? 0.18 : 0.58,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: dark
                                    ? pillAccent.withValues(alpha: 0.40)
                                    : const Color(0xFF82B800).withValues(
                                        alpha: 0.65,
                                      ),
                                width: dark ? 0.75 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: pillAccent.withValues(
                                    alpha: dark ? 0.20 : 0.26,
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
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              onStart();
                            },
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                onStart();
                              },
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
    return PacerTapScale(
      enabled: onTap != null,
      pressedScale: 0.93,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onTap!();
              },
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
      ),
    );
  }
}

/// Circular mini-map button (tracker slot 1). Size passed in as fluid().
class MapCircleButton extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  final bool active;
  final IconData icon;
  final String? tooltip;
  const MapCircleButton({
    super.key,
    this.size = 98,
    this.onTap,
    this.active = false,
    this.icon = Icons.map_outlined,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final label = tooltip ?? S.toggleMapStyle;
    return Semantics(
      button: true,
      toggled: active,
      label: label,
      child: Tooltip(
        message: label,
        child: PacerTapScale(
          enabled: onTap != null,
          pressedScale: 0.93,
          child: GestureDetector(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: active
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [PacerColors.lime, Color(0xFFA3EA15)],
                      )
                    : LinearGradient(
                        colors: [scheme.softBorder, scheme.mapBtnB],
                      ),
                border: active
                    ? Border.all(
                        color: scheme.ink.withValues(alpha: 0.16),
                        width: 1.5,
                      )
                    : const Border.fromBorderSide(BorderSide.none),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: PacerColors.lime.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 36,
                color: active ? PacerColors.ink : scheme.ink,
              ),
            ),
          ),
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
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PacerColors.lime,
                Color.lerp(PacerColors.lime, PacerColors.neon, 0.22)!,
              ],
            ),
            shape: PacerSquircleBorder(
              PacerRadii.hero,
              side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              rimColor: Colors.white.withValues(alpha: 0.65),
            ),
            shadows: [
              BoxShadow(
                color: PacerColors.lime.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _col(distance, S.distance)),
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: PacerColors.limeDivider,
              ),
              Expanded(child: _col(duration, S.duration)),
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: PacerColors.limeDivider,
              ),
              Expanded(child: _col(pace, S.avgPace)),
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
        return PacerSurface(
          radius: PacerRadii.lg,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: fluid(c.maxWidth, 64, 84),
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: scheme.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
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
                      Text(
                        value!,
                        style: PacerText.statValueOf(context).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
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
          ),
        );
      },
    );
  }
}

/// Interactive pill/squircle filter & goal chip with 48dp accessible hit area.
class GoalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final bool useBrandAccent;
  const GoalChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.useBrandAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final selBg = useBrandAccent ? scheme.brandAccent : scheme.chipSelBg;
    final selFg = useBrandAccent ? scheme.onBrandAccent : scheme.chipSelFg;
    return SizedBox(
      height: 48,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: icon != null ? 14 : 20),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: selected ? selBg : scheme.card,
            shadows: selected
                ? [
                    BoxShadow(
                      color: selBg.withValues(alpha: scheme.isDark ? 0.24 : 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
            shape: PacerSquircleBorder(
              PacerRadii.sm,
              side: BorderSide(
                color: selected ? selBg : scheme.chipBorder,
                width: selected ? 1.4 : 1,
              ),
              rimColor: selected
                  ? Colors.white.withValues(alpha: 0.28)
                  : scheme.cardTopRim,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? selFg : scheme.ink),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? selFg : scheme.chipFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lime action bar. Fills parent width, 52 tall, squircle r16.
class LimeActionBar extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const LimeActionBar(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return PacerTapScale(
      enabled: onPressed != null,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.brandAccent,
            foregroundColor: scheme.onBrandAccent,
            shape: PacerSquircleBorder(
              PacerRadii.md,
              rimColor: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: scheme.onBrandAccent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Clubs search field. Fills parent width, squircle r14.
class SearchField extends StatelessWidget {
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  const SearchField({
    super.key,
    this.hint,
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
        hintText: hint ?? S.searchClubs,
        hintStyle: TextStyle(color: scheme.soft, fontSize: 14),
        prefixIcon: Icon(Icons.search, size: 20, color: scheme.soft),
        filled: true,
        fillColor: scheme.searchBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.accent, width: 1.5),
        ),
      ),
    );
  }
}

/// Gradient grid replacing all map/photo fills.
class MapPlaceholder extends StatelessWidget {
  final double height;
  final String? label;
  const MapPlaceholder({
    super.key,
    this.height = 180,
    this.label,
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
                label ?? S.mapPlaceholderLabel,
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

/// Compact pill indicating local/failed sync state on an activity card or item.
class SyncStateChip extends StatelessWidget {
  final SyncState state;
  const SyncStateChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isFailed = state == SyncState.failed;
    final fg = isFailed ? const Color(0xFFD97706) : const Color(0xFF0369A1);
    final bg = fg.withValues(alpha: 0.14);
    final label = isFailed ? S.syncChipFailed : S.syncChipLocal;
    final icon = isFailed ? Icons.error_outline : Icons.cloud_upload_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live banner tracking offline state, pending sync queue, or auth expiry.
/// Renders empty ([SizedBox.shrink]) when online and completely synced.
class SyncStatusBanner extends StatelessWidget {
  final EdgeInsetsGeometry margin;
  final SyncEngine? engine;
  const SyncStatusBanner({
    super.key,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.engine,
  });

  @override
  Widget build(BuildContext context) {
    final sync = engine ?? SyncEngine.instance;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final status = sync.status;
        if (status.isOnline &&
            !status.isSyncing &&
            status.pendingCount == 0 &&
            status.failedCount == 0 &&
            !status.needsReauth) {
          return const SizedBox.shrink();
        }
        final scheme = PacerScheme.of(context);
        final IconData icon;
        final Color accent;
        final String message;
        var showRetry = false;

        if (status.needsReauth) {
          icon = Icons.lock_clock_outlined;
          accent = const Color(0xFFD97706);
          message = status.pendingCount > 0
              ? '${S.syncSignInAgain} (${S.syncPendingCount(status.pendingCount)})'
              : S.syncSignInAgain;
          showRetry = true;
        } else if (status.failedCount > 0) {
          icon = Icons.sync_problem_outlined;
          accent = const Color(0xFFDC2626);
          message = S.syncFailedCount(status.failedCount);
          showRetry = true;
        } else if (!status.isOnline) {
          icon = Icons.cloud_off_outlined;
          accent = scheme.muted;
          message = status.pendingCount > 0
              ? '${S.offlineBannerTitle} · ${S.syncPendingCount(status.pendingCount)}'
              : S.offlineBannerTitle;
        } else if (status.isSyncing) {
          icon = Icons.sync;
          accent = PacerColors.primary;
          message = S.syncingNow;
        } else {
          icon = Icons.cloud_queue_outlined;
          accent = PacerColors.primary;
          message = S.syncPendingCount(status.pendingCount);
          showRetry = true;
        }

        return Container(
          margin: margin,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.ink,
                  ),
                ),
              ),
              if (showRetry)
                TextButton(
                  onPressed: status.isSyncing
                      ? null
                      : () => sync.syncNow(retryFailed: true),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    S.syncRetry,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Maps transient connectivity failures to the friendly localized offline hint
/// instead of leaking raw SocketException / ClientException strings in SnackBars.
String offlineActionErrorMessage(Object error) {
  if (isTransientNetworkError(error) || !ConnectivityService.instance.value) {
    return S.offlineActionNeedsNet;
  }
  return S.errSaveFailed;
}

/// Lightweight tactile spring scale wrapper for cards, pills, and action bars.
/// Uses a non-competing [Listener] so inner tap handlers continue uninterrupted
/// and honors system reduced-motion settings.
class PacerTapScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double pressedScale;

  const PacerTapScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.96,
  });

  @override
  State<PacerTapScale> createState() => _PacerTapScaleState();
}

class _PacerTapScaleState extends State<PacerTapScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final disableAnims = MediaQuery.disableAnimationsOf(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: disableAnims
            ? Duration.zero
            : const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
