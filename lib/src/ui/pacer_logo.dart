import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Wordmark colouring for [PacerLogo].
enum PacerLogoStyle {
  /// Icon + wordmark both in the brand gradient.
  gradient,

  /// Gradient icon, white wordmark (for dark surfaces).
  onDark,

  /// Gradient icon, navy wordmark (for light surfaces).
  onLight,

  /// Single flat colour for icon and wordmark (watermarks, print).
  mono,
}

/// Brand gradient: Pacer sky-blue (bottom-left) to lime (top-right).
const LinearGradient pacerBrandGradient = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [PacerColors.primary, PacerColors.lime],
);

/// The "p" mark: stem + bowl, skewed -16°, with an open counter and three
/// horizontal "speed cuts". Built as geometry (union minus cutouts), so it
/// scales crisply and can take any fill. Lives in a 130x120 box.
Path pacerMarkPath({double cutHeight = 4}) {
  final stem = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 20, 20, 80),
        const Radius.circular(4),
      ),
    );
  final bowl = Path()
    ..moveTo(34, 20)
    ..lineTo(65, 20)
    ..arcToPoint(
      const Offset(65, 80),
      radius: const Radius.circular(30),
      clockwise: true,
    )
    ..lineTo(34, 80)
    ..close();
  final counter = Path()
    ..moveTo(10, 38)
    ..lineTo(65, 38)
    ..arcToPoint(
      const Offset(65, 62),
      radius: const Radius.circular(12),
      clockwise: true,
    )
    ..lineTo(10, 62)
    ..close();

  var shape = Path.combine(PathOperation.union, stem, bowl);
  shape = Path.combine(PathOperation.difference, shape, counter);
  for (final y in const [49.0, 67.0, 85.0]) {
    shape = Path.combine(
      PathOperation.difference,
      shape,
      Path()..addRect(Rect.fromLTWH(-20, y, 120, cutHeight)),
    );
  }
  // SVG: skewX(-16) translate(30, 0) — translate first, then skew.
  final m = Matrix4.identity()
    ..setEntry(0, 1, math.tan(-16 * math.pi / 180))
    ..translateByDouble(30, 0, 0, 1);
  return shape.transform(m.storage);
}

class _MarkPainter extends CustomPainter {
  final Gradient? gradient;
  final Color color;
  const _MarkPainter({this.gradient, this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 130;
    canvas.scale(s);
    final paint = Paint()..isAntiAlias = true;
    if (gradient != null) {
      paint.shader = gradient!.createShader(const Rect.fromLTWH(0, 0, 130, 120));
    } else {
      paint.color = color;
    }
    canvas.drawPath(pacerMarkPath(), paint);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.gradient != gradient || old.color != color;
}

/// Just the "p" mark (app icon, favicon, avatars). 130:120 aspect.
class PacerMark extends StatelessWidget {
  final double width;

  /// Null = brand gradient.
  final Color? color;
  const PacerMark({super.key, this.width = 48, this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pacer',
      image: true,
      child: CustomPaint(
        size: Size(width, width * 120 / 130),
        painter: _MarkPainter(
          gradient: color == null ? pacerBrandGradient : null,
          color: color ?? Colors.white,
        ),
      ),
    );
  }
}

/// Full lockup: mark + italic "acer" wordmark (the mark reads as the "p").
/// Native 400x120 design box, scaled to [width].
class PacerLogoLockup extends StatelessWidget {
  final double width;

  /// Null = follow the theme (dark → white wordmark, light → navy).
  final PacerLogoStyle? style;
  final Color monoColor;
  const PacerLogoLockup({
    super.key,
    this.width = 198,
    this.style,
    this.monoColor = PacerColors.slate800,
  });

  @override
  Widget build(BuildContext context) {
    final resolved =
        style ??
        (Theme.of(context).brightness == Brightness.dark
            ? PacerLogoStyle.onDark
            : PacerLogoStyle.onLight);
    final mono = resolved == PacerLogoStyle.mono;

    final textStyle = GoogleFonts.montserrat(
      fontSize: 82,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: -0.06 * 82,
      height: 1,
      color: switch (resolved) {
        PacerLogoStyle.onDark => Colors.white,
        PacerLogoStyle.onLight => PacerColors.navy,
        PacerLogoStyle.mono => monoColor,
        PacerLogoStyle.gradient => Colors.white, // masked below
      },
    );
    Widget word = Text('acer', style: textStyle, softWrap: false, maxLines: 1);
    if (resolved == PacerLogoStyle.gradient) {
      word = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: pacerBrandGradient.createShader,
        child: word,
      );
    }

    return Semantics(
      label: 'Pacer',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: width * 120 / 400,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 400,
              height: 120,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 130,
                    height: 120,
                    child: CustomPaint(
                      painter: _MarkPainter(
                        gradient: mono ? null : pacerBrandGradient,
                        color: monoColor,
                      ),
                    ),
                  ),
                  // Baseline pinned at y=96 of the design box, like the SVG.
                  Positioned(
                    left: 100,
                    top: 0,
                    child: Baseline(
                      baseline: 96,
                      baselineType: TextBaseline.alphabetic,
                      child: word,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
