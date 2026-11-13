import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';

/// Thrown when sign-up succeeds but email confirmation is pending:
/// there is a user but no session, so the profile row cannot be RLS-inserted.
class EmailConfirmationRequired implements Exception {
  const EmailConfirmationRequired();
}

/// Offline-first auth & profile repository (DFD process 1.0 LOGIN/KELOLA USER).
class AuthRepository {
  final SupabaseClient? _clientOverride;
  final LocalStore? _storeOverride;
  final SyncEngine? _syncOverride;

  AuthRepository({
    SupabaseClient? client,
    LocalStore? store,
    SyncEngine? sync,
  }) : _clientOverride = client,
       _storeOverride = store,
       _syncOverride = sync;

  SupabaseClient? get _client => safeSupabaseClient(_clientOverride);
  LocalStore get _store => _storeOverride ?? LocalStore.instance;
  SyncEngine get _sync => _syncOverride ?? SyncEngine.instance;

  /// Registers via Supabase Auth, then creates the public.users profile row.
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String nama,
  }) async {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final res = await c.auth.signUp(email: email, password: password);
    final user = res.user;
    if (user == null) {
      throw StateError('Sign-up succeeded without a user session.');
    }
    if (res.session == null) {
      throw const EmailConfirmationRequired();
    }
    await c.from('users').insert(buildUserRow(id: user.id, nama: nama));
    await _store.setLastUserId(user.id);
    final profile = await getProfile(forceRefresh: true);
    final resolved = profile ?? UserProfile(id: user.id, nama: nama);
    await _store.upsertProfile(resolved, email: user.email);
    await _sync.refreshCounts(userId: user.id);
    return resolved;
  }

  /// Email/password sign-in. Self-heals a missing profile row and warms local cache.
  Future<void> signIn({required String email, required String password}) async {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    await c.auth.signInWithPassword(email: email, password: password);
    final id = currentUserId();
    if (id == null) return;
    await _store.setLastUserId(id);
    var profile = await getProfile(forceRefresh: true);
    if (profile == null) {
      try {
        await c.from('users').insert(buildUserRow(id: id, nama: ''));
        profile = UserProfile(id: id, nama: '');
      } catch (_) {}
    }
    if (profile != null) {
      await _store.upsertProfile(
        profile,
        email: c.auth.currentUser?.email ?? email,
      );
    }
    unawaited(_sync.triggerSync(userId: id));
  }

  /// Number of local mutations queued in the outbox for the current user.
  Future<int> pendingSyncCount() async {
    final id = await resolveUserId();
    if (id == null) return 0;
    return _store.getPendingOutboxCount(id);
  }

  Future<void> signOut() async {
    PacerCache.instance.clear();
    await _store.setLastUserId(null);
    try {
      await _client?.auth.signOut();
    } catch (_) {
      // Allow signing out cleanly while offline without failing the UX.
    }
    await _sync.refreshCounts(userId: null);
  }

  String? currentUserId() => _client?.auth.currentUser?.id;

  Future<String?> resolveUserId() async =>
      currentUserId() ?? await _store.getLastUserId();

  Future<String?> getSavedEmail() async {
    final liveEmail = _client?.auth.currentUser?.email;
    if (liveEmail != null && liveEmail.isNotEmpty) return liveEmail;
    final id = await resolveUserId();
    if (id == null) return null;
    return _store.getEmail(id);
  }

  /// Reads the caller's profile row offline-first via SQLite SSOT + SWR.
  Future<UserProfile?> getProfile({bool forceRefresh = false}) async {
    final id = await resolveUserId();
    if (id == null) return null;

    final c = _client;
    final cacheKey = 'auth_profile_$id';
    if (!forceRefresh) {
      final mem = PacerCache.instance.get<UserProfile>(cacheKey);
      if (mem != null) return mem;
    }

    final profile = await offlineRead<UserProfile?>(
      store: _store,
      syncKey: 'profile_$id',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 5),
      readLocal: () => _store.getProfile(id),
      fetchRemote: () async {
        final row = await c!.from('users').select().eq('id', id).maybeSingle();
        if (row == null) return null;
        final map = Map<String, dynamic>.from(row);
        final prof = UserProfile.fromJson(map);
        await _store.upsertProfile(
          prof,
          language: map['language'] as String?,
          email: c.auth.currentUser?.email,
        );
        return prof;
      },
      writeLocal: (remote) async {
        if (remote != null) {
          await _store.upsertProfile(
            remote,
            email: c?.auth.currentUser?.email,
          );
        }
      },
      isEmpty: (p) => p == null,
    );

    if (profile != null) {
      await _store.setLastUserId(id);
      PacerCache.instance.set(
        cacheKey,
        profile,
        ttl: const Duration(minutes: 5),
      );
    }
    return profile;
  }

  /// Reads the saved backend language code offline-first (`'id'` / `'en'`).
  Future<String?> getLanguage({bool forceRefresh = false}) async {
    final id = await resolveUserId();
    if (id == null) return null;
    final c = _client;
    return offlineRead<String?>(
      store: _store,
      syncKey: 'language_$id',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 5),
      readLocal: () => _store.getLanguage(id),
      fetchRemote: () async {
        final row = await c!
            .from('users')
            .select('language')
            .eq('id', id)
            .maybeSingle();
        return row?['language'] as String?;
      },
      writeLocal: (val) async {
        if (val != null) {
          final prof = await _store.getProfile(id) ?? UserProfile(id: id);
          await _store.upsertProfile(prof, language: val);
        }
      },
      isEmpty: (v) => v == null,
    );
  }

  /// Updates language locally immediately and enqueues outbox sync.
  Future<void> updateLanguage(String langCode) async {
    final id = await resolveUserId();
    if (id == null) return;
    await _store.queueLanguageUpdate(id, langCode);
    await _sync.refreshCounts(userId: id);
    if (ConnectivityService.instance.value && _client != null) {
      unawaited(_sync.triggerSync(userId: id));
    }
  }

  /// Updates the caller's own profile locally first, then queues backend sync.
  Future<void> updateProfile({
    String? nama,
    DateTime? lahir,
    String? jenisKelamin,
    double? tinggiCm,
    double? beratKg,
    String? region,
    Set<String> clear = const {},
  }) async {
    final id = await resolveUserId();
    if (id == null) {
      throw StateError('No signed-in user.');
    }
    final payload = <String, dynamic>{};
    if (nama != null) payload['nama'] = nama;
    if (lahir != null) {
      final v = lahir;
      payload['lahir'] =
          '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    }
    if (jenisKelamin != null) payload['jenis_kelamin'] = jenisKelamin;
    if (tinggiCm != null) payload['tinggi_cm'] = tinggiCm;
    if (beratKg != null) payload['berat_kg'] = beratKg;
    if (region != null) payload['region'] = region;
    const clearable = {
      'lahir',
      'jenis_kelamin',
      'tinggi_cm',
      'berat_kg',
      'region',
    };
    for (final c in clear) {
      if (clearable.contains(c)) payload[c] = null;
    }
    if (payload.isEmpty) {
      throw ArgumentError('updateProfile needs at least one field to change.');
    }

    await _store.queueProfileUpdate(id, payload);
    PacerCache.instance.invalidate('auth_profile_$id');
    if (region != null || clear.contains('region')) {
      PacerCache.instance.invalidatePrefix('leaderboard_');
    }
    await _sync.refreshCounts(userId: id);
    unawaited(_sync.triggerSync(userId: id));
  }
}
