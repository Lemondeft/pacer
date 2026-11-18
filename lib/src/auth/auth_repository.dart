import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/auth/profile_input.dart' show validateUsername;
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/notifications/notification_repository.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';

/// Thrown when sign-up succeeds but email confirmation is pending:
/// there is a user but no session, so the profile row cannot be RLS-inserted.
class EmailConfirmationRequired implements Exception {
  const EmailConfirmationRequired();
}

/// Offline-first auth & profile repository (DFD process 1.0 LOGIN/KELOLA USER).
class AuthRepository {
  /// Increments on sign-in, sign-up, sign-out, and demo entry so root UI shells
  /// rebuild with clean per-session state.
  static final ValueNotifier<int> sessionEpoch = ValueNotifier<int>(0);

  /// Increments strictly on explicit sign-out so mounted auth flows unwind
  /// pushed screens back to the welcome gate without stale BuildContexts.
  static final ValueNotifier<int> signOutEpoch = ValueNotifier<int>(0);

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
    final cleanNama = nama.trim();
    final nameErr = validateUsername(cleanNama);
    if (nameErr != null) {
      throw ArgumentError.value(nama, 'nama', nameErr.name);
    }
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    PacerCache.instance.clear();
    NotificationRepository.resetSession();
    _sync.resetSession();
    PacerDummyData.resetDemoTeams();
    await _store.wipeUserData(demoSandboxUserId);
    final res = await c.auth.signUp(
      email: email,
      password: password,
      data: {'nama': cleanNama, 'username': cleanNama},
    );
    final user = res.user;
    if (user == null) {
      throw StateError('Sign-up succeeded without a user session.');
    }
    if (res.session == null) {
      throw const EmailConfirmationRequired();
    }
    await c.from('users').insert(buildUserRow(id: user.id, nama: cleanNama));
    await _store.setLastUserId(user.id);
    final profile = await getProfile(forceRefresh: true);
    final resolved = profile ?? UserProfile(id: user.id, nama: cleanNama);
    await _store.upsertProfile(resolved, email: user.email);
    await _sync.refreshCounts(userId: user.id);
    sessionEpoch.value++;
    return resolved;
  }

  /// Email/password sign-in. Self-heals a missing profile row and warms local cache.
  Future<void> signIn({required String email, required String password}) async {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    PacerCache.instance.clear();
    NotificationRepository.resetSession();
    _sync.resetSession();
    PacerDummyData.resetDemoTeams();
    await _store.wipeUserData(demoSandboxUserId);
    await c.auth.signInWithPassword(email: email, password: password);
    final id = currentUserId();
    if (id == null) return;
    await _store.setLastUserId(id);
    final meta = c.auth.currentUser?.userMetadata;
    final metaNama = ((meta?['nama'] ?? meta?['username']) as String? ?? '')
        .trim();
    var profile = await getProfile(forceRefresh: true);
    if (profile == null) {
      try {
        await c.from('users').insert(buildUserRow(id: id, nama: metaNama));
        profile = UserProfile(id: id, nama: metaNama);
      } catch (_) {}
    } else if ((profile.nama ?? '').trim().isEmpty && metaNama.isNotEmpty) {
      try {
        await c.from('users').update({'nama': metaNama}).eq('id', id);
        profile = UserProfile(
          id: profile.id,
          nama: metaNama,
          peran: profile.peran,
          lahir: profile.lahir,
          jenisKelamin: profile.jenisKelamin,
          tinggiCm: profile.tinggiCm,
          beratKg: profile.beratKg,
          region: profile.region,
        );
      } catch (_) {}
    }
    if (profile != null) {
      await _store.upsertProfile(
        profile,
        email: c.auth.currentUser?.email ?? email,
      );
    }
    await _sync.refreshCounts(userId: id);
    unawaited(_sync.triggerSync(userId: id));
    sessionEpoch.value++;
  }

  /// Signs into an actual ephemeral Demo Account seeded in [LocalStore].
  /// All edits/workouts run through real SQLite tables and are wiped on logout.
  static Future<void> prepareDemoSession({
    LocalStore? store,
    SyncEngine? sync,
    String language = 'id',
  }) async {
    final targetStore = store ?? LocalStore.instance;
    PacerCache.instance.clear();
    NotificationRepository.resetSession();
    (sync ?? SyncEngine.instance).resetSession();
    await PacerDummyData.seedIntoStore(targetStore, language: language);
    final notifs = await targetStore.getNotifications(demoSandboxUserId);
    NotificationRepository.unreadCountNotifier.value = notifs
        .where((n) => !n.isRead)
        .length;
    NotificationRepository.revisionNotifier.value++;
    sessionEpoch.value++;
  }

  /// Number of local mutations queued in the outbox for the current user.
  Future<int> pendingSyncCount() async {
    final id = await resolveUserId();
    if (id == null || isDemoUserId(id)) return 0;
    return _store.getPendingOutboxCount(id);
  }

  Future<void> signOut() async {
    PacerCache.instance.clear();
    NotificationRepository.resetSession();
    _sync.resetSession();
    PacerDummyData.resetDemoTeams();
    await _store.wipeUserData(demoSandboxUserId);
    await _store.setLastUserId(null);
    final c = _client;
    if (c != null) {
      try {
        await c.auth.signOut().timeout(const Duration(seconds: 3));
      } catch (_) {
        // GoTrue clears the local session before network revoke; offline or
        // timeout failures must not stall local logout.
      }
    }
    sessionEpoch.value++;
    signOutEpoch.value++;
  }

  /// Permanently deletes the signed-in user account via the `delete-account`
  /// Edge Function, wipes local SQLite data, and signs out.
  Future<void> deleteAccount() async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) throw StateError('Not signed in');
    final res = await c.functions.invoke('delete-account');
    if (res.status < 200 || res.status >= 300) {
      throw StateError('Failed to delete account (${res.status})');
    }
    await _store.wipeUserData(uid);
    await signOut();
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
    if (!isDemoUserId(id)) {
      await _sync.refreshCounts(userId: id);
      if (ConnectivityService.instance.value && _client != null) {
        unawaited(_sync.triggerSync(userId: id));
      }
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
    if (!isDemoUserId(id)) {
      await _sync.refreshCounts(userId: id);
      unawaited(_sync.triggerSync(userId: id));
    }
  }
}
