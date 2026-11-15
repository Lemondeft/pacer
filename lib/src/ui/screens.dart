import 'dart:async' show Timer;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pacer/core/responsive/responsive.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/aktivitas/activity_repository.dart';
import 'package:pacer/src/auth/auth_repository.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/challenge/challenge_repository.dart';
import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/leaderboard/leaderboard_repository.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/notifications/notification_model.dart';
import 'package:pacer/src/notifications/notification_repository.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:pacer/src/teams/team_model.dart';
import 'package:pacer/src/teams/team_repository.dart';
import 'package:pacer/src/tracking/recorder.dart';
import 'package:pacer/src/update/github_update_service.dart';
import 'package:pacer/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_strings.dart';
import 'app_theme.dart';
import 'format.dart';
import 'more_screens.dart';
import 'pacer_glass.dart';
import 'widgets.dart';

/// Figma LOADING SCREEN: the one PacerLogo + blue progress rectangle 218x18 r2.
/// Centered splash, capped at 480 — no scaling, no stretch.
class LoadingScreen extends StatelessWidget {
  final VoidCallback onDone;
  const LoadingScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Scaffold(
      backgroundColor: scheme.scaffold,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PacerLogo(width: 260),
                const SizedBox(height: 24),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1200),
                  onEnd: onDone,
                  builder: (context, value, _) {
                    return Container(
                      width: 218,
                      height: 18,
                      decoration: BoxDecoration(
                        color: scheme.softBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 218 * value,
                        height: 18,
                        decoration: BoxDecoration(
                          color: scheme.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma GET STARTED: "Pacer, siap membantu!" + Sign In filled + Log In outlined.
/// Form-style screen: 720 shell, vertically centered when short.
class GetStartedScreen extends StatelessWidget {
  final VoidCallback onSignIn;
  final VoidCallback onLogIn;
  const GetStartedScreen({
    super.key,
    required this.onSignIn,
    required this.onLogIn,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PacerTrackLinesPainter(
                  color: scheme.border.withValues(alpha: scheme.isDark ? 0.28 : 0.55),
                  count: 5,
                ),
              ),
            ),
          ),
          SafeArea(
            child: ResponsiveScroll(
              maxWidth: 720,
              centerContent: true,
              child: Column(
                children: [
                  const PacerLogo(width: 280),
                  const SizedBox(height: 24),
                  Text(
                    S.appTagline,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      letterSpacing: -0.4,
                      color: scheme.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  PrimaryButton(label: S.signIn, onPressed: onSignIn),
                  const SizedBox(height: 14),
                  PacerTapScale(
                    pressedScale: 0.98,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: onLogIn,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: scheme.card.withValues(alpha: 0.72),
                          side: BorderSide(
                            width: 1.6,
                            color: scheme.accent,
                          ),
                          shape: const PacerSquircleBorder(PacerRadii.md),
                        ),
                        child: Text(
                          S.logIn,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: scheme.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma SIGN IN: "Create an account" 40 + 4 fields + Sign In + divider + icon row.
/// Form-style screen: 720 shell, fields fill the shell width.
class CreateAccountScreen extends StatefulWidget {
  final VoidCallback onSubmitted;
  final VoidCallback? onBack;
  const CreateAccountScreen({
    super.key,
    required this.onSubmitted,
    this.onBack,
  });

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// False when Supabase was never initialized (demo mode): keep pass-through.
  bool get _backend {
    try {
      supa;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final nama = _name.text.trim();
    final email = _email.text.trim();
    if (nama.isEmpty || email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = S.errFillAll);
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = S.errEmail);
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = S.errPasswordMatch);
      return;
    }
    if (!_backend) {
      widget.onSubmitted();
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthRepository().signUp(
        email: email,
        password: _password.text,
        nama: nama,
      );
      widget.onSubmitted();
    } on EmailConfirmationRequired catch (_) {
      setState(() => _error = S.confirmEmail);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = S.errSignupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(onBack: widget.onBack),
              const SizedBox(height: 16),
              Text(S.createAccount, style: PacerText.authTitleOf(context)),
              const SizedBox(height: 28),
              AuthField(
                hint: S.username,
                icon: Icons.person_outline,
                controller: _name,
              ),
              const SizedBox(height: 16),
              AuthField(
                hint: S.email,
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                controller: _email,
              ),
              const SizedBox(height: 16),
              AuthField(
                hint: S.password,
                icon: Icons.lock_outline,
                obscure: true,
                controller: _password,
              ),
              const SizedBox(height: 16),
              AuthField(
                hint: S.confirmPassword,
                icon: Icons.lock_outline,
                obscure: true,
                controller: _confirm,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                AuthErrorText(_error!),
              ],
              const SizedBox(height: 32),
              PrimaryButton(label: S.signIn, onPressed: _busy ? null : _submit),
              const SizedBox(height: 32),
              Divider(color: PacerScheme.of(context).border, height: 1),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  S.orSignUpWith,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: PacerSurface(
                  width: 48,
                  height: 48,
                  radius: PacerRadii.md,
                  child: Icon(
                    Icons.person_add_alt_outlined,
                    color: PacerScheme.of(context).ink,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live home dashboard: PACER header, streak card, quick workout actions,
/// weekly summary chart, active/available challenges, history, teams,
/// and leaderboard snapshot. Responsive across compact/medium/expanded.
typedef _HomeChallengeItem = ({
  Challenge challenge,
  PartisipasiChallenge? participation,
  String? teamName,
});

typedef _HomeRankSummary = ({
  String boardName,
  int rank,
  int total,
  double value,
  String kriteria,
});

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSeeTeams;
  final VoidCallback? onSeeHistory;
  final VoidCallback? onSeeLeaderboard;
  final ValueChanged<String>? onStartSport;
  final VoidCallback? onContentUpdated;
  const HomeScreen({
    super.key,
    this.onSeeTeams,
    this.onSeeHistory,
    this.onSeeLeaderboard,
    this.onStartSport,
    this.onContentUpdated,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

/// Live home data; [isDemo] marks signed-out preview mode.
class _HomeData {
  final List<LocalActivity> activities;
  final int streak;
  final DateTime? streakLast;
  final List<Team> teams;
  final String initials;
  final bool isDemo;
  final AppNotification? assignedBanner;
  final double weeklyKm;
  final int weeklySeconds;
  final int weeklyWorkouts;
  final List<double> dailyKmThisWeek;
  final List<_HomeChallengeItem> featuredChallenges;
  final bool hasJoinedChallenges;
  final _HomeRankSummary? rankSummary;

  const _HomeData({
    this.activities = const [],
    this.streak = 0,
    this.streakLast,
    this.teams = const [],
    this.initials = '?',
    this.isDemo = false,
    this.assignedBanner,
    this.weeklyKm = 0,
    this.weeklySeconds = 0,
    this.weeklyWorkouts = 0,
    this.dailyKmThisWeek = const [0, 0, 0, 0, 0, 0, 0],
    this.featuredChallenges = const [],
    this.hasJoinedChallenges = false,
    this.rankSummary,
  });

  _HomeData copyWith({AppNotification? Function()? assignedBanner}) => _HomeData(
    activities: activities,
    streak: streak,
    streakLast: streakLast,
    teams: teams,
    initials: initials,
    isDemo: isDemo,
    assignedBanner: assignedBanner != null
        ? assignedBanner()
        : this.assignedBanner,
    weeklyKm: weeklyKm,
    weeklySeconds: weeklySeconds,
    weeklyWorkouts: weeklyWorkouts,
    dailyKmThisWeek: dailyKmThisWeek,
    featuredChallenges: featuredChallenges,
    hasJoinedChallenges: hasJoinedChallenges,
    rankSummary: rankSummary,
  );
}

class HomeScreenState extends State<HomeScreen> {
  _HomeData? _data;
  bool _wasSyncing = false;
  final NotificationRepository _notifRepo = NotificationRepository();

  @override
  void initState() {
    super.initState();
    SyncEngine.instance.addListener(_onSyncChanged);
    NotificationRepository.revisionNotifier.addListener(_onNotifRevision);
    _notifRepo.watchNotifications();
    reload();
  }

  @override
  void dispose() {
    SyncEngine.instance.removeListener(_onSyncChanged);
    NotificationRepository.revisionNotifier.removeListener(_onNotifRevision);
    _notifRepo.dispose();
    super.dispose();
  }

  void _onNotifRevision() {
    if (!mounted) return;
    _notifRepo.listNotifications().then((items) {
      if (!mounted || _data == null) return;
      final top = NotificationRepository.topAssignedBannerFrom(items);
      setState(() => _data = _data!.copyWith(assignedBanner: () => top));
    }).catchError((_) {});
  }

  void _onSyncChanged() {
    final syncing = SyncEngine.instance.status.isSyncing;
    if (_wasSyncing && !syncing) {
      reload();
    }
    _wasSyncing = syncing;
  }

  /// Reloads home dashboard cards. When [forceRefresh] is true, cache is bypassed.
  Future<void> reload({bool forceRefresh = false}) async {
    final d = await _load(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() => _data = d);
      widget.onContentUpdated?.call();
    }
  }

  ({int count, List<double> dailyKm}) _weeklyBreakdown(
    List<LocalActivity> activities,
    DateTime now,
  ) {
    final thisKey = periodeKey(now);
    final bars = List<double>.filled(7, 0);
    var count = 0;
    for (final item in activities) {
      final ts = (item.activity.mulaiAt ?? item.activity.selesaiAt)?.toLocal();
      if (ts == null || periodeKey(ts) != thisKey) continue;
      count++;
      final dayIdx = (ts.weekday - 1).clamp(0, 6);
      bars[dayIdx] += (item.activity.jarakM ?? 0) / 1000.0;
    }
    return (count: count, dailyKm: bars);
  }

  Future<_HomeData> _demoData() async {
    final now = DateTime.now();
    final notifs = await _notifRepo.listNotifications();
    final demoActs = PacerDummyData.activities
        .take(5)
        .map(
          (a) => LocalActivity(
            activity: a,
            syncState: SyncState.synced,
            updatedAt: a.selesaiAt ?? a.mulaiAt ?? now,
          ),
        )
        .toList();
    final demoTeams = PacerDummyData.demoMyTeams;
    final teamNames = {for (final t in PacerDummyData.demoTeams) t.id: t.nama};
    final partsByChal = {
      for (final p in PacerDummyData.getDemoParticipations()) p.challengeId: p,
    };
    final featured = <_HomeChallengeItem>[];
    for (final c in PacerDummyData.demoChallenges) {
      if (!c.diumumkan || !isChallengeActive(c, now.toUtc())) continue;
      final p = partsByChal[c.id];
      if (p != null && p.isActive && !p.berhasil) {
        featured.add((
          challenge: c,
          participation: p,
          teamName: c.teamId != null ? teamNames[c.teamId] : null,
        ));
      }
      if (featured.length >= 3) break;
    }
    final lb = PacerDummyData.getLeaderboardData(scope: 'team');
    _HomeRankSummary? rankSummary;
    for (final row in lb.rows) {
      if (row.entry.userId == lb.uid) {
        rankSummary = (
          boardName: lb.boardNama,
          rank: row.entry.posisi ?? 1,
          total: lb.rows.length,
          value: row.entry.nilai,
          kriteria: 'jarak',
        );
        break;
      }
    }
    final dailyDemo = <double>[5.4, 0, 8.2, 6.5, 10.1, 7.8, 7.2];
    return _HomeData(
      activities: demoActs,
      streak: 5,
      streakLast: now.subtract(const Duration(hours: 4)),
      teams: demoTeams,
      initials: 'PD',
      isDemo: true,
      assignedBanner: NotificationRepository.topAssignedBannerFrom(notifs),
      weeklyKm: PacerDummyData.statistics.km,
      weeklySeconds: PacerDummyData.statistics.seconds,
      weeklyWorkouts: 5,
      dailyKmThisWeek: dailyDemo,
      featuredChallenges: featured,
      hasJoinedChallenges: featured.isNotEmpty,
      rankSummary: rankSummary,
    );
  }

  Future<_HomeData> _load({bool forceRefresh = false}) async {
    try {
      if (await isDemoAccount()) {
        return await _demoData();
      }
      final now = DateTime.now();
      final repo = ActivityRepository();
      final auth = AuthRepository();
      final uid = await auth.resolveUserId();
      final activities = await repo.listLocalActivities(
        limit: 15,
        forceRefresh: forceRefresh,
      );
      final streak = await repo.getStreak(forceRefresh: forceRefresh);
      final stats = await repo.getStatistik(
        periodeKey(now),
        forceRefresh: forceRefresh,
      );
      final teams = await TeamRepository().myTeams(forceRefresh: forceRefresh);
      final profile = await auth.getProfile(forceRefresh: forceRefresh);
      final email = await auth.getSavedEmail();
      final notifs = await _notifRepo.listNotifications(
        forceRefresh: forceRefresh,
      );
      final teamNames = {for (final t in teams) t.id: t.nama};

      // Challenges: prioritized joined active items; fall back to open challenges.
      final featured = <_HomeChallengeItem>[];
      var hasJoined = false;
      try {
        final chalRepo = ChallengeRepository();
        final allChals = await chalRepo.listChallenges(
          forceRefresh: forceRefresh,
        );
        final parts = await chalRepo.myParticipations(
          forceRefresh: forceRefresh,
        );
        final partMap = {for (final p in parts) p.challengeId: p};
        final nowUtc = now.toUtc();
        final activeChals = allChals
            .where((c) => c.diumumkan && isChallengeActive(c, nowUtc))
            .toList();
        for (final c in activeChals) {
          final p = partMap[c.id];
          if (p != null && p.isActive && !p.berhasil) {
            hasJoined = true;
            featured.add((
              challenge: c,
              participation: p,
              teamName: c.teamId != null ? teamNames[c.teamId] : null,
            ));
          }
          if (featured.length >= 3) break;
        }
        if (featured.isEmpty) {
          for (final c in activeChals) {
            if (partMap.containsKey(c.id)) continue;
            featured.add((
              challenge: c,
              participation: null,
              teamName: c.teamId != null ? teamNames[c.teamId] : null,
            ));
            if (featured.length >= 2) break;
          }
        }
      } catch (_) {}

      // Top leaderboard snapshot (pure offline-first SWR, never throws).
      _HomeRankSummary? rankSummary;
      if (uid != null) {
        try {
          final lbRepo = LeaderboardRepository();
          final boards = await lbRepo.listLeaderboards(
            limit: 5,
            forceRefresh: forceRefresh,
          );
          if (boards.isNotEmpty) {
            final topBoard = boards.first;
            final rows = await lbRepo.getPeringkatWithNames(
              topBoard.id,
              limit: 50,
              forceRefresh: forceRefresh,
            );
            for (var i = 0; i < rows.length; i++) {
              if (rows[i].entry.userId == uid) {
                rankSummary = (
                  boardName: topBoard.nama,
                  rank: rows[i].entry.posisi ?? (i + 1),
                  total: rows.length,
                  value: rows[i].entry.nilai,
                  kriteria: topBoard.kriteria,
                );
                break;
              }
            }
          }
        } catch (_) {}
      }

      final weekly = _weeklyBreakdown(activities, now);
      final name = (profile?.nama ?? '').trim();
      final label = name.isNotEmpty ? name : (email ?? 'P');
      return _HomeData(
        activities: activities,
        streak: streak?.berjalan ?? 0,
        streakLast: streak?.terakhir,
        teams: teams,
        initials: initialsOf(label),
        isDemo: false,
        assignedBanner: NotificationRepository.topAssignedBannerFrom(notifs),
        weeklyKm: (stats?.jarakM ?? 0) / 1000.0,
        weeklySeconds: stats?.waktuS ?? 0,
        weeklyWorkouts: weekly.count,
        dailyKmThisWeek: weekly.dailyKm,
        featuredChallenges: featured,
        hasJoinedChallenges: hasJoined,
        rankSummary: rankSummary,
      );
    } catch (_) {
      if (await isDemoAccount()) {
        return await _demoData();
      }
      return const _HomeData(
        activities: [],
        streak: 0,
        teams: [],
        initials: 'P',
        isDemo: false,
      );
    }
  }

  Widget _header(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          PacerTapScale(
            pressedScale: 0.92,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.card,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.border),
                boxShadow: [scheme.shadowBox],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const FiturScreen()))
                    .then((_) => reload()),
                icon: Icon(Icons.menu_rounded, size: 24, color: scheme.ink),
              ),
            ),
          ),
          // Balance right-side bell (44) + gap (6) + avatar (48) = 98px so PacerLogo centers cleanly.
          const SizedBox(width: 54),
          const Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: PacerLogo(width: 112),
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: NotificationRepository.unreadCountNotifier,
            builder: (context, unread, _) {
              return PacerTapScale(
                pressedScale: 0.92,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.border),
                    boxShadow: [scheme.shadowBox],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: S.notifications,
                    onPressed: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        )
                        .then((_) => reload()),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          unread > 0
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none_rounded,
                          size: 22,
                          color: scheme.ink,
                        ),
                        if (unread > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: PacerColors.errorRed,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: scheme.scaffold,
                                  width: 1.5,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 16,
                              ),
                              child: Text(
                                unread > 9 ? '9+' : '$unread',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          // Logged-in user's initials (Figma spec). Tap → Account.
          // 48px tap target around the 42px visual.
          GestureDetector(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AccountScreen()))
                .then((_) => reload()),
            child: PacerTapScale(
              pressedScale: 0.92,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.border,
                        width: 1.5,
                      ),
                    ),
                    child: InitialAvatar(_data?.initials ?? '?', size: 40),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openStreaks() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const StreaksScreen()))
      .then((_) => reload());

  void _openStatistics() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const StatisticScreen()))
      .then((_) => reload());

  void _openChallenges() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ChallengeListScreen()))
      .then((_) => reload());

  void _openLeaderboard() {
    if (widget.onSeeLeaderboard != null) {
      widget.onSeeLeaderboard!();
    } else {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (ctx) =>
                  LeaderboardScreen(onBack: () => Navigator.of(ctx).pop()),
            ),
          )
          .then((_) => reload());
    }
  }

  void _openTeams() {
    if (widget.onSeeTeams != null) {
      widget.onSeeTeams!();
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const TeamsScreen()))
          .then((_) => reload());
    }
  }

  void _startSport(String sport) {
    if (widget.onStartSport != null) {
      widget.onStartSport!(sport);
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RunSetupScreen(initialSport: sport)))
          .then((_) => reload());
    }
  }

  Widget _streak() {
    // The card carries its own header pill, so no separate SectionHeader —
    // count, week strip, and record read as one unit.
    // The stored count only resets on the next workout, so derive the live
    // state here: a missed day shows 0 / inactive instead of a stale count.
    final now = DateTime.now();
    final last = _data?.streakLast;
    final raw = _data?.streak ?? 0;
    final count = effectiveStreak(count: raw, last: last, now: now);
    return GestureDetector(
      onTap: _openStreaks,
      behavior: HitTestBehavior.opaque,
      child: PacerTapScale(
        child: StreakCard(
          count: count,
          done: streakWeek(count: count, last: last, now: now),
          todayIndex: now.weekday - 1,
          status: streakStatusOf(count: raw, last: last, now: now),
        ),
      ),
    );
  }

  Widget _quickActions() {
    final scheme = PacerScheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? PacerColors.primary : const Color(0xFF0284C7);
    final items = [
      (key: 'lari', icon: Icons.directions_run_rounded, accent: scheme.accent),
      (key: 'joging', icon: Icons.directions_walk_rounded, accent: secondary),
      (key: 'bersepeda', icon: Icons.directions_bike_rounded, accent: scheme.accent),
      (key: 'berjalan', icon: Icons.nordic_walking_rounded, accent: secondary),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: S.quickStartTitle),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: PacerSurface(
                  radius: PacerRadii.md,
                  borderColor: items[i].accent.withValues(
                    alpha: dark ? 0.28 : 0.36,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        scheme.card,
                        items[i].accent,
                        dark ? 0.10 : 0.06,
                      )!,
                      scheme.card,
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  onTap: () => _startSport(items[i].key),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: ShapeDecoration(
                          color: items[i].accent.withValues(
                            alpha: dark ? 0.16 : 0.14,
                          ),
                          shape: PacerSquircleBorder(
                            PacerRadii.sm,
                            side: BorderSide(
                              color: items[i].accent.withValues(alpha: 0.34),
                            ),
                            rimColor: Colors.white.withValues(
                              alpha: dark ? 0.14 : 0.65,
                            ),
                          ),
                        ),
                        child: Icon(
                          items[i].icon,
                          size: 20,
                          color: items[i].accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          S.sportName(items[i].key),
                          maxLines: 1,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _weeklyOverview() {
    final scheme = PacerScheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final d = _data;
    final weeklyKm = d?.weeklyKm ?? 0;
    final weeklySec = d?.weeklySeconds ?? 0;
    final weeklyCount = d?.weeklyWorkouts ?? 0;
    final bars = d?.dailyKmThisWeek ?? const [0, 0, 0, 0, 0, 0, 0];
    final maxBar = bars.fold<double>(1.0, (m, v) => v > m ? v : m);
    final paceText = weeklyKm > 0 && weeklySec > 0
        ? fmtPace(weeklySec, weeklyKm * 1000)
        : '—';
    final dayLetters = S.dayLetters;
    final todayIdx = DateTime.now().weekday - 1;

    return GestureDetector(
      onTap: _openStatistics,
      behavior: HitTestBehavior.opaque,
      child: PacerTapScale(
        child: Container(
          width: double.infinity,
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  scheme.card,
                  scheme.accent,
                  dark ? 0.08 : 0.05,
                )!,
                Color.lerp(scheme.scaffold, scheme.card, 0.55)!,
              ],
            ),
            shape: PacerSquircleBorder(
              PacerRadii.hero,
              side: BorderSide(
                color: dark
                    ? scheme.accent.withValues(alpha: 0.25)
                    : scheme.border,
              ),
              rimColor: scheme.cardTopRim,
            ),
            shadows: [scheme.shadowBox],
          ),
          child: ClipPath.shape(
            shape: const PacerSquircleBorder(PacerRadii.hero),
            child: Stack(
            children: [
              Positioned(
                right: -24,
                top: -24,
                child: IgnorePointer(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          scheme.accent.withValues(
                            alpha: dark ? 0.16 : 0.10,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: scheme.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.insights_rounded,
                            size: 15,
                            color: scheme.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            S.weeklyOverviewTitle,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: scheme.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.accent.withValues(
                              alpha: dark ? 0.14 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: scheme.accent.withValues(
                                alpha: dark ? 0.35 : 0.28,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                S.viewStats,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: dark ? scheme.accent : scheme.ink,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 15,
                                color: dark ? scheme.accent : scheme.ink,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.bottomLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    weeklyKm.toStringAsFixed(2),
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: scheme.ink,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      'km',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.searchBg.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            S.runsCount(weeklyCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Inset 7-day volume chart well
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: BoxDecoration(
                        color: scheme.scaffold.withValues(
                          alpha: dark ? 0.55 : 0.75,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.border.withValues(alpha: 0.55),
                        ),
                      ),
                      child: SizedBox(
                        height: 60,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < 7; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: scheme.border.withValues(
                                            alpha: dark ? 0.35 : 0.45,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.bottomCenter,
                                        child: FractionallySizedBox(
                                          widthFactor: 1.0,
                                          heightFactor: bars[i] <= 0
                                              ? 0.16
                                              : (bars[i] / maxBar).clamp(
                                                  0.24,
                                                  1.0,
                                                ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: bars[i] > 0
                                                  ? LinearGradient(
                                                      begin: Alignment.topCenter,
                                                      end: Alignment.bottomCenter,
                                                      colors: i == todayIdx
                                                          ? [
                                                              PacerColors.primary,
                                                              const Color(
                                                                0xFF38BDF8,
                                                              ),
                                                            ]
                                                          : [
                                                              scheme.accent,
                                                              Color.lerp(
                                                                scheme.accent,
                                                                PacerColors.neon,
                                                                0.4,
                                                              )!,
                                                            ],
                                                    )
                                                  : null,
                                              color: bars[i] <= 0
                                                  ? scheme.border.withValues(
                                                      alpha: 0.65,
                                                    )
                                                  : null,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      dayLetters[i],
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: i == todayIdx
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: i == todayIdx
                                            ? scheme.accent
                                            : scheme.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(height: 0.8, color: scheme.groupedDivider),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, c) {
                        final pace = _WeeklyStatMetric(
                          icon: Icons.speed_rounded,
                          label: S.avgPaceShort,
                          value: paceText,
                        );
                        final time = _WeeklyStatMetric(
                          icon: Icons.timer_outlined,
                          label: S.time,
                          value: weeklySec > 0 ? fmtDurasi(weeklySec) : '0m',
                        );
                        final workouts = _WeeklyStatMetric(
                          icon: Icons.bolt_rounded,
                          label: S.workoutsShort,
                          value: '$weeklyCount',
                        );
                        final vDivider = Container(
                          width: 0.8,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: scheme.groupedDivider,
                        );
                        // 2-up tablet cards (~300px inner width) wrap into 2+1
                        // cleanly so Avg Pace & Workouts never truncate.
                        if (c.maxWidth < 330) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: time),
                                  vDivider,
                                  Expanded(child: pace),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Container(
                                  height: 0.8,
                                  color: scheme.groupedDivider,
                                ),
                              ),
                              workouts,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: time),
                            vDivider,
                            Expanded(child: pace),
                            vDivider,
                            Expanded(child: workouts),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _challenges() {
    final scheme = PacerScheme.of(context);
    final items = _data?.featuredChallenges ?? const [];
    final hasJoined = _data?.hasJoinedChallenges ?? false;
    final title = hasJoined ? S.activeChallengesTitle : S.openChallengesTitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: _openChallenges),
        const SizedBox(height: 14),
        if (items.isEmpty)
          GestureDetector(
            onTap: _openChallenges,
            behavior: HitTestBehavior.opaque,
            child: PacerTapScale(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: scheme.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.emoji_events_outlined,
                        color: scheme.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.browseChallengesCta,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            S.noChallengesHomeHint,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: scheme.muted),
                  ],
                ),
              ),
            ),
          )
        else
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _HomeChallengeCard(
              challenge: items[i].challenge,
              participation: items[i].participation,
              teamName: items[i].teamName,
              onTap: () async {
                final changed = await ChallengeDetailSheet.show(
                  context,
                  challenge: items[i].challenge,
                  participation: items[i].participation,
                );
                if (changed == true && mounted) {
                  reload(forceRefresh: true);
                }
              },
            ),
          ],
      ],
    );
  }

  Widget _standingCard() {
    final scheme = PacerScheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final summary = _data?.rankSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: S.leaderboardSnapshotTitle,
          onSeeAll: _openLeaderboard,
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _openLeaderboard,
          behavior: HitTestBehavior.opaque,
          child: PacerTapScale(
            child: Container(
              width: double.infinity,
              decoration: ShapeDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      scheme.card,
                      scheme.accent,
                      dark ? 0.09 : 0.06,
                    )!,
                    Color.lerp(scheme.scaffold, scheme.card, 0.55)!,
                  ],
                ),
                shape: PacerSquircleBorder(
                  PacerRadii.lg,
                  side: BorderSide(
                    color: summary != null
                        ? scheme.accent.withValues(alpha: dark ? 0.45 : 0.65)
                        : scheme.border,
                  ),
                  rimColor: scheme.cardTopRim,
                ),
                shadows: [scheme.shadowBox],
              ),
              child: ClipPath.shape(
                shape: const PacerSquircleBorder(PacerRadii.lg),
                child: Stack(
                children: [
                  Positioned(
                    right: -12,
                    bottom: -18,
                    child: IgnorePointer(
                      child: Icon(
                        Icons.emoji_events_rounded,
                        size: 96,
                        color: (summary != null
                                ? scheme.accent
                                : PacerColors.primary)
                            .withValues(alpha: dark ? 0.07 : 0.08),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: summary != null
                        ? Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: scheme.accent,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.accent.withValues(
                                        alpha: dark ? 0.28 : 0.35,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '#${summary.rank}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        ThemeData.estimateBrightnessForColor(
                                              scheme.accent,
                                            ) ==
                                            Brightness.light
                                        ? PacerColors.navy
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      summary.boardName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.searchBg.withValues(
                                              alpha: 0.85,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            '${summary.rank} / ${summary.total}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: dark
                                                  ? scheme.accent
                                                  : scheme.ink,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${summary.value.toStringAsFixed(1)} ${summary.kriteria == 'kalori' ? 'kcal' : summary.kriteria == 'durasi' ? S.unitMinutes : 'km'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: scheme.muted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: scheme.searchBg.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: scheme.ink,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: PacerColors.primary.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: PacerColors.primary.withValues(
                                      alpha: 0.28,
                                    ),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.leaderboard_rounded,
                                  color: PacerColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      S.openLeaderboardCta,
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      S.noRankingYet,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: scheme.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: scheme.searchBg.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: scheme.ink,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _history() {
    final activities = _data?.activities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: S.history, onSeeAll: widget.onSeeHistory),
        const SizedBox(height: 12),
        // Empty state instead of mock cards when signed in.
        if (activities == null || activities.isEmpty)
          PacerEmptyState(
            S.noRunsOfflineEmpty,
            icon: Icons.directions_run_outlined,
          )
        else
          for (final item in activities.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: RunSessionCard(
                title: S.sportName(item.activity.jenis),
                date: fmtDate(item.activity.mulaiAt),
                time: fmtDurasi(item.activity.durasiS),
                pace: fmtPace(item.activity.durasiS, item.activity.jarakM),
                distance: fmtKm(item.activity.jarakM),
                syncState: _data?.isDemo == true ? null : item.syncState,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RunFinishScreen(
                      title:
                          '${S.sportName(item.activity.jenis)} ${fmtDate(item.activity.mulaiAt)}'
                              .trim(),
                      isHistoryDetail: true,
                      aktivitasId: _data?.isDemo == true
                          ? null
                          : item.activity.id,
                      summary: RunSummary(
                        aktivitasId: item.activity.id,
                        jenis: item.activity.jenis,
                        jarakM: item.activity.jarakM ?? 0,
                        durasiS: item.activity.durasiS ?? 0,
                        pointCount: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _teams() {
    final teams = _data?.teams;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: S.pacerTeams, onSeeAll: widget.onSeeTeams),
        const SizedBox(height: 20),
        // Horizontal carousel: cards grow with width via fluid(), never fixed.
        SizedBox(
          height: 150,
          child: LayoutBuilder(
            builder: (context, c) {
              final cardW = fluid(c.maxWidth, 241, 300);
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                children: [
                  // Compact variant: the carousel is only 150px tall.
                  if (teams == null || teams.isEmpty)
                    SizedBox(
                      width: cardW,
                      child: GestureDetector(
                        onTap: _openTeams,
                        behavior: HitTestBehavior.opaque,
                        child: PacerTapScale(
                          child: PacerEmptyState(
                            S.noTeamsCachedEmpty,
                            icon: Icons.groups_outlined,
                            compact: true,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    for (var i = 0; i < teams.length; i++) ...[
                      if (i > 0) const SizedBox(width: 19),
                      GestureDetector(
                        onTap: () async {
                          final changed = await Navigator.of(context)
                              .push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => TeamDashboardScreen(
                                    teamId: teams[i].id,
                                    initialTeam: teams[i],
                                  ),
                                ),
                              );
                          if (changed == true && mounted) {
                            reload(forceRefresh: true);
                          }
                        },
                        child: TeamCard(
                          name: teams[i].nama,
                          width: cardW,
                          memberCount: teams[i].memberCount,
                          isJoined: true,
                          isPrivate: teams[i].isPrivate,
                        ),
                      ),
                    ],
                    const SizedBox(width: 19),
                    _HomeExploreClubsCard(width: 168, onTap: _openTeams),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ResponsiveScroll(
        onRefresh: () => reload(forceRefresh: true),
        // Bottom clearance for the floating nav pill (nav height + margin).
        padding: const EdgeInsets.only(bottom: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 12),
            if (_data != null && !_data!.isDemo) const SyncStatusBanner(),
            if (_data?.assignedBanner != null) ...[
              const SizedBox(height: 8),
              _AssignedChallengeBanner(
                notification: _data!.assignedBanner!,
                onDismiss: () => NotificationRepository.dismissBanner(
                  _data!.assignedBanner!.id,
                ),
                onOpen: () async {
                  final b = _data!.assignedBanner!;
                  await _notifRepo.markAsRead(b.id);
                  if (!context.mounted) return;
                  if (b.challengeId != null && b.challengeId!.isNotEmpty) {
                    await ChallengeDetailSheet.show(
                      context,
                      challengeId: b.challengeId,
                    );
                  } else {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  }
                  if (mounted) reload();
                },
              ),
            ],
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, c) {
                return switch (screenSizeOf(c.maxWidth)) {
                  ScreenSize.compact => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _streak(),
                      const SizedBox(height: 20),
                      _quickActions(),
                      const SizedBox(height: 24),
                      _weeklyOverview(),
                      const SizedBox(height: 28),
                      _challenges(),
                      const SizedBox(height: 24),
                      _standingCard(),
                      const SizedBox(height: 28),
                      _history(),
                      const SizedBox(height: 28),
                      _teams(),
                    ],
                  ),
                  ScreenSize.medium => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _streak()),
                          const SizedBox(width: 24),
                          Expanded(child: _weeklyOverview()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _quickActions(),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _challenges()),
                          const SizedBox(width: 24),
                          Expanded(child: _history()),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _teams()),
                          const SizedBox(width: 24),
                          Expanded(child: _standingCard()),
                        ],
                      ),
                    ],
                  ),
                  ScreenSize.expanded => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _streak(),
                            const SizedBox(height: 24),
                            _weeklyOverview(),
                            const SizedBox(height: 24),
                            _standingCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _quickActions(),
                            const SizedBox(height: 28),
                            _challenges(),
                            const SizedBox(height: 28),
                            _history(),
                            const SizedBox(height: 32),
                            _teams(),
                          ],
                        ),
                      ),
                    ],
                  ),
                };
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shell: floating dark pill nav (4 icons + central START) on compact and
/// medium; extended NavigationRail on expanded. The pill scales with
/// fluid(w, 377, 480) — bigger on bigger screens, capped at ~480, centered.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  final List<int> _tabHistory = [];
  DateTime? _lastBackAt;
  String _activeSport = 'lari';
  String? _activeGoal;
  List<String>? _activeChallengeIds;
  ActiveDraftRun? _resumedDraft;
  bool _draftPrompted = false;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final LiquidGlassViewController _glassController =
      LiquidGlassViewController();
  Timer? _glassScrollTimer;
  bool _glassRealtime = false;
  bool _glassCaptureScheduled = false;
  Brightness? _lastBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _glassController.captureOnce();
      if (await _checkPendingDraft() || !mounted) return;
      await _checkGithubUpdate();
    });
  }

  Future<void> _checkGithubUpdate() async {
    final svc = GitHubUpdateService.instance;
    if (svc.clientFactory == null &&
        WidgetsBinding.instance.runtimeType.toString().contains(
          'TestWidgetsFlutterBinding',
        )) {
      return;
    }
    final release = await svc.checkOnceOnStartup();
    if (release == null || !mounted) return;
    await UpdateAvailableSheet.show(context, release);
  }

  @override
  void dispose() {
    _glassScrollTimer?.cancel();
    _glassScrollTimer = null;
    if (_glassRealtime) {
      _glassRealtime = false;
      _glassController.stopRealtimeCapture();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scheduleGlassCapture() {
    // When Impeller shader filters are available, LiquidGlassLens reads the
    // live backdrop via BackdropFilter and never needs RepaintBoundary capture.
    if (ImageFilter.isShaderFilterSupported ||
        _index == 1 ||
        _glassCaptureScheduled) {
      return;
    }
    _glassCaptureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _glassCaptureScheduled = false;
      if (!mounted || _index == 1) return;
      _glassController.captureOnce();
    });
  }

  void _startGlassRealtime() {
    if (ImageFilter.isShaderFilterSupported || _index == 1) return;
    _glassScrollTimer?.cancel();
    if (!_glassRealtime) {
      _glassRealtime = true;
      _glassController.startRealtimeCapture();
    }
    _glassScrollTimer = Timer(const Duration(milliseconds: 140), () {
      _glassScrollTimer = null;
      _stopGlassRealtime();
    });
  }

  void _stopGlassRealtime() {
    _glassScrollTimer?.cancel();
    _glassScrollTimer = null;
    if (_glassRealtime) {
      _glassRealtime = false;
      _glassController.stopRealtimeCapture();
    }
    _scheduleGlassCapture();
  }

  bool _handleGlassScroll(ScrollNotification notification) {
    if (_index == 1) return false;
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      _startGlassRealtime();
    } else if (notification is ScrollEndNotification) {
      _stopGlassRealtime();
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AuthRepository().resolveUserId().then((uid) {
        if (uid != null) {
          SyncEngine.instance.triggerSync(userId: uid);
        }
      }).catchError((_) {});
      _homeKey.currentState?.reload();
    }
  }

  Future<bool> _checkPendingDraft() async {
    if (_draftPrompted) return false;
    final uid = await AuthRepository().resolveUserId();
    if (uid == null || !mounted) return false;
    final draft = await LocalStore.instance.loadActiveDraft(uid);
    if (draft == null || !mounted) return false;
    _draftPrompted = true;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(S.draftRecoveryTitle),
        content: Text(
          S.draftRecoveryBody(
            S.sportName(draft.jenis),
            fmtKm(draft.distanceM),
            fmtDurasi(draft.elapsedS),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: Text(S.draftDiscard),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: Text(S.draftSaveNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('resume'),
            child: Text(S.draftResume),
          ),
        ],
      ),
    );
    if (!mounted) return true;
    switch (choice) {
      case 'resume':
        setState(() {
          _resumedDraft = draft;
          _activeSport = draft.jenis;
          _activeGoal = null;
          _activeChallengeIds = null;
          _index = 1;
        });
        break;
      case 'save':
        final rec = RunRecorder();
        try {
          rec.restoreDraft(draft);
          final summary = await rec.finish();
          await _homeKey.currentState?.reload();
          if (summary != null && mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RunFinishScreen(
                  summary: summary,
                  isHistoryDetail: true,
                  aktivitasId: summary.aktivitasId,
                  title: S.sportName(summary.jenis),
                ),
              ),
            );
            await _homeKey.currentState?.reload();
          }
        } finally {
          rec.dispose();
        }
        break;
      case 'discard':
        await LocalStore.instance.discardDraft(draft.id);
        break;
    }
    return true;
  }

  void _onPillTap(int i) {
    if (i == _index) {
      if (i == 0) {
        _resumedDraft = null;
        _homeKey.currentState?.reload();
      }
      return;
    }
    if (i == 1) _stopGlassRealtime();
    setState(() {
      if (_index != 1 && (_tabHistory.isEmpty || _tabHistory.last != _index)) {
        _tabHistory.add(_index);
        if (_tabHistory.length > 12) _tabHistory.removeAt(0);
      }
      if (_index == 1 && i != 1) {
        _activeChallengeIds = null;
      }
      if (i == 0) {
        _resumedDraft = null;
        _homeKey.currentState?.reload();
      }
      _index = i;
    });
    if (i != 1) _scheduleGlassCapture();
  }

  void _goBackFromTab() {
    if (_tabHistory.isNotEmpty) {
      final prev = _tabHistory.removeLast();
      if (prev == 1) _stopGlassRealtime();
      setState(() {
        if (_index == 1 && prev != 1) _activeChallengeIds = null;
        _resumedDraft = null;
        _index = prev;
      });
      if (prev == 0) {
        _homeKey.currentState?.reload();
      }
      if (prev != 1) _scheduleGlassCapture();
      return;
    }
    if (_index != 0) {
      setState(() {
        if (_index == 1) _activeChallengeIds = null;
        _resumedDraft = null;
        _index = 0;
      });
      _homeKey.currentState?.reload();
      _scheduleGlassCapture();
    }
  }

  void _handleShellBack() {
    if (_index != 0 || _tabHistory.isNotEmpty) {
      HapticFeedback.lightImpact();
      _goBackFromTab();
      return;
    }
    final now = DateTime.now();
    if (_lastBackAt == null ||
        now.difference(_lastBackAt!) > const Duration(seconds: 2)) {
      _lastBackAt = now;
      HapticFeedback.lightImpact();
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(S.pressBackAgainToExit),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    SystemNavigator.pop();
  }

  void _goHistory() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const HistoryScreen()))
      .then((_) {
        _homeKey.currentState?.reload();
        _scheduleGlassCapture();
      });

  void _goSetup({String? initialSport}) => Navigator.of(context)
      .push(
        MaterialPageRoute(
          builder: (_) => RunSetupScreen(
            initialSport: initialSport,
            onStartWithChallenges: (sport, goal, challengeIds) {
              Navigator.of(context).pop();
              _stopGlassRealtime();
              setState(() {
                if (_index != 1 &&
                    (_tabHistory.isEmpty || _tabHistory.last != _index)) {
                  _tabHistory.add(_index);
                  if (_tabHistory.length > 12) _tabHistory.removeAt(0);
                }
                _resumedDraft = null;
                _activeSport = sport;
                _activeGoal = goal;
                _activeChallengeIds = challengeIds;
                _index = 1;
              });
            },
            onStartWithConfig: (sport, goal) {
              Navigator.of(context).pop();
              _stopGlassRealtime();
              setState(() {
                if (_index != 1 &&
                    (_tabHistory.isEmpty || _tabHistory.last != _index)) {
                  _tabHistory.add(_index);
                  if (_tabHistory.length > 12) _tabHistory.removeAt(0);
                }
                _resumedDraft = null;
                _activeSport = sport;
                _activeGoal = goal;
                _activeChallengeIds = null;
                _index = 1;
              });
            },
            onStart: () {
              Navigator.of(context).pop();
              _stopGlassRealtime();
              setState(() {
                if (_index != 1 &&
                    (_tabHistory.isEmpty || _tabHistory.last != _index)) {
                  _tabHistory.add(_index);
                  if (_tabHistory.length > 12) _tabHistory.removeAt(0);
                }
                _resumedDraft = null;
                _activeChallengeIds = null;
                _index = 1;
              });
            },
          ),
        ),
      )
      .then((_) => _scheduleGlassCapture());

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness != null && _lastBrightness != brightness) {
      _scheduleGlassCapture();
    }
    _lastBrightness = brightness;

    final pages = [
      HomeScreen(
        key: _homeKey,
        onSeeTeams: () => _onPillTap(2),
        onSeeHistory: _goHistory,
        onSeeLeaderboard: () => _onPillTap(3),
        onStartSport: (sport) => _goSetup(initialSport: sport),
        onContentUpdated: _scheduleGlassCapture,
      ),
      // Tracker gets the full screen: nav pill hidden (it covered PAUSE),
      // back button returns to the previous tab instead. Mounted only when active.
      if (_index == 1)
        RunTrackerScreen(
          onBack: _goBackFromTab,
          sportType: _activeSport,
          goal: _activeGoal,
          initialDraft: _resumedDraft,
          initialChallengeIds: _activeChallengeIds,
        )
      else
        const SizedBox.shrink(),
      TeamsScreen(onBack: _goBackFromTab),
      LeaderboardScreen(onBack: _goBackFromTab),
    ];
    final w = MediaQuery.sizeOf(context).width;
    if (w >= Breakpoints.expanded) {
      if (_glassRealtime) {
        _glassRealtime = false;
        _glassScrollTimer?.cancel();
        _glassScrollTimer = null;
        _glassController.stopRealtimeCapture();
      }
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleShellBack();
        },
        child: Scaffold(
          body: Row(
            children: [
              _PacerNavRail(
                index: _index,
                onTap: _onPillTap,
                onStart: () => _goSetup(),
              ),
              Expanded(child: _AnimatedTabStack(index: _index, children: pages)),
            ],
          ),
        ),
      );
    }
    // Floating pill: fluid 377→480, capped at ~480 AND at the viewport
    // (minus side margin) so it never overflows narrow screens.
    var pillW = fluid(w, 377, 480);
    if (pillW > w - 16) pillW = w - 16;
    final pillScale = pillW / 377;
    final tabBackdrop = NotificationListener<ScrollNotification>(
      onNotification: _handleGlassScroll,
      child: _AnimatedTabStack(index: _index, children: pages),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleShellBack();
      },
      child: Scaffold(
        body: LiquidGlassView(
          controller: _glassController,
          pixelRatio: _index == 1 ? 0.5 : 0.85,
          realTimeCapture: false,
          refreshRate: LiquidGlassRefreshRate.high,
          useSync: false,
          batch: false,
          backgroundWidget: tabBackdrop,
          child: _index == 1
              ? null
              : Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: pillW,
                      height: 80.7 * pillScale,
                      // Pill is authored at fixed 377x80.7 design size; the
                      // FittedBox scales it uniformly (aspect ratios match, so
                      // contain == exact proportional scale).
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: PacerGlassScope(
                          hasBackdropView: true,
                          clarity: 0.85,
                          child: BottomNavPill(
                            index: _index,
                            onTap: _onPillTap,
                            onStart: () => _goSetup(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _AnimatedTabStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _AnimatedTabStack({required this.index, required this.children});

  @override
  State<_AnimatedTabStack> createState() => _AnimatedTabStackState();
}

class _AnimatedTabStackState extends State<_AnimatedTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1.0,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.02),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void didUpdateWidget(covariant _AnimatedTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _ctrl.value = 1.0;
      } else {
        _ctrl.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}

/// Extended NavigationRail for expanded widths — dark brand surface, lime
/// selected icons, central START circle as the leading action.
class _PacerNavRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onStart;
  const _PacerNavRail({
    required this.index,
    required this.onTap,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final dark = scheme.isDark;
    final selFg = dark ? scheme.accent : const Color(0xFF102A43);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.navBar,
        border: Border(right: BorderSide(color: scheme.groupedDivider)),
      ),
      child: NavigationRail(
        extended: true,
        minExtendedWidth: 220,
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.brandAccent.withValues(alpha: dark ? 0.22 : 0.62),
        unselectedIconTheme: IconThemeData(color: scheme.navIcon),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.navIcon,
          fontWeight: FontWeight.w500,
        ),
        selectedIconTheme: IconThemeData(color: selFg),
        selectedLabelTextStyle: TextStyle(
          color: selFg,
          fontWeight: FontWeight.w700,
        ),
        selectedIndex: index,
        onDestinationSelected: onTap,
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: PacerGlassPress(
            radius: 36,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onStart();
              },
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF5CE7FF),
                      PacerColors.primary,
                      Color(0xFF00A6CE),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PacerColors.primary.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'START',
                    style: PacerText.fugazBrand.copyWith(
                      fontSize: 19,
                      letterSpacing: 0.8,
                      color: const Color(0xFF0B132B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        destinations: [
          NavigationRailDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: selFg),
            label: Text(S.home),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.directions_run_outlined),
            selectedIcon: Icon(Icons.directions_run, color: selFg),
            label: Text(S.running),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups, color: selFg),
            label: Text(S.teams),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard, color: selFg),
            label: Text(S.leaderboard),
          ),
        ],
      ),
    );
  }
}

class _AssignedChallengeBanner extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;
  const _AssignedChallengeBanner({
    required this.notification,
    required this.onDismiss,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return PacerSurface(
      key: const ValueKey('assigned_challenge_banner'),
      width: double.infinity,
      radius: PacerRadii.md,
      borderColor: PacerColors.primary.withValues(alpha: 0.48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PacerColors.primary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flag_circle_outlined,
              size: 20,
              color: scheme.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: scheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: scheme.bodyGray),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(8),
                  child: Text(
                    S.viewChallenge,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: Icon(Icons.close, size: 18, color: scheme.muted),
          ),
        ],
      ),
    );
  }
}

class _WeeklyStatMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _WeeklyStatMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.5, color: scheme.accent),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: scheme.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final PartisipasiChallenge? participation;
  final String? teamName;
  final VoidCallback onTap;

  const _HomeChallengeCard({
    required this.challenge,
    required this.participation,
    required this.teamName,
    required this.onTap,
  });

  IconData _sportIcon(String? jenis) {
    final j = (jenis ?? '').toLowerCase();
    if (j.contains('sepeda') || j.contains('cycl')) {
      return Icons.directions_bike_rounded;
    }
    if (j.contains('jalan') || j.contains('walk')) {
      return Icons.nordic_walking_rounded;
    }
    if (j.contains('jog')) {
      return Icons.directions_walk_rounded;
    }
    return Icons.directions_run_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final title = challenge.judul?.trim().isNotEmpty == true
        ? challenge.judul!.trim()
        : '${S.sportName(challenge.jenis)} • ${S.challengeTargetSummary(challenge.targetNilai, challenge.targetSatuan)}';
    final scopeText = challenge.isTeamChallenge
        ? (teamName != null && teamName!.isNotEmpty
              ? '${S.teamChallengeTag} • $teamName'
              : S.teamChallengeTag)
        : S.soloChallengeTag;
    final windowText = challenge.waktuSelesai != null
        ? fmtDate(challenge.waktuSelesai)
        : S.challengeOpenEnded;
    final pct = participation != null
        ? progressPercent(participation!.progressNilai, challenge.targetNilai)
        : null;
    final isDone = participation?.berhasil == true;
    final accent = isDone
        ? PacerColors.primary
        : (challenge.isTeamChallenge
              ? scheme.brandAccent
              : PacerColors.primary);

    return PacerSurface(
      width: double.infinity,
      radius: PacerRadii.lg,
      padding: const EdgeInsets.all(16),
      borderColor: challenge.isTeamChallenge
          ? scheme.brandAccent.withValues(alpha: dark ? 0.30 : 0.48)
          : scheme.border,
      onTap: onTap,
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: challenge.isTeamChallenge
                              ? scheme.brandAccent.withValues(
                                  alpha: dark ? 0.16 : 0.25,
                                )
                              : scheme.searchBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: challenge.isTeamChallenge
                                ? scheme.brandAccent.withValues(alpha: 0.35)
                                : scheme.border.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          scopeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: challenge.isTeamChallenge && dark
                                ? scheme.brandAccent
                                : scheme.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.searchBg.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 12,
                            color: scheme.muted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              windowText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: scheme.muted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: dark ? 0.16 : 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Icon(
                      _sportIcon(challenge.jenis),
                      size: 20,
                      color:
                          accent == PacerColors.lime && !dark
                          ? PacerColors.navy
                          : accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (pct != null && participation != null) ...[
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: scheme.searchBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (pct / 100.0).clamp(0.04, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDone
                              ? [PacerColors.primary, const Color(0xFF38BDF8)]
                              : [
                                  scheme.brandAccent,
                                  Color.lerp(
                                    scheme.brandAccent,
                                    PacerColors.neon,
                                    0.35,
                                  )!,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${S.challengeTargetSummary(participation!.progressNilai, challenge.targetSatuan)} / ${S.challengeTargetSummary(challenge.targetNilai, challenge.targetSatuan)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.muted,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isDone ? PacerColors.primary : scheme.brandAccent)
                                .withValues(alpha: dark ? 0.16 : 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${pct.round()}%',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDone
                              ? PacerColors.primary
                              : (dark ? scheme.brandAccent : scheme.ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${S.sportName(challenge.jenis)} • ${S.challengeTargetSummary(challenge.targetNilai, challenge.targetSatuan)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.muted,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.brandAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        S.join,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onBrandAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
  }
}

class _HomeExploreClubsCard extends StatelessWidget {
  final double width;
  final VoidCallback onTap;

  const _HomeExploreClubsCard({required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      height: 150,
      child: PacerSurface(
        radius: PacerRadii.lg,
        onTap: onTap,
        borderColor: scheme.accent.withValues(alpha: dark ? 0.36 : 0.45),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              scheme.card,
              scheme.accent,
              dark ? 0.12 : 0.08,
            )!,
            Color.lerp(scheme.scaffold, scheme.card, 0.55)!,
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: PacerTrackLinesPainter(
                    color: scheme.accent.withValues(alpha: dark ? 0.08 : 0.06),
                    count: 3,
                  ),
                ),
              ),
            ),
                Positioned(
                  right: -12,
                  top: -12,
                  child: IgnorePointer(
                    child: Icon(
                      Icons.explore_rounded,
                      size: 80,
                      color: scheme.accent.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: scheme.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scheme.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.explore_outlined,
                          size: 20,
                          color: scheme.accent,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        S.findClubsCta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: scheme.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              S.seeAll,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: scheme.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
