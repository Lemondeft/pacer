import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/admin/admin_models.dart';
import 'package:pacer/src/admin/admin_repository.dart';
import 'package:pacer/src/admin/ui/admin_console_screen.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAdminGateway implements AdminGateway {
  AdminOverviewStats stats = const AdminOverviewStats(
    totalUsers: 12,
    userCount: 9,
    coachCount: 2,
    adminCount: 1,
    totalTeams: 3,
    totalActivities: 48,
    flaggedActivities: 1,
    verifiedActivities: 47,
    totalKm: 184.5,
  );

  final List<AdminUserEntry> users = [
    const AdminUserEntry(
      id: 'u-admin',
      nama: 'Super Admin',
      peran: 'admin',
      totalRuns: 5,
      totalKm: 22.0,
    ),
    const AdminUserEntry(
      id: 'u-runner',
      nama: 'Budi Runner',
      peran: 'user',
      totalRuns: 10,
      totalKm: 42.5,
    ),
  ];

  final List<CoachInvite> invites = [];
  final List<AdminFlaggedActivity> flagged = [
    const AdminFlaggedActivity(
      id: 'act-flag-1',
      userId: 'u-runner',
      userNama: 'Budi Runner',
      jenis: 'berjalan',
      durasiS: 900,
      jarakM: 4800,
      cadenceSpm: 0,
      suggestedSport: 'bersepeda',
      validationStatus: 'flagged_ride',
      validationScore: 0.9,
      validationReasons: ['OS_BIKE_CONFIRMED', 'ZERO_STEP_VELOCITY'],
    ),
  ];
  final List<AdminAuditEntry> audits = [];

  @override
  Future<AdminOverviewStats> getOverviewStats() async => stats;

  @override
  Future<List<AdminUserEntry>> listUsers({
    String? query,
    String? role,
    int limit = 50,
    int offset = 0,
  }) async {
    return users.where((u) {
      if (role != null && role.isNotEmpty && u.peran != role) return false;
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        return u.nama.toLowerCase().contains(q) ||
            u.id.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  @override
  Future<void> setUserRole({
    required String targetUserId,
    required String newRole,
    String? reason,
  }) async {
    final idx = users.indexWhere((u) => u.id == targetUserId);
    if (idx < 0) throw StateError('User not found');
    final cur = users[idx];
    users[idx] = AdminUserEntry(
      id: cur.id,
      nama: cur.nama,
      peran: newRole,
      region: cur.region,
      totalRuns: cur.totalRuns,
      totalKm: cur.totalKm,
    );
    audits.insert(
      0,
      AdminAuditEntry(
        id: 'audit-${audits.length + 1}',
        actorId: 'u-admin',
        actorNama: 'Super Admin',
        action: 'set_user_role',
        targetType: 'user',
        targetId: targetUserId,
        createdAt: DateTime.utc(2026, 11, 18),
      ),
    );
  }

  @override
  Future<CoachInvite> createCoachInvite({
    String? note,
    int maxUses = 1,
    int expiresDays = 14,
  }) async {
    final inv = CoachInvite(
      id: 'inv-${invites.length + 1}',
      code: 'COACH-1234ABCD',
      note: note,
      maxUses: maxUses,
    );
    invites.insert(0, inv);
    return inv;
  }

  @override
  Future<List<CoachInvite>> listCoachInvites() async => List.of(invites);

  @override
  Future<void> revokeCoachInvite(String inviteId) async {
    final idx = invites.indexWhere((i) => i.id == inviteId);
    if (idx >= 0) {
      final old = invites[idx];
      invites[idx] = CoachInvite(
        id: old.id,
        code: old.code,
        maxUses: old.maxUses,
        usesCount: old.usesCount,
        revokedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Future<String> claimCoachInvite(String code) async => 'coach';

  @override
  Future<List<AdminFlaggedActivity>> listFlaggedActivities({
    int limit = 50,
  }) async => List.of(flagged);

  @override
  Future<void> reviewActivity({
    required String aktivitasId,
    required String action,
    String? newJenis,
    String? reason,
  }) async {
    flagged.removeWhere((a) => a.id == aktivitasId);
    audits.insert(
      0,
      AdminAuditEntry(
        id: 'audit-${audits.length + 1}',
        actorId: 'u-admin',
        actorNama: 'Super Admin',
        action: 'review_activity_$action',
        targetType: 'aktivitas',
        targetId: aktivitasId,
        createdAt: DateTime.utc(2026, 11, 18),
      ),
    );
  }

  @override
  Future<List<AdminAuditEntry>> listAuditLogs({int limit = 50}) async =>
      List.of(audits);
}

void main() {
  group('AdminRepository & Validation', () {
    test('rejects invalid roles/actions locally and updates cached role on invite claim', () async {
      final store = MemoryLocalStore();
      await store.setLastUserId('u-local');
      await store.upsertProfile(
        const UserProfile(id: 'u-local', nama: 'Teacher', peran: 'user'),
      );
      final gw = _FakeAdminGateway();
      final repo = AdminRepository(gateway: gw, store: store);

      expect(
        () => repo.setUserRole(targetUserId: 'u-local', newRole: 'superuser'),
        throwsArgumentError,
      );
      expect(
        () => repo.reviewActivity(aktivitasId: 'a1', action: 'reclassify'),
        throwsArgumentError,
      );
      expect(() => repo.claimCoachInvite('   '), throwsArgumentError);

      final role = await repo.claimCoachInvite('COACH-1234ABCD');
      expect(role, 'coach');
      expect((await store.getProfile('u-local'))?.peran, 'coach');
    });
  });

  group('Super Admin Role-Gating & Console UI', () {
    testWidgets('AccountScreen shows Admin Console only for admin and omits retired Redeem Coach Code', (tester) async {
      SharedPreferences.setMockInitialValues({});
      PacerCache.instance.clear();
      langNotifier.value = Lang.en;
      final prevStore = LocalStore.instance;
      addTearDown(() {
        LocalStore.instance = prevStore;
        PacerCache.instance.clear();
      });

      // Regular user: sees neither Super Admin Console nor retired Redeem Coach Code
      final userStore = MemoryLocalStore();
      await userStore.setLastUserId('u-1');
      await userStore.upsertProfile(
        const UserProfile(id: 'u-1', nama: 'Athlete', peran: 'user'),
      );
      LocalStore.instance = userStore;

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: const AccountScreen(key: ValueKey('user')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.adminConsole), findsNothing);
      expect(find.text(S.redeemCoachCode), findsNothing);

      // Legacy global coach: also sees neither Super Admin Console nor Redeem Coach Code
      PacerCache.instance.clear();
      await userStore.upsertProfile(
        const UserProfile(id: 'u-1', nama: 'Coach', peran: 'coach'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: const AccountScreen(key: ValueKey('coach')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.adminConsole), findsNothing);
      expect(find.text(S.redeemCoachCode), findsNothing);

      // Admin: sees Super Admin Console
      PacerCache.instance.clear();
      await userStore.upsertProfile(
        const UserProfile(id: 'u-1', nama: 'Boss', peran: 'admin'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: const AccountScreen(key: ValueKey('admin')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.adminConsole), findsOneWidget);
      expect(find.text(S.redeemCoachCode), findsNothing);
    });

    testWidgets('AdminConsoleScreen supports KPI overview, user role promotion, flagged activity review, and audit logs', (tester) async {
      langNotifier.value = Lang.en;
      final store = MemoryLocalStore();
      final gw = _FakeAdminGateway();
      final repo = AdminRepository(gateway: gw, store: store);

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: AdminConsoleScreen(repository: repo, currentUserId: 'u-admin'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('12'), findsOneWidget); // total users
      expect(find.text('48'.toString()), findsNothing);

      // Switch to Users tab -> coach invite card is retired; role promotion works
      await tester.tap(find.text(S.adminUsersTab).first);
      await tester.pumpAndSettle();

      expect(find.text('Budi Runner'), findsOneWidget);
      expect(find.text(S.adminGenerateCodeCta), findsNothing);

      await tester.tap(find.text('USER').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('COACH').last);
      await tester.tap(find.text(S.adminSaveRoleCta));
      await tester.pumpAndSettle();

      expect(gw.users.firstWhere((u) => u.id == 'u-runner').peran, 'coach');

      // Switch to Flagged tab -> verify summary without GPS leak -> reclassify
      await tester.tap(find.text(S.adminFlaggedTab));
      await tester.pumpAndSettle();
      expect(find.textContaining('Budi Runner'), findsOneWidget);

      await tester.tap(
        find.text('${S.adminReclassifyCta}: ${S.sportName('bersepeda')}'),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.adminNoFlaggedRuns), findsOneWidget);

      // Switch to Audit tab -> confirm both actions logged
      await tester.tap(find.text(S.adminAuditTab));
      await tester.pumpAndSettle();
      expect(find.textContaining('set_user_role'), findsOneWidget);
      expect(find.textContaining('review_activity_reclassify'), findsOneWidget);
    });
  });
}
