import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OpenStreetMap route view (no API key). Shows [points] as a lime polyline
/// with a position marker on the latest fix; the camera follows new fixes.
/// Empty points center on Jakarta (GBK area) as a neutral default.
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
  Widget build(BuildContext context) {
    final pts = widget.points;
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
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
      ),
    );
  }
}
