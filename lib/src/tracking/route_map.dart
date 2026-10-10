import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Simple Strava-like route view: OpenStreetMap tiles (no API key) render
/// immediately — even before GPS lock — with a lime route polyline and a
/// runner dot once fixes arrive. Empty points show a small overlay chip
/// instead of a fake map.
///
/// [minimal] drops the tiles for a clean offline canvas (grid + fitted
/// route): cheaper, private, always available.
class RouteMap extends StatefulWidget {
  final List<LatLng> points;
  final double height;
  final bool minimal;
  const RouteMap({
    super.key,
    required this.points,
    this.height = 300,
    this.minimal = false,
  });

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final MapController _controller = MapController();

  static const LatLng _fallback = LatLng(-6.2296, 106.8294);
  static const Color _route = Color(0xFFBAFF29);

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.points.isNotEmpty &&
        widget.points.length != oldWidget.points.length) {
      _controller.move(widget.points.last, _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    // CARTO basemaps: Positron (light) / Dark Matter (dark) — clean minimal
    // tiles, no API key. Attribution is legally required (see below).
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Minimal mode: offline canvas (grid + fitted route), no tiles.
    if (widget.minimal) {
      return SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: const Color(0xFFE2E8F0),
            child: CustomPaint(
              painter: _MinimalRoutePainter(pts),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Grid paint behind the tiles: tile failure (offline, blocked
            // UA) degrades to a route grid instead of a black box.
            Positioned.fill(
              child: Container(
                color: const Color(0xFFE2E8F0),
                child: CustomPaint(painter: _GridPainter()),
              ),
            ),
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: pts.isEmpty ? _fallback : pts.last,
                initialZoom: 16,
                // Transparent so the grid fallback shows through on tile failure.
                backgroundColor: Colors.transparent,
              ),
              children: [
                TileLayer(
                  // CARTO Positron / Dark Matter: minimal, label-light —
                  // the closest keyless match to the requested Aubergine look
                  // (roads read, labels whisper). Attribution below is required.
                  urlTemplate: dark
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                      : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.pacer',
                ),
                if (pts.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: pts, strokeWidth: 5, color: _route),
                    ],
                  ),
                if (pts.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pts.last,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _route,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Icon(
                            Icons.directions_run,
                            size: 22,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                // Attribution is legally required for OSM + CARTO tiles.
                SimpleAttributionWidget(
                  source: const Text('© OpenStreetMap contributors © CARTO'),
                ),
              ],
            ),
            // Empty route: small overlay chip over live geography.
            if (pts.isEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.route, color: Color(0xFFBAFF29), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Belum ada rute',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Light route grid: fallback paint behind the tile layer.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Fitted route shape for minimal mode: uniform scale + center so the
/// route never clips, regardless of aspect.
class _MinimalRoutePainter extends CustomPainter {
  final List<LatLng> points;
  static const Color _route = Color(0xFFBAFF29);

  _MinimalRoutePainter(this.points);

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
    if ((maxLat - minLat).abs() < 1e-9) {
      minLat -= 0.0005;
      maxLat += 0.0005;
    }
    if ((maxLng - minLng).abs() < 1e-9) {
      minLng -= 0.0005;
      maxLng += 0.0005;
    }
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
  bool shouldRepaint(covariant _MinimalRoutePainter old) =>
      old.points != points;
}
