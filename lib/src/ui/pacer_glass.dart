import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

export 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassBatch;

import 'app_theme.dart';

/// Glass capability levels per GLASSMORPHISM_SPEC.md.
enum PacerGlassLevel {
  /// Opaque surface, zero backdrop sampling.
  flat,

  /// Translucent fill + single BackdropFilter pass.
  frosted,

  /// Impeller shader lens (LiquidGlassLens) refracting a blurred backdrop.
  liquid,
}

/// Glass configuration settings / theme tokens.
class PacerGlassTheme {
  const PacerGlassTheme({
    this.clarity = 0.75,
    this.outlines = true,
    this.level = PacerGlassLevel.liquid,
  });

  final double clarity;
  final bool outlines;
  final PacerGlassLevel level;

  static double clarityOf(BuildContext context) =>
      PacerGlassScope.maybeOf(context)?.clarity ?? 0.75;

  static bool outlinesOf(BuildContext context) =>
      PacerGlassScope.maybeOf(context)?.outlines ?? true;

  static PacerGlassLevel levelOf(BuildContext context) =>
      PacerGlassScope.maybeOf(context)?.level ?? PacerGlassLevel.liquid;

  static double navigationOpacity(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? 0.36 : 0.49;
  }
}

/// Inherited scope to customize or override glass settings for a subtree.
class PacerGlassScope extends InheritedWidget {
  const PacerGlassScope({
    super.key,
    this.clarity = 0.75,
    this.outlines = true,
    this.level = PacerGlassLevel.liquid,
    required super.child,
  });

  final double clarity;
  final bool outlines;
  final PacerGlassLevel level;

  static PacerGlassScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PacerGlassScope>();

  @override
  bool updateShouldNotify(PacerGlassScope oldWidget) =>
      clarity != oldWidget.clarity ||
      outlines != oldWidget.outlines ||
      level != oldWidget.level;
}

/// Marker that tells nested controls "you sit on glass, don't re-blur"
/// (Rule #1: One surface, one blur).
class _GlassBackdropScope extends InheritedWidget {
  const _GlassBackdropScope({required super.child});

  @override
  bool updateShouldNotify(_GlassBackdropScope oldWidget) => false;
}

/// Continuous-corner squircle border using liquid_glass_easy's continuous path.
class PacerSquircleBorder extends ShapeBorder {
  const PacerSquircleBorder(this.radius);

  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) => PacerSquircleBorder(radius * t);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      liquidGlassSquirclePath(rect.size, radius, 1).shift(rect.topLeft);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  bool operator ==(Object other) =>
      other is PacerSquircleBorder && other.radius == radius;

  @override
  int get hashCode => radius.hashCode;
}

/// Two-stroke hairline rim painter: subtle contact edge + top-light illumination.
class _PacerGlassRim extends CustomPainter {
  const _PacerGlassRim({
    required this.shape,
    required this.firstInGroup,
    required this.lastInGroup,
    required this.illuminated,
    required this.emphasized,
    required this.dark,
    required this.smoothCorners,
    required this.highlightIntensity,
  });

  final BorderRadius shape;
  final bool firstInGroup;
  final bool lastInGroup;
  final bool illuminated;
  final bool emphasized;
  final bool dark;
  final bool smoothCorners;
  final double highlightIntensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final outline = shape.toRRect(
      Rect.fromLTRB(
        0,
        firstInGroup ? 0 : -2,
        size.width,
        lastInGroup ? size.height : size.height + 2,
      ),
    );

    canvas.save();
    canvas.clipRect(bounds);

    void stroke(double inset, Paint paint) {
      if (smoothCorners) {
        canvas.drawPath(
          PacerSquircleBorder(
            (shape.topLeft.x - inset).clamp(0.0, double.infinity),
          ).getOuterPath(bounds.deflate(inset)),
          paint,
        );
      } else {
        canvas.drawRRect(outline.deflate(inset), paint);
      }
    }

    // 1. Contact edge (always): 0.5px stroke at inset 0.25
    stroke(
      0.25,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Colors.black.withValues(alpha: dark ? 0.50 : 0.16),
    );

    // 2. Illumination gradient at inset 0.8
    if (illuminated) {
      stroke(
        0.8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = emphasized ? 1.0 : 0.6
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.14, 0.5, 0.86, 1.0],
            colors: [
              firstInGroup
                  ? Color(emphasized ? 0x88ffffff : 0x40ffffff)
                  : Colors.transparent,
              Color(emphasized ? 0x26ffffff : 0x0dffffff),
              const Color(0x0a000000),
              Color(emphasized ? 0x20ffffff : 0x0dffffff),
              lastInGroup
                  ? Color(emphasized ? 0x55ffffff : 0x26ffffff)
                  : Colors.transparent,
            ]
                .map(
                  (c) => c.withValues(
                    alpha: (c.a * highlightIntensity).clamp(0.0, 1.0),
                  ),
                )
                .toList(),
          ).createShader(bounds),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PacerGlassRim oldDelegate) =>
      shape != oldDelegate.shape ||
      firstInGroup != oldDelegate.firstInGroup ||
      lastInGroup != oldDelegate.lastInGroup ||
      illuminated != oldDelegate.illuminated ||
      emphasized != oldDelegate.emphasized ||
      dark != oldDelegate.dark ||
      smoothCorners != oldDelegate.smoothCorners ||
      highlightIntensity != oldDelegate.highlightIntensity;
}

/// Bounded LiquidGlass lens wrapper.
class PacerLiquidBackdrop extends StatelessWidget {
  const PacerLiquidBackdrop({
    super.key,
    required this.borderRadius,
    required this.clarity,
    required this.blurSigma,
    required this.child,
    this.interaction = false,
    this.progress = 1.0,
    this.refractionDepth = 0.30,
    this.refractionWidth = 20.0,
    this.smoothCorners = false,
    this.highlightIntensity = 1.0,
  });

  final BorderRadius borderRadius;
  final double clarity;
  final double blurSigma;
  final Widget child;
  final bool interaction;
  final double progress;
  final double refractionDepth;
  final double refractionWidth;
  final bool smoothCorners;
  final double highlightIntensity;

  @override
  Widget build(BuildContext context) {
    if (interaction && progress <= 0) return child;
    final effect = interaction ? progress : 1.0;
    final outlines = PacerGlassTheme.outlinesOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final edgeBend =
        math.sqrt(1 - 1 / (1.7 * 1.7)) *
        refractionWidth *
        refractionDepth *
        effect *
        5 /
        70;
    final index = 1 / math.sqrt(1 - math.pow(edgeBend.clamp(0.0, 0.95), 2));

    return LiquidGlassLens(
      style: LiquidGlassStyle(
        shape: LiquidGlassShape(
          cornerStyle: smoothCorners
              ? LiquidGlassCornerStyle.squircle
              : LiquidGlassCornerStyle.roundedRectangle,
          clipQuality: smoothCorners
              ? LiquidGlassClipQuality.exact
              : LiquidGlassClipQuality.roundedRectangle,
          cornerRadius: borderRadius.topLeft.x,
        ),
        specular: LiquidGlassLight.specular(
          thickness: outlines ? 0.75 * 5.4 : 0,
          angle: 0,
          spread: 0.2,
          intensity: outlines
              ? (dark ? 0.25 : 0.12) * effect * highlightIntensity
              : 0,
          color: dark ? Colors.white : const Color(0x88ffffff),
        ),
        glow: LiquidGlassLight.glow(
          thickness: outlines ? 0.75 * 29.4 : 0,
          intensity: outlines ? 0.05 * highlightIntensity : 0,
        ),
        blur: blurSigma,
        refractionIndex: index,
        refractionWidth: refractionWidth,
        dispersion: 1.32 * clarity * effect,
      ),
      child: child,
    );
  }
}

/// Core Glass material matching Mornye GLASSMORPHISM_SPEC.md.
class PacerGlass extends StatelessWidget {
  const PacerGlass({
    super.key,
    required this.child,
    this.blurEnabled = true,
    this.radius = 32,
    this.firstInGroup = true,
    this.lastInGroup = true,
    this.strongTint = false,
    this.tintOpacity,
    this.tintColor,
    this.samplesBackdrop = true,
    this.highlightBorder = false,
    this.refractionDepth = 0.30,
    this.smoothCorners = false,
    this.highlightIntensity = 1.0,
    this.glassProgress = 1.0,
    this.blurSigmaOverride,
  });

  const PacerGlass.navigation({
    super.key,
    required this.child,
    this.blurEnabled = true,
    this.radius = 32,
    this.firstInGroup = true,
    this.lastInGroup = true,
    this.strongTint = true,
    this.tintOpacity,
    this.tintColor,
    this.samplesBackdrop = true,
    this.highlightBorder = false,
    this.refractionDepth = 0.30,
    this.smoothCorners = false,
    this.highlightIntensity = 1.0,
    this.glassProgress = 1.0,
    this.blurSigmaOverride,
  });

  // Quantized pre-constructed blur sigmas bank (Spec §5.5)
  static const _blurSigmas = [2.0, 3.0, 6.0, 16.0];
  static final _blurs = [
    for (final sigma in _blurSigmas)
      ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
  ];

  @visibleForTesting
  static bool? debugShaderFilterSupport;

  final Widget child;
  final bool blurEnabled;
  final double radius;
  final bool firstInGroup;
  final bool lastInGroup;
  final bool strongTint;
  final double? tintOpacity;
  final Color? tintColor;
  final bool samplesBackdrop;
  final bool highlightBorder;
  final double refractionDepth;
  final bool smoothCorners;
  final double highlightIntensity;
  final double glassProgress;
  final double? blurSigmaOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final clarity = PacerGlassTheme.clarityOf(context);
    final level = PacerGlassTheme.levelOf(context);
    final outlines = PacerGlassTheme.outlinesOf(context);
    final reveal = glassProgress.clamp(0.0, 1.0);

    final highContrast = MediaQuery.highContrastOf(context);
    final translucent =
        reveal > 0 &&
        blurEnabled &&
        level != PacerGlassLevel.flat &&
        clarity > 0 &&
        !highContrast;

    final shape = BorderRadius.vertical(
      top: firstInGroup ? Radius.circular(radius) : Radius.zero,
      bottom: lastInGroup ? Radius.circular(radius) : Radius.zero,
    );

    final scheme = PacerScheme.of(context);
    final fallbackTint = dark ? PacerDark.navBar : scheme.navBar;
    var tint = fallbackTint;

    if (translucent) {
      final tintSource = tintColor ?? fallbackTint;
      final opacity = tintOpacity ?? (strongTint ? 0.80 : 0.60);

      var baseTint = tintSource.withValues(
        alpha: dark
            ? (opacity * 0.82).clamp(0.0, 1.0)
            : (opacity * 0.88).clamp(0.50, 1.0),
      );

      if (dark) {
        baseTint = Color.alphaBlend(
          baseTint,
          Colors.black.withValues(alpha: 0.35),
        );
      }

      final tintStrength = (1.0 - clarity) * (1.0 - clarity);
      tint = Color.alphaBlend(
        fallbackTint.withValues(alpha: tintStrength),
        baseTint,
      );
    }

    final insideGlass =
        context.dependOnInheritedWidgetOfExactType<_GlassBackdropScope>() !=
        null;
    final blurThreshold = level == PacerGlassLevel.frosted ? 0.5 : 0.2;
    final sampleBackdrop =
        translucent &&
        samplesBackdrop &&
        !insideGlass &&
        clarity > blurThreshold;

    final shaderSupported =
        debugShaderFilterSupport ?? ImageFilter.isShaderFilterSupported;
    final useLens =
        sampleBackdrop &&
        firstInGroup &&
        lastInGroup &&
        level == PacerGlassLevel.liquid &&
        shaderSupported;

    final filterIndex = level == PacerGlassLevel.frosted
        ? 1
        : clarity >= 0.9
        ? 0
        : clarity >= 0.6
        ? 2
        : 3;

    final effectiveSigma = blurSigmaOverride ?? _blurSigmas[filterIndex];
    final effectiveBlur = blurSigmaOverride != null
        ? ImageFilter.blur(
            sigmaX: blurSigmaOverride!,
            sigmaY: blurSigmaOverride!,
          )
        : _blurs[filterIndex];

    final clearFill = (dark ? const Color(0xff999999) : Colors.white)
        .withValues(alpha: dark ? 0.17 : 0.46);

    final fill = Color.lerp(
      fallbackTint,
      useLens && !strongTint
          ? Color.lerp(tint, clearFill, ((clarity - 0.2) / 0.8).clamp(0.0, 1.0))
          : tint,
      reveal,
    )!;

    final squircle = smoothCorners && firstInGroup && lastInGroup;
    final surface = DecoratedBox(
      decoration: squircle
          ? ShapeDecoration(color: fill, shape: PacerSquircleBorder(radius))
          : BoxDecoration(color: fill, borderRadius: shape),
      child: _GlassBackdropScope(child: child),
    );

    // Single outer shadow (Spec §5.6.1)
    final shadows = firstInGroup && lastInGroup
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.14 : 0.08),
              blurRadius: 8,
              blurStyle: BlurStyle.outer,
              offset: const Offset(0, 2),
            ),
          ]
        : null;

    final lens = useLens
        ? PacerLiquidBackdrop(
            borderRadius: shape,
            clarity: clarity,
            blurSigma: effectiveSigma,
            refractionDepth: refractionDepth * reveal,
            smoothCorners: squircle,
            highlightIntensity: highlightIntensity * reveal,
            child: surface,
          )
        : null;

    final backdrop = lens != null
        ? LiquidGlassBatch.backdropIdOf(context) == null
              ? LiquidGlassBatch(child: lens)
              : lens
        : sampleBackdrop
        ? BackdropFilter(filter: effectiveBlur, child: surface)
        : surface;

    return DecoratedBox(
      decoration: squircle
          ? ShapeDecoration(
              shape: PacerSquircleBorder(radius),
              shadows: shadows,
            )
          : BoxDecoration(borderRadius: shape, boxShadow: shadows),
      child: CustomPaint(
        foregroundPainter: outlines && (!useLens || highlightBorder)
            ? _PacerGlassRim(
                shape: shape,
                firstInGroup: firstInGroup,
                lastInGroup: lastInGroup,
                illuminated: translucent && (!useLens || highlightBorder),
                emphasized: highlightBorder,
                dark: dark,
                smoothCorners: squircle,
                highlightIntensity: highlightIntensity * reveal,
              )
            : null,
        child: squircle
            ? ClipPath.shape(
                shape: PacerSquircleBorder(radius),
                child: backdrop,
              )
            : ClipRRect(borderRadius: shape, child: backdrop),
      ),
    );
  }
}

/// Liquid press physics for controls sitting on glass (Spec §9).
/// Underdamped spring: mass 1, stiffness 420, damping 24.
/// Soft pointer illumination and subtle fluid swell.
class PacerGlassPress extends StatefulWidget {
  const PacerGlassPress({
    super.key,
    required this.radius,
    required this.child,
    this.enabled = true,
  });

  final double radius;
  final Widget child;
  final bool enabled;

  @override
  State<PacerGlassPress> createState() => _PacerGlassPressState();
}

class _PacerGlassPressState extends State<PacerGlassPress>
    with SingleTickerProviderStateMixin {
  static const _hoverLevel = 0.3;
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 24,
  );

  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );
  final _drag = ValueNotifier<Offset>(Offset.zero);
  late final Listenable _motion = Listenable.merge([_press, _drag]);

  Offset? _pointer;
  Offset _origin = Offset.zero;
  Size _size = Size.zero;
  int? _activePointer;
  bool _hovered = false;

  @override
  void dispose() {
    _press.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _measure() {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) _size = box.size;
  }

  void _settle() {
    final target = _activePointer != null
        ? 1.0
        : _hovered
        ? _hoverLevel
        : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _press.value = target;
      return;
    }
    _press.animateWith(
      SpringSimulation(
        _spring,
        _press.value,
        target,
        _press.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final still = MediaQuery.disableAnimationsOf(context);
    final radius = widget.radius;

    return MouseRegion(
      opaque: false,
      onEnter: (event) {
        _measure();
        _hovered = true;
        _pointer = event.localPosition;
        _settle();
      },
      onHover: (event) => _pointer = event.localPosition,
      onExit: (_) {
        _hovered = false;
        _settle();
      },
      child: Listener(
        onPointerDown: (event) {
          if (_activePointer != null) return;
          _measure();
          _activePointer = event.pointer;
          _origin = event.localPosition;
          _pointer = event.localPosition;
          _drag.value = Offset.zero;
          _settle();
        },
        onPointerMove: (event) {
          if (event.pointer != _activePointer) return;
          _pointer = event.localPosition;
          _drag.value = event.localPosition - _origin;
        },
        onPointerUp: (event) {
          if (event.pointer != _activePointer) return;
          _activePointer = null;
          _settle();
        },
        onPointerCancel: (event) {
          if (event.pointer != _activePointer) return;
          _activePointer = null;
          _settle();
        },
        child: AnimatedBuilder(
          animation: _motion,
          child: widget.child,
          builder: (context, child) {
            final press = _press.value;
            return Transform(
              alignment: Alignment.center,
              transform: still || _size.isEmpty || press == 0
                  ? Matrix4.identity()
                  : _deformation(press),
              transformHitTests: false,
              child: CustomPaint(
                foregroundPainter: _GlassLightPainter(
                  center: _pointer,
                  strength: press.clamp(0.0, 1.0),
                  radius: radius,
                ),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }

  Matrix4 _deformation(double press) {
    final swell = (_size.shortestSide * 0.10).clamp(2.0, 5.0) * press;
    var scaleX = 1 + swell / _size.width;
    var scaleY = 1 + swell / _size.height;
    final lean = Offset(
      (_drag.value.dx / 40).clamp(-1.0, 1.0),
      (_drag.value.dy / 40).clamp(-1.0, 1.0),
    );
    final bias = math.max(press, 0.0);
    scaleX += (lean.dx.abs() * 0.05 - lean.dy.abs() * 0.025) * bias;
    scaleY += (lean.dy.abs() * 0.05 - lean.dx.abs() * 0.025) * bias;
    return Matrix4.identity()
      ..translateByDouble(lean.dx * 3 * bias, lean.dy * 3 * bias, 0.0, 1.0)
      ..scaleByDouble(scaleX, scaleY, 1.0, 1.0);
  }
}

/// Soft pointer illumination inside the control's shape.
class _GlassLightPainter extends CustomPainter {
  const _GlassLightPainter({
    required this.center,
    required this.strength,
    required this.radius,
  });

  final Offset? center;
  final double strength;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final bounds = Offset.zero & size;
    final focus = center ?? bounds.center;
    final reach = size.longestSide.clamp(40.0, 180.0);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(bounds, Radius.circular(radius)));
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.20 * strength),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: focus, radius: reach)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassLightPainter oldDelegate) =>
      center != oldDelegate.center ||
      strength != oldDelegate.strength ||
      radius != oldDelegate.radius;
}
