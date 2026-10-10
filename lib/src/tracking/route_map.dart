import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Simple Strava-like route view: OpenStreetMap tiles (no API key) render
/// immediately — even before GPS lock — with a lime route polyline and a
/// runner dot once fixes arrive. Empty points show a small overlay chip
/// instead of a fake map.
class RouteMap extends StatefulWidget {
  final List<LatLng> points;
  final double height;
  const RouteMap({super.key, required this.points, this.height = 300});

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
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: pts.isEmpty ? _fallback : pts.last,
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
