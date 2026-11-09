/// Lightweight in-memory Time-To-Live (TTL) cache.
/// Prevents hammering Supabase when navigating back and forth between screens,
/// while supporting explicit cache invalidation when data mutations occur.
class PacerCache {
  PacerCache._();
  static final PacerCache instance = PacerCache._();

  final Map<String, _CacheEntry> _store = {};

  /// Retrieves a cached value of type [T] if it exists and has not expired.
  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  /// Stores a [value] in memory with the given [ttl] (default: 3 minutes).
  void set<T>(
    String key,
    T value, {
    Duration ttl = const Duration(minutes: 3),
  }) {
    _store[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Removes a single cache entry.
  void invalidate(String key) {
    _store.remove(key);
  }

  /// Removes all cache entries matching the given [prefix].
  void invalidatePrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// Clears the entire in-memory cache (e.g. on logout or test teardown).
  void clear() {
    _store.clear();
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  _CacheEntry({required this.value, required this.expiresAt});
}
