import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:pacer/src/ui/app_strings.dart';

/// Distraction-free route view powered by OpenFreeMap vector tiles (no API key):
/// renders OpenFreeMap Positron in light mode and Fiord (filtered to drop the
/// light `landuse_residential` fill) in dark mode with labels/POIs/legends
/// disabled by default ([showLabels] == false), overlaid with a high-contrast
/// lime route polyline, start/finish pins, and built-in offline disk caching.
///
/// [minimal] swaps tiles for an offline grid canvas + fitted route;
/// [fitBounds] frames the full recorded route rather than only following the
/// live cursor; [showControls] overlays recenter + view toggle.
class RouteMap extends StatefulWidget {
  static const String lightStyleUri = 'https://tiles.openfreemap.org/styles/positron';
  static const String darkStyleUri = 'https://tiles.openfreemap.org/styles/fiord';

  final List<LatLng> points;
  final double height;
  final bool minimal;
  final bool fitBounds;
  final bool showControls;
  final bool showLabels;
  final bool showEmptyChip;
  final EdgeInsets controlsPadding;
  final LatLng? fallbackCenter;
  final String? emptyLabel;
  final double borderRadius;

  /// Optional test hook to inject a pre-built/fake style loader without network.
  @visibleForTesting
  final Future<vt.Style?> Function(String uri)? styleLoader;

  /// Removes `landuse_residential` from OpenFreeMap Fiord so beige low-zoom
  /// polygons do not obscure the clean slate-blue dark palette.
  @visibleForTesting
  static vt.Style sanitizeStyle(vt.Style style, String uri) {
    if (uri != darkStyleUri) return style;
    final filtered = style.theme.layers
        .where((l) => l.id != 'landuse_residential')
        .toList(growable: false);
    if (filtered.length == style.theme.layers.length) return style;
    return vt.Style(
      theme: vt.Theme(id: '${style.theme.id}-clean', layers: filtered),
      providers: style.providers,
      rasterSources: style.rasterSources,
      sprites: style.sprites,
      glyphs: style.glyphs,
      center: style.center,
      zoom: style.zoom,
      name: style.name,
      attributions: style.attributions,
    );
  }

  const RouteMap({
    super.key,
    required this.points,
    this.height = 300,
    this.minimal = false,
    this.fitBounds = false,
    this.showControls = false,
    this.showLabels = false,
    this.showEmptyChip = true,
    this.controlsPadding = const EdgeInsets.all(10),
    this.fallbackCenter,
    this.emptyLabel,
    this.borderRadius = 12,
    this.styleLoader,
  });

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final MapController _controller = MapController();
  late bool _minimal = widget.minimal;
  LatLng? _resolvedFallback;
  bool _mapReady = false;

  vt.Style? _style;
  String? _targetStyleUri;
  String? _loadedStyleUri;
  int _styleGeneration = 0;

  static const LatLng _fallback = LatLng(-6.2296, 106.8294);
  static const Color _route = Color(0xFFBAFF29);

  LatLng get _effectiveFallback =>
      widget.fallbackCenter ?? _resolvedFallback ?? _fallback;

  bool _hasAreaSpan(List<LatLng> pts) {
    if (pts.length < 2) return false;
    var minLat = pts.first.latitude;
    var maxLat = pts.first.latitude;
    var minLng = pts.first.longitude;
    var maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return (maxLat - minLat).abs() > 1e-5 || (maxLng - minLng).abs() > 1e-5;
  }

  void _syncCamera() {
    if (!_mapReady || _minimal) return;
    final pts = widget.points;
    try {
      if (widget.fitBounds && _hasAreaSpan(pts)) {
        _controller.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pts),
            padding: const EdgeInsets.all(36),
            maxZoom: 17.5,
          ),
        );
      } else if (pts.isNotEmpty) {
        _controller.move(pts.last, widget.fitBounds ? 16.5 : _controller.camera.zoom);
      } else {
        _controller.move(_effectiveFallback, 16);
      }
    } catch (_) {
      // Ignore if controller detached mid-dispose.
    }
  }

  void _scheduleStyleDispose(vt.Style? style) {
    if (style == null) return;
    Future<void>.microtask(style.dispose);
  }

  void _ensureStyleLoaded() {
    final uri = _targetStyleUri;
    if (_minimal || uri == null || uri == _loadedStyleUri) return;
    _loadedStyleUri = uri;
    final gen = ++_styleGeneration;
    _loadStyle(uri, gen);
  }

  Future<void> _loadStyle(String uri, int gen) async {
    try {
      final style = widget.styleLoader != null
          ? await widget.styleLoader!(uri)
          : await vt.StyleReader(
              uri: uri,
              headers: const {'User-Agent': 'com.example.pacer'},
              cache: true,
              refreshAfter: const Duration(hours: 12),
            ).read();
      if (!mounted || gen != _styleGeneration) {
        _scheduleStyleDispose(style);
        return;
      }
      if (style == null) return;
      final sanitized = RouteMap.sanitizeStyle(style, uri);
      final prev = _style;
      setState(() => _style = sanitized);
      _scheduleStyleDispose(prev);
    } catch (_) {
      // Cold offline start or headless test environment: keep themed grid behind route.
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.points.isEmpty && widget.fallbackCenter == null) {
      _resolveDeviceAnchor();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nextUri = isDark ? RouteMap.darkStyleUri : RouteMap.lightStyleUri;
    if (_targetStyleUri != nextUri) {
      _targetStyleUri = nextUri;
      final prev = _style;
      if (prev != null) {
        _style = null;
        _scheduleStyleDispose(prev);
      }
      _ensureStyleLoaded();
    }
  }

  Future<void> _resolveDeviceAnchor() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (!mounted || pos == null) return;
      final anchor = LatLng(pos.latitude, pos.longitude);
      setState(() => _resolvedFallback = anchor);
      if (_mapReady && widget.points.isEmpty && !_minimal) {
        _controller.move(anchor, 16);
      }
    } catch (_) {
      // Optional best-effort anchor when location plugin is unavailable.
    }
  }

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minimal != widget.minimal) {
      _minimal = widget.minimal;
      _ensureStyleLoaded();
    }
    final pointsChanged =
        widget.points.length != oldWidget.points.length ||
        (widget.points.isNotEmpty &&
            oldWidget.points.isNotEmpty &&
            widget.points.last != oldWidget.points.last);
    final anchorChanged = widget.fallbackCenter != oldWidget.fallbackCenter;
    final fitChanged = widget.fitBounds != oldWidget.fitBounds;
    if (pointsChanged || anchorChanged || fitChanged) {
      _syncCamera();
    }
  }

  @override
  void dispose() {
    _styleGeneration++;
    final activeStyle = _style;
    _style = null;
    _controller.dispose();
    super.dispose();
    _scheduleStyleDispose(activeStyle);
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    final radius = BorderRadius.circular(widget.borderRadius);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridBg = isDark ? const Color(0xFF283349) : const Color(0xFFF1F5F9);
    final gridLine = isDark ? const Color(0xFF364563) : const Color(0xFFE2E8F0);
    final casingColor =
        isDark ? const Color(0xE6020617) : const Color(0xCC0F172A);

    Widget controlsOverlay() {
      if (!widget.showControls) return const SizedBox.shrink();
      return Positioned(
        top: widget.controlsPadding.top,
        right: widget.controlsPadding.right,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MapOverlayButton(
              icon: _minimal ? Icons.map_outlined : Icons.grid_on_rounded,
              tooltip: S.toggleMapStyle,
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _minimal = !_minimal);
                _ensureStyleLoaded();
              },
            ),
            if (!_minimal) ...[
              const SizedBox(width: 8),
              _MapOverlayButton(
                icon: Icons.center_focus_strong_rounded,
                tooltip: S.recenterRoute,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _syncCamera();
                },
              ),
            ],
          ],
        ),
      );
    }

    // Minimal mode: offline canvas (grid + fitted route), no tiles.
    if (_minimal) {
      return SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Container(
                color: gridBg,
                child: CustomPaint(
                  painter: _MinimalRoutePainter(pts, gridColor: gridLine),
                  child: const SizedBox.expand(),
                ),
              ),
              if (pts.isEmpty && widget.showEmptyChip)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: _EmptyRouteChip(
                      label: widget.emptyLabel ?? S.noGpsPoints,
                    ),
                  ),
                ),
              controlsOverlay(),
            ],
          ),
        ),
      );
    }

    final useFitBounds = widget.fitBounds && _hasAreaSpan(pts);
    final style = _style;
    final attributionText = (style != null && style.attributions.isNotEmpty)
        ? style.attributions.map((a) => a.text).join(' · ')
        : '© OpenFreeMap · © OpenStreetMap contributors';

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Themed grid paint behind vector tiles: cold offline or loading degrades gracefully.
            Positioned.fill(
              child: Container(
                color: gridBg,
                child: CustomPaint(painter: _GridPainter(color: gridLine)),
              ),
            ),
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: pts.isEmpty ? _effectiveFallback : pts.last,
                initialZoom: widget.fitBounds ? 16.5 : 16,
                initialCameraFit: useFitBounds
                    ? CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(pts),
                        padding: const EdgeInsets.all(36),
                        maxZoom: 17.5,
                      )
                    : null,
                onMapReady: () {
                  _mapReady = true;
                  if (useFitBounds || pts.isEmpty) {
                    _syncCamera();
                  }
                },
                // Transparent so the themed grid shows cleanly while loading or offline.
                backgroundColor: Colors.transparent,
              ),
              children: [
                if (style != null)
                  vt.VectorTileLayer(
                    key: ValueKey(_loadedStyleUri),
                    theme: style.theme,
                    tileProviders: style.providers,
                    rasterSources: style.rasterSources,
                    sprites: style.sprites,
                    glyphs: widget.showLabels ? style.glyphs : null,
                    showLabels: widget.showLabels,
                    diskCacheMaximumSizeInBytes: 50 * 1024 * 1024,
                    diskCacheTtl: const Duration(days: 14),
                  ),
                if (pts.length > 1)
                  PolylineLayer(
                    polylines: [
                      // High-contrast casing ensures legibility on both Positron and Dark themes.
                      Polyline(
                        points: pts,
                        strokeWidth: 7.5,
                        color: casingColor,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      Polyline(
                        points: pts,
                        strokeWidth: 4.5,
                        color: _route,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),
                if (pts.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      if (widget.fitBounds && pts.length > 1)
                        Marker(
                          point: pts.first,
                          width: 22,
                          height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF0F172A),
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Marker(
                        point: pts.last,
                        width: 38,
                        height: 38,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _route,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.fitBounds
                                ? Icons.flag_rounded
                                : Icons.directions_run,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            // Attribution required by OpenFreeMap / OpenMapTiles / OSM terms.
            Positioned(
              right: 8,
              bottom: 8,
              child: IgnorePointer(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xD90F172A)
                          : Colors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      attributionText,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            // Empty route: non-intrusive status chip over live OSM geography.
            if (pts.isEmpty && widget.showEmptyChip)
              Positioned(
                left: 12,
                bottom: 8,
                child: _EmptyRouteChip(
                  label: widget.emptyLabel ?? S.noGpsPoints,
                ),
              ),
            controlsOverlay(),
          ],
        ),
      ),
    );
  }
}

class _EmptyRouteChip extends StatelessWidget {
  final String label;
  const _EmptyRouteChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_searching,
            size: 13,
            color: Color(0xFFBAFF29),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MapOverlayButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _MapOverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD90F172A),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }
}

/// Subtle grid fallback painted behind vector tiles for offline/loading states.
class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter({this.color = const Color(0xFFE2E8F0)});

  static void paintGrid(Canvas canvas, Size size, Color color) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  void paint(Canvas canvas, Size size) => paintGrid(canvas, size, color);

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Fitted route shape for minimal mode: uniform scale + center so the
/// route never clips, regardless of aspect.
class _MinimalRoutePainter extends CustomPainter {
  final List<LatLng> points;
  final Color gridColor;
  static const Color _route = Color(0xFFBAFF29);

  _MinimalRoutePainter(
    this.points, {
    this.gridColor = const Color(0xFF364563),
  });

  @override
  void paint(Canvas canvas, Size size) {
    _GridPainter.paintGrid(canvas, size, gridColor);
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
      old.points != points || old.gridColor != gridColor;
}
