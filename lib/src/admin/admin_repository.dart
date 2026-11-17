import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';

import 'admin_models.dart';

/// Gateway abstraction enabling unit/widget testing of [AdminRepository]
/// without requiring live Supabase network calls.
abstract class AdminGateway {
  Future<AdminOverviewStats> getOverviewStats();
  Future<List<AdminUserEntry>> listUsers({
    String? query,
    String? role,
    int limit = 50,
    int offset = 0,
  });
  Future<void> setUserRole({
    required String targetUserId,
    required String newRole,
    String? reason,
  });
  Future<CoachInvite> createCoachInvite({
    String? note,
    int maxUses = 1,
    int expiresDays = 14,
  });
  Future<List<CoachInvite>> listCoachInvites();
  Future<void> revokeCoachInvite(String inviteId);
  Future<String> claimCoachInvite(String code);
  Future<List<AdminFlaggedActivity>> listFlaggedActivities({int limit = 50});
  Future<void> reviewActivity({
    required String aktivitasId,
    required String action,
    String? newJenis,
    String? reason,
  });
  Future<List<AdminAuditEntry>> listAuditLogs({int limit = 50});
}

class _SupabaseAdminGateway implements AdminGateway {
  final SupabaseClient? _clientOverride;
  const _SupabaseAdminGateway([this._clientOverride]);

  SupabaseClient _requireClient() {
    final c = safeSupabaseClient(_clientOverride);
    if (c == null || c.auth.currentSession == null) {
      throw StateError('Authentication required.');
    }
    return c;
  }

  List<Map<String, dynamic>> _asRowList(dynamic raw) {
    if (raw is! List) return const [];
    return [for (final item in raw) Map<String, dynamic>.from(item as Map)];
  }

  @override
  Future<AdminOverviewStats> getOverviewStats() async {
    final c = _requireClient();
    final raw = await c.rpc('admin_get_overview_stats');
    final rows = _asRowList(raw);
    if (rows.isEmpty) return const AdminOverviewStats();
    return AdminOverviewStats.fromJson(rows.first);
  }

  @override
  Future<List<AdminUserEntry>> listUsers({
    String? query,
    String? role,
    int limit = 50,
    int offset = 0,
  }) async {
    final c = _requireClient();
    final raw = await c.rpc(
      'admin_list_users',
      params: {
        'p_query': query?.trim(),
        'p_role': role?.trim(),
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    return [for (final row in _asRowList(raw)) AdminUserEntry.fromJson(row)];
  }

  @override
  Future<void> setUserRole({
    required String targetUserId,
    required String newRole,
    String? reason,
  }) async {
    final c = _requireClient();
    await c.rpc(
      'admin_set_user_role',
      params: {
        'p_target_user_id': targetUserId,
        'p_new_role': newRole,
        'p_reason': reason?.trim(),
      },
    );
  }

  @override
  Future<CoachInvite> createCoachInvite({
    String? note,
    int maxUses = 1,
    int expiresDays = 14,
  }) async {
    final c = _requireClient();
    final raw = await c.rpc(
      'admin_create_coach_invite',
      params: {
        'p_note': note?.trim(),
        'p_max_uses': maxUses,
        'p_expires_days': expiresDays,
      },
    );
    return CoachInvite.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<List<CoachInvite>> listCoachInvites() async {
    final c = _requireClient();
    final raw = await c.rpc('admin_list_coach_invites');
    return [for (final row in _asRowList(raw)) CoachInvite.fromJson(row)];
  }

  @override
  Future<void> revokeCoachInvite(String inviteId) async {
    final c = _requireClient();
    await c.rpc(
      'admin_revoke_coach_invite',
      params: {'p_invite_id': inviteId},
    );
  }

  @override
  Future<String> claimCoachInvite(String code) async {
    final c = _requireClient();
    final raw = await c.rpc(
      'claim_coach_invite',
      params: {'p_code': code.trim()},
    );
    return (raw as String?) ?? 'coach';
  }

  @override
  Future<List<AdminFlaggedActivity>> listFlaggedActivities({
    int limit = 50,
  }) async {
    final c = _requireClient();
    final raw = await c.rpc(
      'admin_list_flagged_activities',
      params: {'p_limit': limit},
    );
    return [
      for (final row in _asRowList(raw)) AdminFlaggedActivity.fromJson(row),
    ];
  }

  @override
  Future<void> reviewActivity({
    required String aktivitasId,
    required String action,
    String? newJenis,
    String? reason,
  }) async {
    final c = _requireClient();
    await c.rpc(
      'admin_review_activity',
      params: {
        'p_aktivitas_id': aktivitasId,
        'p_action': action,
        'p_new_jenis': newJenis,
        'p_reason': reason?.trim(),
      },
    );
  }

  @override
  Future<List<AdminAuditEntry>> listAuditLogs({int limit = 50}) async {
    final c = _requireClient();
    final raw = await c.rpc(
      'admin_list_audit_logs',
      params: {'p_limit': limit},
    );
    return [for (final row in _asRowList(raw)) AdminAuditEntry.fromJson(row)];
  }
}

/// Repository exposing Super Admin RPCs and Coach Invite code redemption.
/// Always delegates privilege validation to Postgres `is_admin()` RPCs using
/// parameterized inputs (no dynamic SQL).
class AdminRepository {
  static const allowedRoles = <String>['user', 'coach', 'admin'];
  static const allowedReviewActions = <String>[
    'verify',
    'reclassify',
    'exclude',
  ];

  final AdminGateway _gateway;
  final LocalStore _store;

  AdminRepository({
    AdminGateway? gateway,
    SupabaseClient? client,
    LocalStore? store,
  }) : _gateway = gateway ?? _SupabaseAdminGateway(client),
       _store = store ?? LocalStore.instance;

  Future<AdminOverviewStats> getOverviewStats() => _gateway.getOverviewStats();

  Future<List<AdminUserEntry>> listUsers({
    String? query,
    String? role,
    int limit = 50,
    int offset = 0,
  }) {
    if (role != null && role.isNotEmpty && !allowedRoles.contains(role)) {
      throw ArgumentError.value(role, 'role', 'must be one of $allowedRoles');
    }
    return _gateway.listUsers(
      query: query,
      role: role,
      limit: limit,
      offset: offset,
    );
  }

  Future<void> setUserRole({
    required String targetUserId,
    required String newRole,
    String? reason,
  }) async {
    if (!allowedRoles.contains(newRole)) {
      throw ArgumentError.value(
        newRole,
        'newRole',
        'must be one of $allowedRoles',
      );
    }
    await _gateway.setUserRole(
      targetUserId: targetUserId,
      newRole: newRole,
      reason: reason,
    );
    PacerCache.instance.invalidatePrefix('profile_');
  }

  Future<CoachInvite> createCoachInvite({
    String? note,
    int maxUses = 1,
    int expiresDays = 14,
  }) {
    if (maxUses < 1) {
      throw ArgumentError.value(maxUses, 'maxUses', 'must be >= 1');
    }
    return _gateway.createCoachInvite(
      note: note,
      maxUses: maxUses,
      expiresDays: expiresDays,
    );
  }

  Future<List<CoachInvite>> listCoachInvites() => _gateway.listCoachInvites();

  Future<void> revokeCoachInvite(String inviteId) =>
      _gateway.revokeCoachInvite(inviteId);

  /// Redeems a Coach Invite Code cleanly using parameterized RPC and refreshes
  /// the caller's cached profile role locally.
  Future<String> claimCoachInvite(String code) async {
    final cleaned = code.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError.value(code, 'code', 'Invite code cannot be empty');
    }
    final nextRole = await _gateway.claimCoachInvite(cleaned);
    final uid = await _store.getLastUserId();
    if (uid != null) {
      final cached = await _store.getProfile(uid);
      if (cached != null) {
        await _store.upsertProfile(
          UserProfile(
            id: cached.id,
            nama: cached.nama,
            peran: nextRole,
            lahir: cached.lahir,
            jenisKelamin: cached.jenisKelamin,
            tinggiCm: cached.tinggiCm,
            beratKg: cached.beratKg,
            region: cached.region,
          ),
        );
      }
      PacerCache.instance.invalidate('profile_$uid');
    }
    return nextRole;
  }

  Future<List<AdminFlaggedActivity>> listFlaggedActivities({int limit = 50}) =>
      _gateway.listFlaggedActivities(limit: limit);

  Future<void> reviewActivity({
    required String aktivitasId,
    required String action,
    String? newJenis,
    String? reason,
  }) {
    if (!allowedReviewActions.contains(action)) {
      throw ArgumentError.value(
        action,
        'action',
        'must be one of $allowedReviewActions',
      );
    }
    if (action == 'reclassify' &&
        (newJenis == null || !aktivitasJenis.contains(newJenis))) {
      throw ArgumentError.value(
        newJenis,
        'newJenis',
        'must be one of $aktivitasJenis',
      );
    }
    return _gateway.reviewActivity(
      aktivitasId: aktivitasId,
      action: action,
      newJenis: newJenis,
      reason: reason,
    );
  }

  Future<List<AdminAuditEntry>> listAuditLogs({int limit = 50}) =>
      _gateway.listAuditLogs(limit: limit);
}
