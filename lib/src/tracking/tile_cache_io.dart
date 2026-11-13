import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<TileProvider?>? _cachedProviderFuture;

/// Returns a disk-backed [CachedTileProvider] for viewed OSM tiles, or `null`
/// cleanly in environments without `path_provider` (e.g. widget tests).
Future<TileProvider?> getCachedTileProvider() {
  return _cachedProviderFuture ??= _createProvider();
}

Future<TileProvider?> _createProvider() async {
  try {
    final base = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(base.path, 'pacer_osm_tiles'));
    await cacheDir.create(recursive: true);
    return CachedTileProvider(
      store: FileCacheStore(cacheDir.path),
      maxStale: const Duration(days: 30),
      cachePolicy: CachePolicy.forceCache,
      hitCacheOnNetworkFailure: true,
    );
  } catch (_) {
    return null;
  }
}
