import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Simple Strava-like route view: OpenStreetMap tiles (no API key), lime
/// route polyline, runner dot that the camera follows. Empty points render
/// a neutral placeholder instead of a fake map.
class RouteMap extends StatefulWidget {
  final List<LatLng> points;
  final double height;
  const RouteMap({super.key, required this.points, this.height = 300});

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final MapController _controller = MapController();

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
    if (pts.isEmpty) {
      return Container(
        height: widget.height,
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
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _controller,
          options: MapOptions(initialCenter: pts.last, initialZoom: 16),
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
      ),
    );
  }
}
