import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/local/sqlite_local_store.dart';
import 'package:pacer/src/teams/team_model.dart';
import 'package:pacer/src/teams/team_repository.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/coach_board.dart';
import 'package:pacer/src/ui/more_screens.dart';

void main() {
  sqfliteFfiInit();

  group('Team expiration & team-scoped role helpers', () {
    test('Team parses expires_at and evaluates pending vs expired vs graduated', () {
      final future = DateTime.now().toUtc().add(const Duration(days: 5));
      final past = DateTime.now().toUtc().subtract(const Duration(minutes: 1));

      final pending = Team.fromJson({
        'id': 't-pending',
        'nama': 'Sunday Track',
        'is_private': true,
        'member_count': 1,
        'expires_at': future.toIso8601String(),
      });
      expect(pending.isPendingActivation, isTrue);
      expect(pending.isExpired, isFalse);
      expect(pending.toJson()['expires_at'], future.toIso8601String());

      final graduated = pending.copyWith(memberCount: 2, clearExpiresAt: true);
      expect(graduated.expiresAt, isNull);
      expect(graduated.isPendingActivation, isFalse);
      expect(graduated.isExpired, isFalse);

      final expired = Team(
        id: 't-expired',
        nama: 'Ghost Club',
        expiresAt: past,
      );
      expect(expired.isExpired, isTrue);
      expect(expired.isPendingActivation, isFalse);
    });

    test('TeamRosterMember role helpers identify coach, ketua, and anggota', () {
      const coach = TeamRosterMember(
        userId: 'u1',
        nama: 'Coach A',
        peran: 'coach',
        appPeran: 'user',
      );
      const ketua = TeamRosterMember(
        userId: 'u2',
        nama: 'Ketua B',
        peran: 'ketua',
        appPeran: 'user',
      );
      const member = TeamRosterMember(
        userId: 'u3',
        nama: 'Member C',
        peran: 'anggota',
        appPeran: 'user',
      );

      expect(coach.isCoach, isTrue);
      expect(coach.isTeamLeader, isTrue);
      expect(ketua.isCoach, isFalse);
      expect(ketua.isKetua, isTrue);
      expect(ketua.isTeamLeader, isTrue);
      expect(member.isTeamLeader, isFalse);
    });
  });

  group('SqliteLocalStore v6 expires_at persistence & graduation', () {
    test('persists expires_at and clears it once 2nd member joins', () async {
      final store = await SqliteLocalStore.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(store.close);

      final expiry = DateTime.now().toUtc().add(const Duration(hours: 72));
      final team = Team(
        id: 't-sqlite-1',
        nama: 'Kelas X-1',
        dibuatOleh: 'u-1',
        isPrivate: true,
        memberCount: 1,
        createdAt: DateTime.now().toUtc(),
        expiresAt: expiry,
      );

      await store.saveTeams('u-1', [team], isMine: true);
      final loaded = await store.getTeam('u-1', 't-sqlite-1');
      expect(loaded, isNotNull);
      expect(loaded!.isPendingActivation, isTrue);
      expect(loaded.expiresAt?.toUtc(), expiry);

      // Second member joins -> count reaches 2 -> expires_at graduates to null
      await store.setTeamMembershipLocal(
        'u-1',
        't-sqlite-1',
        memberCountDelta: 1,
      );
      final graduated = await store.getTeam('u-1', 't-sqlite-1');
      expect(graduated!.memberCount, 2);
      expect(graduated.expiresAt, isNull);
      expect(graduated.isPendingActivation, isFalse);
    });
  });

  group('TeamRepository team-scoped coaching & expiry filtering', () {
    test('myCoachedTeams returns only coached active teams and excludes expired teams', () async {
      final store = MemoryLocalStore();
      await store.setLastUserId('u-regular');
      await store.upsertProfile(
        const UserProfile(id: 'u-regular', nama: 'Regular Runner', peran: 'user'),
      );

      final coachedTeam = Team(
        id: 't-coached',
        nama: 'My PE Class',
        dibuatOleh: 'u-regular',
        memberCount: 2,
        createdAt: DateTime.now().toUtc(),
      );
      final joinedTeam = Team(
        id: 't-joined-only',
        nama: 'City Club',
        dibuatOleh: 'u-other',
        memberCount: 5,
        createdAt: DateTime.now().toUtc(),
      );
      final expiredTeam = Team(
        id: 't-expired',
        nama: 'Old Empty Club',
        dibuatOleh: 'u-regular',
        memberCount: 1,
        createdAt: DateTime.now().toUtc().subtract(const Duration(days: 8)),
        expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );

      await store.saveTeams(
        'u-regular',
        [coachedTeam, joinedTeam, expiredTeam],
        isMine: true,
      );
      await store.saveTeamRoster('u-regular', 't-coached', const [
        TeamRosterMember(
          userId: 'u-regular',
          nama: 'Regular Runner',
          peran: 'coach',
          appPeran: 'user',
        ),
      ]);
      await store.saveTeamRoster('u-regular', 't-joined-only', const [
        TeamRosterMember(
          userId: 'u-other',
          nama: 'Other Coach',
          peran: 'coach',
          appPeran: 'user',
        ),
        TeamRosterMember(
          userId: 'u-regular',
          nama: 'Regular Runner',
          peran: 'anggota',
          appPeran: 'user',
        ),
      ]);

      final repo = TeamRepository(store: store);
      final coached = await repo.myCoachedTeams();
      expect(coached.map((t) => t.id).toList(), ['t-coached']);

      final visible = await repo.myTeams();
      expect(visible.map((t) => t.id).toSet(), {'t-coached', 't-joined-only'});
      expect(await repo.getTeam('t-expired'), isNull);
    });

    test('demo createTeam sets 72-hour expiry, coach role, and preserves existing teams', () async {
      final store = MemoryLocalStore();
      await store.setLastUserId(PacerDummyData.demoUserId);
      await store.upsertProfile(
        const UserProfile(
          id: PacerDummyData.demoUserId,
          nama: 'andi_wijaya',
          peran: 'user',
        ),
      );
      final priorTeam = Team(
        id: 't-prior',
        nama: 'Existing Squad',
        dibuatOleh: 'u-other',
        memberCount: 4,
        createdAt: DateTime.now().toUtc(),
      );
      await store.saveTeams(PacerDummyData.demoUserId, [priorTeam], isMine: true);

      final repo = TeamRepository(store: store);
      final created = await repo.createTeam(nama: 'New Track Team');
      expect(created.isPendingActivation, isTrue);
      expect(created.memberCount, 1);

      final mine = await repo.myTeams();
      expect(mine.map((t) => t.id).toSet(), {created.id, 't-prior'});

      final roster = await repo.teamRoster(created.id);
      expect(roster.single.peran, 'coach');
    });
  });

  group('Team-scoped Coach UI & Pending Expiration Widgets', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PacerCache.instance.clear();
      langNotifier.value = Lang.en;
    });

    testWidgets('Regular user who coaches a team unlocks CoachBoardScreen for that team only', (tester) async {
      final prevStore = LocalStore.instance;
      addTearDown(() {
        LocalStore.instance = prevStore;
        PacerCache.instance.clear();
      });

      final store = MemoryLocalStore();
      await store.setLastUserId('u-1');
      await store.upsertProfile(
        const UserProfile(id: 'u-1', nama: 'Siti Runner', peran: 'user'),
      );
      await store.saveTeams(
        'u-1',
        [
          Team(
            id: 't-own',
            nama: 'Siti PE Class',
            dibuatOleh: 'u-1',
            memberCount: 2,
            createdAt: DateTime.now().toUtc(),
          ),
          Team(
            id: 't-other',
            nama: 'Other Squad',
            dibuatOleh: 'u-2',
            memberCount: 4,
            createdAt: DateTime.now().toUtc(),
          ),
        ],
        isMine: true,
      );
      await store.saveTeamRoster('u-1', 't-own', const [
        TeamRosterMember(
          userId: 'u-1',
          nama: 'Siti Runner',
          peran: 'coach',
          appPeran: 'user',
        ),
        TeamRosterMember(
          userId: 'u-student',
          nama: 'Budi Student',
          peran: 'anggota',
          appPeran: 'user',
        ),
      ]);
      await store.saveTeamRoster('u-1', 't-other', const [
        TeamRosterMember(
          userId: 'u-2',
          nama: 'Other Coach',
          peran: 'coach',
          appPeran: 'user',
        ),
        TeamRosterMember(
          userId: 'u-1',
          nama: 'Siti Runner',
          peran: 'anggota',
          appPeran: 'user',
        ),
      ]);
      LocalStore.instance = store;

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: const CoachBoardScreen(initialTeamId: 't-own'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Siti PE Class'), findsOneWidget);
      expect(find.text('Other Squad'), findsNothing);
      expect(find.text(S.coachBoardNoTeamsHint), findsNothing);
    });

    testWidgets('TeamDashboardScreen shows 72-hour pending banner & team-scoped coach controls, and guards sole coach leaving', (tester) async {
      final prevStore = LocalStore.instance;
      addTearDown(() {
        LocalStore.instance = prevStore;
        PacerCache.instance.clear();
      });

      final store = MemoryLocalStore();
      await store.setLastUserId('u-1');
      await store.upsertProfile(
        const UserProfile(id: 'u-1', nama: 'Siti Runner', peran: 'user'),
      );
      final pendingTeam = Team(
        id: 't-pending',
        nama: 'Morning 5K Group',
        dibuatOleh: 'u-1',
        isPrivate: true,
        inviteCode: 'ABCD1234',
        memberCount: 1,
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 60)),
      );
      await store.saveTeams('u-1', [pendingTeam], isMine: true);
      await store.saveTeamRoster('u-1', 't-pending', const [
        TeamRosterMember(
          userId: 'u-1',
          nama: 'Siti Runner',
          peran: 'coach',
          appPeran: 'user',
        ),
      ]);
      LocalStore.instance = store;

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: TeamDashboardScreen(
            teamId: 't-pending',
            initialTeam: pendingTeam,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pending activation banner & team-scoped Coach Board button appear for regular 'user' creator
      expect(find.text(S.teamPendingActivationTitle), findsOneWidget);
      expect(find.text(S.coachBoardTitle), findsOneWidget);
      expect(find.text('COACH'), findsOneWidget);

      // Tapping Leave as sole coach opens the sole-coach guard dialog
      await tester.ensureVisible(find.text(S.leaveTeamAction));
      await tester.tap(find.text(S.leaveTeamAction));
      await tester.pumpAndSettle();

      expect(find.text(S.soleCoachLeaveTitle), findsOneWidget);
    });

    testWidgets('TeamDashboardScreen hides coach controls when creator was demoted to anggota', (tester) async {
      final prevStore = LocalStore.instance;
      addTearDown(() {
        LocalStore.instance = prevStore;
        PacerCache.instance.clear();
      });

      final store = MemoryLocalStore();
      await store.setLastUserId('u-1');
      await store.upsertProfile(
        const UserProfile(id: 'u-1', nama: 'Siti Runner', peran: 'user'),
      );
      final activeTeam = Team(
        id: 't-demoted',
        nama: 'Campus Track',
        dibuatOleh: 'u-1',
        isPrivate: true,
        memberCount: 2,
        createdAt: DateTime.now().toUtc(),
      );
      await store.saveTeams('u-1', [activeTeam], isMine: true);
      await store.saveTeamRoster('u-1', 't-demoted', const [
        TeamRosterMember(
          userId: 'u-2',
          nama: 'Co Coach',
          peran: 'coach',
          appPeran: 'user',
        ),
        TeamRosterMember(
          userId: 'u-1',
          nama: 'Siti Runner',
          peran: 'anggota',
          appPeran: 'user',
        ),
      ]);
      LocalStore.instance = store;

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: TeamDashboardScreen(
            teamId: 't-demoted',
            initialTeam: activeTeam,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.coachBoardTitle), findsNothing);
      expect(find.text(S.deleteLabel), findsNothing);
    });

    testWidgets('CreateClubScreen displays 72-hour hint without non-functional placeholders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: const CreateClubScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.teamCreateRoleAndExpiryHint), findsOneWidget);
      expect(find.text(S.addLogo), findsNothing);
      expect(find.text('Road Run'), findsNothing);
      expect(find.text(S.cityHQ), findsNothing);
    });
  });
}
