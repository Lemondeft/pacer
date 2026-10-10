import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Offline route shape: draws [points] as a lime polyline fitted to the
/// canvas with aspect preserved, no tiles, no network, nothing to fail.
/// Empty points render a neutral placeholder box instead of a fake map.
class RouteMap extends StatelessWidget {
  final List<LatLng> points;
  final double height;
  const RouteMap({super.key, required this.points, this.height = 300});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.route, color: Color(0xFFBAFF29), size: 40),
              SizedBox(height: 8),
              Text(
                'Belum ada rute',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: const Color(0xFF0F172A),
          child: CustomPaint(
            painter: _RouteShapePainter(points),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _RouteShapePainter extends CustomPainter {
  final List<LatLng> points;
  static const Color _route = Color(0xFFBAFF29);

  _RouteShapePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // Degenerate bounds (single fix): pad so the math never divides by zero.
    if ((maxLat - minLat).abs() < 1e-9) {
      minLat -= 0.0005;
      maxLat += 0.0005;
    }
    if ((maxLng - minLng).abs() < 1e-9) {
      minLng -= 0.0005;
      maxLng += 0.0005;
    }
    // Uniform scale + center: aspect preserved, route never clips.
    const pad = 24.0;
    final sx = (size.width - pad * 2) / (maxLng - minLng);
    final sy = (size.height - pad * 2) / (maxLat - minLat);
    final s = sx < sy ? sx : sy;
    final dx = (size.width - (maxLng - minLng) * s) / 2;
    final dy = (size.height - (maxLat - minLat) * s) / 2;
    Offset map(LatLng p) =>
        Offset(dx + (p.longitude - minLng) * s, dy + (maxLat - p.latitude) * s);
    final path = Path()..moveTo(map(points.first).dx, map(points.first).dy);
    for (var i = 1; i < points.length; i++) {
      final o = map(points[i]);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _route
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    // Start (white) and current-position (lime) dots.
    canvas.drawCircle(map(points.first), 7, Paint()..color = Colors.white);
    final last = map(points.last);
    canvas.drawCircle(last, 8, Paint()..color = _route);
    canvas.drawCircle(
      last,
      8,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteShapePainter old) => old.points != points;
}
