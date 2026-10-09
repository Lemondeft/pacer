import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'app_theme.dart';
import 'more_screens.dart';
import 'widgets.dart';

/// Figma LOADING SCREEN: the one PacerLogo + blue progress rectangle 218x18 r2.
class LoadingScreen extends StatelessWidget {
  final VoidCallback onDone;
  const LoadingScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
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
    );
  }
}

/// Figma GET STARTED: "Pacer, siap membantu!" + Sign In filled 357x69 + Log In outlined.
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
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
                  width: 357,
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
                  width: 357,
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
      ),
    );
  }
}

/// Figma SIGN IN: "Create an account" 40 + 4 fields 315x50 + Sign In + divider + icon row.
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
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 38),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const PageHeader(),
              const SizedBox(height: 16),
              Text(S.createAccount, style: PacerText.authTitle),
              const SizedBox(height: 28),
              AuthField(hint: S.username, icon: Icons.person_outline),
              const SizedBox(height: 16),
              AuthField(
                hint: S.email,
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AuthField(
                hint: S.password,
                icon: Icons.lock_outline,
                obscure: true,
              ),
              const SizedBox(height: 16),
              AuthField(
                hint: S.confirmPassword,
                icon: Icons.lock_outline,
                obscure: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: PacerColors.errorRed,
                    fontSize: 15,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Center(
                child: PrimaryButton(
                  label: S.signIn,
                  onPressed: () {
                    setState(() => _error = null);
                    widget.onSubmitted();
                  },
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: SizedBox(
                  width: 289,
                  child: Divider(color: Colors.black, height: 1),
                ),
              ),
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

/// Figma HOME: PACER header + streak hero + History 2 cards + Pacer Teams 2 cards + floating pill nav.
class HomeScreen extends StatelessWidget {
  final VoidCallback? onSeeTeams;
  final VoidCallback? onSeeHistory;
  const HomeScreen({super.key, this.onSeeTeams, this.onSeeHistory});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FiturScreen()),
                    ),
                    icon: const Icon(Icons.menu, size: 32),
                  ),
                  Expanded(
                    child: Center(
                      // One consistent logo across the app.
                      child: PacerLogo(width: 84, fontSize: 18),
                    ),
                  ),
                  // Logged-in user's initials (Figma spec). Tap → Account.
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountScreen()),
                    ),
                    child: const InitialAvatar('RP', size: 42),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(title: S.streaks),
            const SizedBox(height: 8),
            const Center(child: StreakCard()),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onSeeHistory,
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
            const SizedBox(height: 8),
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
            const SizedBox(height: 32),
            SectionHeader(title: S.pacerTeams, onSeeAll: onSeeTeams),
            const SizedBox(height: 20),
            SizedBox(
              height: 133,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                children: const [
                  TeamCard(
                    name: 'JakBar Pacer',
                    location: 'Jakarta Barat, Indonesia',
                  ),
                  SizedBox(width: 19),
                  TeamCard(
                    name: 'Tangerang Runners',
                    location: 'Tangerang, Indonesia',
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

/// Shell with floating dark pill nav (4 icons + central START).
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
    return Scaffold(
      body: Stack(
        children: [
          pages[_index],
          if (_index != 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 54,
              child: Center(
                child: BottomNavPill(
                  index: _index,
                  onTap: _onPillTap,
                  onStart: _goSetup,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
