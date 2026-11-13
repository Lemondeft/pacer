import 'package:flutter_map/flutter_map.dart';

/// Web fallback: relies on browser HTTP tile caching without `dart:io`.
Future<TileProvider?> getCachedTileProvider() async => null;
