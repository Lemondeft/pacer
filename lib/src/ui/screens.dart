import 'package:flutter/material.dart';
import 'package:pacer/core/responsive/responsive.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/aktivitas/activity_repository.dart';
import 'package:pacer/src/auth/auth_repository.dart';
import 'package:pacer/src/teams/team_model.dart';
import 'package:pacer/src/teams/team_repository.dart';
import 'package:pacer/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_strings.dart';
import 'app_theme.dart';
import 'format.dart';
import 'more_screens.dart';
import 'widgets.dart';

/// Figma LOADING SCREEN: the one PacerLogo + blue progress rectangle 218x18 r2.
/// Centered splash, capped at 480 — no scaling, no stretch.
class LoadingScreen extends StatelessWidget {
  final VoidCallback onDone;
  const LoadingScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PacerLogo(width: 160, fontSize: 44),
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
                        color: PacerColors.slate200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 218 * value,
                        height: 18,
                        decoration: BoxDecoration(
                          color: PacerColors.primary,
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
    return Scaffold(
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          centerContent: true,
          child: Column(
            children: [
              const PacerLogo(width: 198, fontSize: 40),
              const SizedBox(height: 24),
              Text(
                S.appTagline,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 69,
                child: ElevatedButton(
                  onPressed: onSignIn,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Text(S.signIn),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 69,
                child: OutlinedButton(
                  onPressed: onLogIn,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      width: 2,
                      color: PacerColors.primary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Text(S.logIn),
                ),
              ),
            ],
          ),
        ),
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
              Text(S.createAccount, style: PacerText.authTitle),
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
              const Divider(color: PacerColors.border, height: 1),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  S.orSignUpWith,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: PacerColors.border),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_outlined,
                    color: PacerColors.ink,
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

/// Figma HOME: PACER header + streak hero + History cards + Pacer Teams.
/// compact: single column. medium: streak full width, history + teams in
/// 2 columns. expanded: streak pane left, history + teams pane right.
///
/// Live data when signed in (streak row, own activities, own teams);
/// Figma mock cards when in demo mode or while loading.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onSeeTeams;
  final VoidCallback? onSeeHistory;
  const HomeScreen({super.key, this.onSeeTeams, this.onSeeHistory});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Live home data; every field null in demo mode (keeps the mock cards).
class _HomeData {
  final List<Activity>? activities;
  final int? streak;
  final List<Team>? teams;
  final String? initials;
  const _HomeData({this.activities, this.streak, this.teams, this.initials});
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeData? _data;

  @override
  void initState() {
    super.initState();
    // _load never throws (demo fallback inside); refresh cards on arrival.
    _load().then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  bool get _backend {
    try {
      supa;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<_HomeData> _load() async {
    try {
      if (!_backend) return const _HomeData();
      if (supa.auth.currentUser == null) return const _HomeData();
      final repo = ActivityRepository();
      final activities = await repo.listActivities(limit: 5);
      final streak = await repo.getStreak();
      final teams = await TeamRepository().myTeams();
      final profile = await AuthRepository().getProfile();
      return _HomeData(
        activities: activities,
        streak: streak?.berjalan,
        teams: teams,
        initials: initialsOf(profile?.nama),
      );
    } catch (_) {
      return const _HomeData();
    }
  }

  Widget _header(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const FiturScreen())),
            icon: const Icon(Icons.menu, size: 32),
          ),
          Expanded(
            child: Center(
              // One consistent logo across the app.
              child: PacerLogo(width: 84, fontSize: 18),
            ),
          ),
          // Logged-in user's initials (Figma spec). Tap → Account.
          // 48px tap target around the 42px visual.
          GestureDetector(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AccountScreen())),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: InitialAvatar(_data?.initials ?? '?', size: 42),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _streak() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: S.streaks),
        const SizedBox(height: 8),
        StreakCard(count: _data?.streak),
      ],
    );
  }

  Widget _history() {
    String cap(String j) =>
        j.isEmpty ? j : '${j[0].toUpperCase()}${j.substring(1)}';
    final activities = _data?.activities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.onSeeHistory,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.history,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 20,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (activities == null) ...[
          const RunSessionCard(),
          const SizedBox(height: 16),
          const RunSessionCard(
            title: 'Sunday Morning Run',
            date: '14/7/2024',
            time: '1.00.00',
            pace: "4'00''",
            distance: '15,00 Km',
            limePill: true,
          ),
        ] else if (activities.isEmpty)
          const PacerEmptyState(
            'Belum ada aktivitas. Mulai lari pertamamu!',
            icon: Icons.directions_run_outlined,
          )
        else
          for (final a in activities.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RunSessionCard(
                title: cap(a.jenis),
                date: fmtDate(a.mulaiAt),
                time: fmtDurasi(a.durasiS),
                pace: fmtPace(a.durasiS, a.jarakM),
                distance: fmtKm(a.jarakM),
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
                  if (teams == null) ...[
                    TeamCard(
                      name: 'JakBar Pacer',
                      location: 'Jakarta Barat, Indonesia',
                      width: cardW,
                    ),
                    const SizedBox(width: 19),
                    TeamCard(
                      name: 'Tangerang Runners',
                      location: 'Tangerang, Indonesia',
                      width: cardW,
                    ),
                  ] else if (teams.isEmpty)
                    const PacerEmptyState(
                      'Belum gabung tim mana pun.',
                      icon: Icons.groups_outlined,
                    )
                  else
                    for (var i = 0; i < teams.length; i++) ...[
                      if (i > 0) const SizedBox(width: 19),
                      TeamCard(name: teams[i].nama, width: cardW),
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
        // Bottom clearance for the floating nav pill (nav height + margin).
        padding: const EdgeInsets.only(bottom: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                return switch (screenSizeOf(c.maxWidth)) {
                  ScreenSize.compact => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _streak(),
                      const SizedBox(height: 8),
                      _history(),
                      const SizedBox(height: 32),
                      _teams(),
                    ],
                  ),
                  ScreenSize.medium => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _streak(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _history()),
                          const SizedBox(width: 24),
                          Expanded(child: _teams()),
                        ],
                      ),
                    ],
                  ),
                  ScreenSize.expanded => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _streak()),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _onPillTap(int i) => setState(() => _index = i);
  void _goHistory() =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  void _goSetup() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => RunSetupScreen(
        onStart: () {
          Navigator.of(context).pop();
          setState(() => _index = 1);
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onSeeTeams: () => _onPillTap(2), onSeeHistory: _goHistory),
      // Tracker gets the full screen: nav pill hidden (it covered PAUSE),
      // back button returns to Home instead.
      RunTrackerScreen(onBack: () => _onPillTap(0)),
      const TeamsScreen(),
      const LeaderboardScreen(),
    ];
    final w = MediaQuery.sizeOf(context).width;
    if (w >= Breakpoints.expanded) {
      return Scaffold(
        body: Row(
          children: [
            _PacerNavRail(index: _index, onTap: _onPillTap, onStart: _goSetup),
            Expanded(child: pages[_index]),
          ],
        ),
      );
    }
    // Floating pill: fluid 377→480, capped at ~480 AND at the viewport
    // (minus side margin) so it never overflows narrow screens.
    var pillW = fluid(w, 377, 480);
    if (pillW > w - 16) pillW = w - 16;
    final pillScale = pillW / 377;
    return Scaffold(
      body: Stack(
        children: [
          pages[_index],
          if (_index != 1)
            Positioned(
              left: 0,
              right: 0,
              // Sticks low: small margin above the bottom edge.
              bottom: 16,
              child: Center(
                child: SizedBox(
                  width: pillW,
                  height: 80.7 * pillScale,
                  // Pill is authored at fixed 377x80.7 design size; the
                  // FittedBox scales it uniformly (aspect ratios match, so
                  // contain == exact proportional scale).
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: BottomNavPill(
                      index: _index,
                      onTap: _onPillTap,
                      onStart: _goSetup,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
    return NavigationRail(
      extended: true,
      minExtendedWidth: 220,
      backgroundColor: PacerColors.bottomBar,
      selectedIndex: index,
      onDestinationSelected: onTap,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: GestureDetector(
          onTap: onStart,
          child: Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: PacerColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'START',
                style: PacerText.fugazBrand.copyWith(
                  fontSize: 20,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home, color: PacerColors.lime),
          label: Text(S.home),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.directions_run_outlined),
          selectedIcon: const Icon(
            Icons.directions_run,
            color: PacerColors.lime,
          ),
          label: Text(S.running),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.groups_outlined),
          selectedIcon: const Icon(Icons.groups, color: PacerColors.lime),
          label: Text(S.teams),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.leaderboard_outlined),
          selectedIcon: const Icon(Icons.leaderboard, color: PacerColors.lime),
          label: Text(S.leaderboard),
        ),
      ],
    );
  }
}
