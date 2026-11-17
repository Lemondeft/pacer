import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  final String? validationStatus;
  final String? suggestedSport;
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
    this.validationStatus,
    this.suggestedSport,
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
                if (S.validationBadgeLabel(
                  validationStatus,
                  suggestedSport: suggestedSport,
                ).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _ValidationStatusBadge(
                    label: S.validationBadgeLabel(
                      validationStatus,
                      suggestedSport: suggestedSport,
                    ),
                    status: validationStatus,
                  ),
                ],
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

class _ValidationStatusBadge extends StatelessWidget {
  final String label;
  final String? status;
  const _ValidationStatusBadge({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (status) {
      'flagged_vehicle' => PacerColors.errorRed,
      'flagged_ride' || 'flagged_mismatch' => PacerColors.streakAmber,
      _ => PacerColors.chipGreen,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 0.2,
        ),
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

/// Interactive frosted-glass nav pill + central START circle. Authored at
/// the fixed 377x80.7 design size; MainShell scales it via fluid(w, 377, 480)
/// (capped at ~480 and centered on wide screens per the nav rules).
///
/// Glass: strong backdrop blur over the scrolling page, a translucent tint
/// with a top-light gradient, a hairline highlight border, and a soft drop
/// shadow outside the clip. Holding or horizontally dragging expands a
/// dedicated refractive [PacerScrubberDroplet] lens that magnifies underlying
/// icons and morphs smoothly into a circle over the `START` button.
class BottomNavPill extends StatefulWidget {
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
  State<BottomNavPill> createState() => _BottomNavPillState();
}

class _BottomNavPillState extends State<BottomNavPill>
    with TickerProviderStateMixin {
  static const double _barWidth = 377.0;
  static const double _barHeight = 80.7;
  static const double _padH = 10.0;
  static const double _padV = 8.0;
  static const double _slotW = (_barWidth - 2 * _padH) / 5.0; // 71.4
  static const double _centerY = _barHeight / 2.0; // 40.35

  static const List<int?> _slotToTab = [0, 1, null, 2, 3];
  static double _tabToSlot(int idx) =>
      idx < 2 ? idx.toDouble() : (idx + 1).toDouble();

  static Future<ui.FragmentProgram>? _selectionMaskProgram;
  static ui.FragmentProgram? _loadedSelectionMaskProgram;

  late double _slot = _tabToSlot(widget.index);
  late double _dragTargetSlot = _slot;
  double _slotVel = 0;
  late double _targetSlot = _slot;

  double _lift = 0;
  double _liftVel = 0;
  double _targetLift = 0;

  bool _scrubbing = false;
  String? _scrubOwner;
  int? _lastDetentSlot;

  ui.FragmentProgram? _maskProgram = _loadedSelectionMaskProgram;
  ui.FragmentShader? _maskShader;

  Ticker? _ticker;
  Duration? _lastTick;

  bool get _scrubberGlassActive =>
      _scrubbing || _lift > 0.002 || (_slot - _targetSlot).abs() > 0.002;

  @override
  void initState() {
    super.initState();
    _maskShader = _maskProgram?.fragmentShader();
    if (_maskProgram == null) {
      unawaited(_loadMaskProgram());
    }
  }

  Future<void> _loadMaskProgram() async {
    try {
      final program = _loadedSelectionMaskProgram ??
          await (_selectionMaskProgram ??= ui.FragmentProgram.fromAsset(
            'assets/shaders/pacer_selection_mask.frag',
          ));
      _loadedSelectionMaskProgram = program;
      if (!mounted) return;
      final shader = program.fragmentShader();
      setState(() {
        _maskProgram = program;
        _maskShader?.dispose();
        _maskShader = shader;
      });
    } catch (_) {
      // Headless widget tests without shader bundle keep gradient fallback.
    }
  }

  @override
  void didUpdateWidget(covariant BottomNavPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !_scrubbing) {
      final newTarget = _tabToSlot(widget.index);
      if ((newTarget - _targetSlot).abs() > 0.01) {
        _targetSlot = newTarget;
        _dragTargetSlot = newTarget;
        if (MediaQuery.disableAnimationsOf(context)) {
          _slot = newTarget;
          _slotVel = 0;
        } else {
          _ensureTicking();
        }
      }
    }
  }

  @override
  void dispose() {
    _maskShader?.dispose();
    _ticker?.dispose();
    super.dispose();
  }

  static (double, double) _stepSpring({
    required double x,
    required double vel,
    required double target,
    required double dt,
    required double stiffness,
    required double damping,
  }) {
    var rem = dt;
    var px = x;
    var pv = vel;
    while (rem > 0) {
      final step = rem > 1 / 240.0 ? 1 / 240.0 : rem;
      final accel = -stiffness * (px - target) - damping * pv;
      pv += accel * step;
      px += pv * step;
      rem -= step;
    }
    return (px, pv);
  }

  void _ensureTicking() {
    final t = _ticker ??= createTicker(_onTick);
    if (!t.isActive) {
      _lastTick = null;
      t.start();
    }
  }

  double _centerXForSlot(double slot) => _padH + (slot + 0.5) * _slotW;

  void _onTick(Duration elapsed) {
    final prev = _lastTick ?? elapsed;
    final dt = ((elapsed - prev).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    if (dt <= 0) return;

    var busy = false;

    if (_scrubbing) {
      // Exponentially chase raw pointer slot so discrete desktop mouse/touchpad
      // quantization never feeds sawtooth acceleration spikes into motion tilt.
      const followTau = 0.038;
      final prevSlot = _slot;
      final alpha = 1.0 - math.exp(-dt / followTau);
      _slot += (_dragTargetSlot - _slot) * alpha;
      _slotVel = (_slot - prevSlot) / dt;
      if ((_dragTargetSlot - _slot).abs() < 0.001) {
        _slot = _dragTargetSlot;
        _slotVel = 0;
      } else {
        busy = true;
      }
    } else {
      final (ns, nsv) = _stepSpring(
        x: _slot,
        vel: _slotVel,
        target: _targetSlot,
        dt: dt,
        stiffness: 290,
        damping: 27,
      );
      _slot = ns;
      _slotVel = nsv;
      if ((_slot - _targetSlot).abs() < 0.002 && _slotVel.abs() < 0.01) {
        _slot = _targetSlot;
        _slotVel = 0;
      } else {
        busy = true;
      }
    }

    final expanding = _targetLift > _lift;
    final (nl, nlv) = _stepSpring(
      x: _lift,
      vel: _liftVel,
      target: _targetLift,
      dt: dt,
      stiffness: expanding ? 360 : 220,
      damping: expanding ? 30 : 25,
    );
    _lift = nl.clamp(0.0, 1.35);
    _liftVel = nlv;
    if ((_lift - _targetLift).abs() < 0.002 && _liftVel.abs() < 0.01) {
      _lift = _targetLift;
      _liftVel = 0;
    } else {
      busy = true;
    }

    if (!busy && !_scrubbing) {
      _ticker?.stop();
    }
    if (mounted) setState(() {});
  }

  double _rawSlotFromDx(double dx) {
    final raw = ((dx - _padH) / _slotW) - 0.5;
    if (raw < 0) return math.max(-0.14, raw * 0.35);
    if (raw > 4) return math.min(4.14, 4 + (raw - 4) * 0.35);
    return raw;
  }

  int _snappedSlot(double slot) => slot.round().clamp(0, 4);

  void _triggerSlotDetent(int slot) {
    if (_lastDetentSlot == slot) return;
    _lastDetentSlot = slot;
    if (slot == 2) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _beginScrub(String owner, double localDx) {
    if (_scrubbing && _scrubOwner != owner) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final slot = _rawSlotFromDx(localDx);
    _scrubbing = true;
    _scrubOwner = owner;
    _dragTargetSlot = slot;
    _targetSlot = slot;
    _targetLift = 1.0;
    _lastDetentSlot = _snappedSlot(slot);
    HapticFeedback.selectionClick();
    if (reduceMotion) {
      _slot = slot;
      _slotVel = 0;
      _lift = 1.0;
      _liftVel = 0;
      setState(() {});
    } else {
      _ensureTicking();
      setState(() {});
    }
  }

  void _updateScrub(String owner, double localDx) {
    if (!_scrubbing || _scrubOwner != owner) return;
    final slot = _rawSlotFromDx(localDx);
    _dragTargetSlot = slot;
    _targetSlot = slot;
    _triggerSlotDetent(_snappedSlot(slot));
    if (MediaQuery.disableAnimationsOf(context)) {
      _slot = slot;
      _slotVel = 0;
      if (mounted) setState(() {});
    } else {
      _ensureTicking();
    }
  }

  void _endScrub(String owner, {required bool commit}) {
    if (!_scrubbing || _scrubOwner != owner) return;
    final landedSlot = _snappedSlot(_dragTargetSlot);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _scrubbing = false;
    _scrubOwner = null;
    _lastDetentSlot = null;
    _targetLift = 0.0;

    if (commit) {
      final tabIdx = _slotToTab[landedSlot];
      if (tabIdx != null) {
        _targetSlot = landedSlot.toDouble();
        _dragTargetSlot = _targetSlot;
        widget.onTap(tabIdx);
      } else {
        // Released over center START orb: launch Start & return resting pill
        // smoothly back to the currently selected tab.
        _targetSlot = _tabToSlot(widget.index);
        _dragTargetSlot = _targetSlot;
        HapticFeedback.mediumImpact();
        widget.onStart();
      }
    } else {
      _targetSlot = _tabToSlot(widget.index);
      _dragTargetSlot = _targetSlot;
    }

    if (reduceMotion) {
      _slot = _targetSlot;
      _slotVel = 0;
      _lift = 0;
      _liftVel = 0;
      setState(() {});
    } else {
      _ensureTicking();
      setState(() {});
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_scrubbing) return;
    final slot = _snappedSlot(_rawSlotFromDx(details.localPosition.dx));
    final tabIdx = _slotToTab[slot];
    if (tabIdx == null) {
      HapticFeedback.mediumImpact();
      widget.onStart();
      return;
    }
    HapticFeedback.selectionClick();
    widget.onTap(tabIdx);
    final newSlot = _tabToSlot(tabIdx);
    if (!MediaQuery.disableAnimationsOf(context) &&
        (newSlot - _slot).abs() > 0.01) {
      _targetSlot = newSlot;
      _dragTargetSlot = newSlot;
      _ensureTicking();
    } else {
      setState(() {
        _slot = newSlot;
        _targetSlot = newSlot;
        _dragTargetSlot = newSlot;
      });
    }
  }

  /// Continuous pill -> circle morph progress near the center START orb (slot 2).
  double get _circleMorph {
    final dist = (_slot - 2.0).abs();
    final t = (1.0 - dist / 0.52).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Per-tab glyphs matching the nav rail: outlined idle, filled selected.
    final tabs = [
      (Icons.home_outlined, Icons.home, S.home),
      (Icons.history_outlined, Icons.history, S.history),
      (Icons.groups_outlined, Icons.groups, S.teams),
      (Icons.leaderboard_outlined, Icons.leaderboard, S.leaderboard),
    ];
    final tint = dark ? scheme.card : scheme.navBar;
    final pillAccent = dark ? scheme.accent : scheme.brandAccent;
    final selectedFg = dark ? scheme.accent : const Color(0xFF102A43);
    final circleMorph = _circleMorph;
    final liftClamped = _lift.clamp(0.0, 1.25);

    Widget tab(
      int tabIdx, {
      bool baseOnly = false,
      bool includeSemantics = true,
    }) {
      final selected = widget.index == tabIdx;
      final highlighted = !baseOnly && selected;
      final Color tabColor = highlighted ? selectedFg : scheme.navIcon;
      final IconData iconGlyph = selected ? tabs[tabIdx].$2 : tabs[tabIdx].$1;

      final Widget visualTab = SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                iconGlyph,
                size: 23,
                color: tabColor,
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tabs[tabIdx].$3,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: tabColor,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (!includeSemantics) return visualTab;

      return Semantics(
        selected: selected,
        button: true,
        label: tabs[tabIdx].$3,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap(tabIdx);
        },
        child: ExcludeSemantics(child: visualTab),
      );
    }

    final startBoost = circleMorph * liftClamped.clamp(0.0, 1.0);
    final startButton = Semantics(
      button: true,
      label: 'START',
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onStart();
      },
      excludeSemantics: true,
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
            color: Colors.white.withValues(alpha: 0.45 + 0.35 * startBoost),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: PacerColors.primary.withValues(
                alpha: 0.50 + 0.25 * startBoost,
              ),
              blurRadius: 18 + 8 * startBoost,
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
    );

    Widget buildIconRow({
      bool baseOnly = false,
      bool includeStart = true,
      bool includeSemantics = true,
    }) =>
        SizedBox(
          width: _barWidth,
          height: _barHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _padH,
              vertical: _padV,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: tab(
                      0,
                      baseOnly: baseOnly,
                      includeSemantics: includeSemantics,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: tab(
                      1,
                      baseOnly: baseOnly,
                      includeSemantics: includeSemantics,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: includeStart
                        ? startButton
                        : const SizedBox(width: 64, height: 64),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: tab(
                      2,
                      baseOnly: baseOnly,
                      includeSemantics: includeSemantics,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: tab(
                      3,
                      baseOnly: baseOnly,
                      includeSemantics: includeSemantics,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    const restCubeW = _slotW - 4.0; // 67.4
    const restCubeH = _barHeight - 2 * _padV - 4.0; // 60.7
    const restCubeR = 22.0;
    const overflowPadX = 28.0;
    const overflowPadY = 20.0;

    final restCubeFill = pillAccent.withValues(alpha: dark ? 0.18 : 0.54);
    final restCubeBorder = dark
        ? pillAccent.withValues(alpha: 0.42)
        : const Color(0xFF82B800).withValues(alpha: 0.65);
    final restCubeShadow = pillAccent.withValues(alpha: dark ? 0.20 : 0.26);

    // Layer 0 stays mounted in MainShell directly (never reparented into an
    // inner LiquidGlassView.backgroundWidget) so Skia/Impeller refraction over
    // the scrolling page stays sharp with zero offscreen crop artifacts.
    final Widget barCapsule = SizedBox(
      width: _barWidth,
      height: _barHeight,
      child: PacerGlass.navigation(
        radius: 36,
        tintColor: tint,
        tintOpacity: PacerGlassTheme.navigationOpacity(context),
        blurSigmaOverride: BottomNavPill.blurSigma,
        lensBlurSigma: 2.8,
        refractionWidth: 12.0,
        refractionIndexOverride: 1.18,
        magnification: 1.02,
        dispersionOverride: 1.2,
        saturation: 1.08,
        continuousCorners: true,
        child: const SizedBox.expand(),
      ),
    );

    final Widget restLayer = SizedBox(
      width: _barWidth,
      height: _barHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: _padH + _slot * _slotW + 2,
            top: _padV + 2,
            width: restCubeW,
            height: restCubeH,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: restCubeFill,
                  borderRadius: BorderRadius.circular(restCubeR),
                  border: Border.all(
                    color: restCubeBorder,
                    width: dark ? 0.75 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: restCubeShadow,
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          buildIconRow(),
        ],
      ),
    );

    Widget visual;
    if (!_scrubberGlassActive) {
      visual = Stack(
        clipBehavior: Clip.none,
        children: [barCapsule, restLayer],
      );
    } else {
      final liftFrac = _lift.clamp(0.0, 1.25);
      // Expand into a crystal-clear water-drop capsule (108x94, r47) taller
      // than the 80.7px navbar so top/bottom overhang is clear, morphing into
      // a true 94x94 circle (r47) over the START orb.
      final activeW = ui.lerpDouble(108.0, 94.0, circleMorph)!;
      final activeH = ui.lerpDouble(94.0, 94.0, circleMorph)!;
      final activeR = ui.lerpDouble(47.0, 47.0, circleMorph)!;
      final dropW = ui.lerpDouble(restCubeW, activeW, liftFrac)!.clamp(restCubeW, 124.0);
      final dropH = ui.lerpDouble(restCubeH, activeH, liftFrac)!.clamp(restCubeH, 108.0);
      final cornerR = ui.lerpDouble(
        restCubeR,
        activeR,
        liftFrac,
      )!.clamp(8.0, dropH / 2);

      final liftUnit = liftFrac.clamp(0.0, 1.0);
      final travelFrac = ((_slot - _targetSlot).abs() / 0.25).clamp(0.0, 1.0);
      final dropPresence = math.max(liftUnit, travelFrac * 0.55);
      final glassPresence = math.pow(dropPresence, 1.25).toDouble();

      // Smoothly shed the rest active fill into near-clear crystal glass when
      // lifted, then blend back to exact restCubeFill/Border/Width on release
      // so handover to restLayer has zero alpha/color flash.
      final colorBlendT = Curves.easeOut.transform(liftUnit);
      final liftedCrystalFill = Colors.white.withValues(alpha: dark ? 0.04 : 0.14);
      final startCircleFill = PacerColors.primary.withValues(
        alpha: dark ? 0.06 : 0.12,
      );
      final cubeOrCircleFill = Color.lerp(
        Color.lerp(restCubeFill, liftedCrystalFill, colorBlendT)!,
        startCircleFill,
        circleMorph,
      )!;

      final restBorderWidth = dark ? 0.75 : 1.0;
      final liftedGlassRim = Colors.white.withValues(alpha: dark ? 0.36 : 0.72);
      final dropBorder = Color.lerp(
        Color.lerp(restCubeBorder, liftedGlassRim, colorBlendT)!,
        PacerColors.primary.withValues(alpha: 0.90),
        circleMorph,
      )!;
      final dropBorderWidth = ui.lerpDouble(
        ui.lerpDouble(restBorderWidth, 0.95, colorBlendT)!,
        1.4,
        circleMorph,
      )!;
      final dropRim = Color.lerp(
        liftedGlassRim,
        PacerColors.primary.withValues(alpha: 0.92),
        circleMorph,
      )!;
      final liftedContactShadow = Colors.black.withValues(
        alpha: dark ? 0.22 : 0.12,
      );
      final dropShadow = Color.lerp(
        Color.lerp(restCubeShadow, liftedContactShadow, colorBlendT)!,
        PacerColors.primary.withValues(alpha: 0.42 * liftUnit),
        circleMorph,
      )!;
      final glowAlpha = (circleMorph * liftUnit).clamp(0.0, 1.0);
      final dropGlow = glowAlpha > 0.005
          ? PacerColors.primary.withValues(alpha: glowAlpha)
          : null;

      final dropCenter = Offset(_centerXForSlot(_slot), _centerY);
      final dropRectInBar = Rect.fromCenter(
        center: dropCenter,
        width: dropW,
        height: dropH,
      );

      final droplet = PacerScrubberDroplet(
        key: const ValueKey('pacer_nav_scrubber_droplet'),
        center: dropCenter,
        coordinateOffset: const Offset(overflowPadX, overflowPadY),
        size: Size(dropW, dropH),
        cornerRadius: cornerR,
        tintColor: cubeOrCircleFill,
        rimColor: dropRim,
        borderColor: dropBorder,
        borderWidth: dropBorderWidth,
        cubeShadowColor: dropShadow,
        glowColor: dropGlow,
        glassPresence: glassPresence,
        cubePresence: 1.0 - 0.15 * circleMorph * liftUnit,
        blur: 0.0,
        refractionIndex: 1.022,
        refractionWidth: 14.0,
        magnification: 1.0,
        dispersion: 1.32,
      );

      final bool shaderNative = PacerGlass.isShaderBackdropSupported;

      // Hairline rim proxy inside the Skia background strip lets the droplet's
      // edge refraction bend the navbar border cleanly while keeping fill clear.
      final Widget capsuleRimProxy = IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? 0.16 : 0.38),
              width: 1.0,
            ),
          ),
        ),
      );

      // Single fixed-geometry tab row recolored under the lens by an SDF
      // ShaderMask (matching MornyeSelectionPill): zero size/weight/ClipPath
      // jumps while sliding across icons. START sits outside the mask.
      final Widget iconStrip = Stack(
        fit: StackFit.expand,
        children: [
          _NavSelectionMask(
            maskRect: dropRectInBar,
            cornerRadius: cornerR,
            color: selectedFg,
            shader: _maskShader,
            child: buildIconRow(
              baseOnly: true,
              includeStart: false,
              includeSemantics: true,
            ),
          ),
          Center(child: startButton),
        ],
      );

      final Widget foregroundInCanvas = SizedBox(
        width: _barWidth + 2 * overflowPadX,
        height: _barHeight + 2 * overflowPadY,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: overflowPadX,
              top: overflowPadY,
              width: _barWidth,
              height: _barHeight,
              child: shaderNative
                  ? iconStrip
                  : Stack(children: [capsuleRimProxy, iconStrip]),
            ),
          ],
        ),
      );

      final Widget scrubberOverlay = Positioned(
        left: -overflowPadX,
        top: -overflowPadY,
        width: _barWidth + 2 * overflowPadX,
        height: _barHeight + 2 * overflowPadY,
        child: shaderNative
            ? Stack(
                clipBehavior: Clip.none,
                children: [foregroundInCanvas, droplet],
              )
            : LiquidGlassView(
                pixelRatio: MediaQuery.devicePixelRatioOf(
                  context,
                ).clamp(1.0, 2.0),
                realTimeCapture: true,
                refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
                useSync: true,
                batch: false,
                backgroundWidget: foregroundInCanvas,
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [droplet],
                ),
              ),
      );

      visual = Stack(
        clipBehavior: Clip.none,
        children: [barCapsule, scrubberOverlay],
      );
    }

    return SizedBox(
      width: _barWidth,
      height: _barHeight,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            () => TapGestureRecognizer(),
            (instance) => instance.onTapUp = _onTapUp,
          ),
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              duration: const Duration(milliseconds: 140),
            ),
            (instance) => instance
              ..onLongPressStart = ((d) => _beginScrub('long', d.localPosition.dx))
              ..onLongPressMoveUpdate = ((d) => _updateScrub('long', d.localPosition.dx))
              ..onLongPressEnd = ((_) => _endScrub('long', commit: true))
              ..onLongPressCancel = (() => _endScrub('long', commit: false)),
          ),
          HorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                  HorizontalDragGestureRecognizer>(
            () => HorizontalDragGestureRecognizer(),
            (instance) => instance
              ..onStart = ((d) => _beginScrub('drag', d.localPosition.dx))
              ..onUpdate = ((d) => _updateScrub('drag', d.localPosition.dx))
              ..onEnd = ((_) => _endScrub('drag', commit: true))
              ..onCancel = (() => _endScrub('drag', commit: false)),
          ),
        },
        child: visual,
      ),
    );
  }
}

class _NavSelectionMask extends StatelessWidget {
  const _NavSelectionMask({
    required this.maskRect,
    required this.cornerRadius,
    required this.color,
    required this.shader,
    required this.child,
  });

  final Rect maskRect;
  final double cornerRadius;
  final Color color;
  final ui.FragmentShader? shader;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (_) {
        final s = shader;
        if (s != null) {
          s
            ..setFloat(0, maskRect.left)
            ..setFloat(1, maskRect.top)
            ..setFloat(2, maskRect.width)
            ..setFloat(3, maskRect.height)
            ..setFloat(4, 1.0)
            ..setFloat(5, 1.0)
            ..setFloat(6, cornerRadius.clamp(0.0, maskRect.height / 2))
            ..setFloat(7, color.r)
            ..setFloat(8, color.g)
            ..setFloat(9, color.b)
            ..setFloat(10, color.a);
          return s;
        }
        return ui.Gradient.linear(
          Offset(maskRect.left, 0),
          Offset(maskRect.right, 0),
          [color.withValues(alpha: 0), color, color, color.withValues(alpha: 0)],
          const [0.0, 0.015, 0.985, 1.0],
          ui.TileMode.decal,
        );
      },
      child: child,
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
