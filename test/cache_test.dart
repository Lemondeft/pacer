import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/cache/pacer_cache.dart';

void main() {
  setUp(() {
    PacerCache.instance.clear();
  });

  test('PacerCache get/set with expiration', () {
    final cache = PacerCache.instance;
    expect(cache.get<String>('key1'), isNull);

    cache.set('key1', 'hello', ttl: const Duration(seconds: 10));
    expect(cache.get<String>('key1'), 'hello');

    // Expired entry
    cache.set('key2', 'expired', ttl: const Duration(milliseconds: -1));
    expect(cache.get<String>('key2'), isNull);
  });

  test('PacerCache invalidate and invalidatePrefix', () {
    final cache = PacerCache.instance;
    cache.set('team_1', 'Team Alpha');
    cache.set('team_2', 'Team Beta');
    cache.set('other', 'Other data');

    cache.invalidate('team_1');
    expect(cache.get<String>('team_1'), isNull);
    expect(cache.get<String>('team_2'), 'Team Beta');
    expect(cache.get<String>('other'), 'Other data');

    cache.invalidatePrefix('team_');
    expect(cache.get<String>('team_2'), isNull);
    expect(cache.get<String>('other'), 'Other data');

    cache.clear();
    expect(cache.get<String>('other'), isNull);
  });
}
