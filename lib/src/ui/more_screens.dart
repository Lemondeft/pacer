import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pacer/supabase.dart';

import 'app_strings.dart';
import 'app_theme.dart';
import 'screens.dart';
import 'widgets.dart';

/// Figma LOG IN: "Welcome runners !" single line + Username/Password + Log In + divider.
class LoginScreen extends StatelessWidget {
  final VoidCallback onLoggedIn;
  final VoidCallback? onBack;
  const LoginScreen({super.key, required this.onLoggedIn, this.onBack});

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
              Text(
                S.welcomeRunners,
                style: PacerText.authTitle.copyWith(fontSize: 34),
              ),
              const SizedBox(height: 32),
              AuthField(hint: S.username, icon: Icons.person_outline),
              const SizedBox(height: 16),
              AuthField(
                hint: S.password,
                icon: Icons.lock_outline,
                obscure: true,
              ),
              const SizedBox(height: 28),
              Center(
                child: PrimaryButton(label: S.logIn, onPressed: onLoggedIn),
              ),
              const SizedBox(height: 28),
              const Center(
                child: SizedBox(
                  width: 289,
                  child: Divider(color: Colors.black, height: 1),
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

/// Figma "Pilih Olahraga" pre-run setup.
class RunSetupScreen extends StatefulWidget {
  final VoidCallback onStart;
  const RunSetupScreen({super.key, required this.onStart});

  @override
  State<RunSetupScreen> createState() => _RunSetupScreenState();
}

class _RunSetupScreenState extends State<RunSetupScreen> {
  int _goal = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 65, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const BackButton(color: PacerColors.ink),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.chooseSport,
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        height: 32 / 24,
                        color: const Color(0xFF181C22),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S.setupSubtitle,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14,
                        height: 20 / 14,
                        color: const Color(0xFF444749),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 350,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(width: 2, color: Colors.black),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.directions_run,
                            size: 21,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.outdoorRun,
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                height: 24 / 16,
                                color: const Color(0xFF181C22),
                              ),
                            ),
                            Text(
                              S.gpsDistanceTempo,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 12,
                                height: 16 / 12,
                                color: const Color(0xFF444749),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 350,
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E8F1))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          S.sessionGoal,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            height: 16 / 12,
                            color: const Color(0xFF444749),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '5.0 km',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12,
                            color: const Color(0xFF444749),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final g in const [
                          'Bebas',
                          '3 km',
                          '5 km',
                          '30 mnt',
                        ])
                          GestureDetector(
                            onTap: () => setState(
                              () => _goal = [
                                'Bebas',
                                '3 km',
                                '5 km',
                                '30 mnt',
                              ].indexOf(g),
                            ),
                            child: GoalChip(
                              label: g,
                              selected:
                                  _goal ==
                                  [
                                    'Bebas',
                                    '3 km',
                                    '5 km',
                                    '30 mnt',
                                  ].indexOf(g),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 350,
                height: 52,
                child: ElevatedButton(
                  onPressed: widget.onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                  child: Text(
                    S.startRun,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      height: 24 / 16,
                    ),
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

/// Figma tracker: full-bleed map overlay, Fugaz 78 distance, GPS pill, 3 stats, 98 circles.
class RunTrackerScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const RunTrackerScreen({super.key, this.onBack});

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen> {
  bool _running = false;
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return RunFinishScreen(onBack: () => setState(() => _finished = false));
    }
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: CustomPaint(painter: _RouteGridPainter()),
            ),
          ),
          SafeArea(
            // Design canvas is 393x808 (Figma 393x852 minus status bar).
            // Scale it to any screen width so exact geometry (98px circles,
            // Fugaz-78 distance) never crowds or clips on narrow phones.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 393,
                height: 808,
                child: Stack(
                  children: [
                    Positioned(
                      left: 32,
                      top: 85 - 44,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed:
                              widget.onBack ??
                              () => Navigator.maybePop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: PacerColors.ink,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(right: 32, top: 85 - 44, child: GpsPill()),
                    Positioned(
                      left: 160,
                      top: 102 - 44,
                      child: Container(
                        width: 83,
                        height: 10,
                        decoration: BoxDecoration(
                          color: PacerColors.ink.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 79,
                      top: 210 - 44,
                      child: Text('00,00', style: PacerText.giantNum(78)),
                    ),
                    Positioned(
                      left: 149,
                      top: 320 - 44,
                      child: Text(
                        S.distanceKm,
                        style: TextStyle(
                          fontWeight: FontWeight.w300,
                          fontSize: 15,
                          color: Color(0x99000000),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 38,
                      top: 589 - 44,
                      child: SizedBox(
                        width: 317,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TrackerStatColumn(
                              avatarSize: 20,
                              initials: 'A',
                              value: "0'00''",
                              label: S.avgPace,
                            ),
                            Spacer(),
                            TrackerStatColumn(
                              avatarSize: 25,
                              initials: 'B',
                              value: '00.00',
                              label: S.duration,
                            ),
                            Spacer(),
                            TrackerStatColumn(
                              avatarSize: 30,
                              initials: 'C',
                              value: '0 kcal',
                              label: S.calories,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 32,
                      right: 32,
                      top: 690 - 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const MapCircleButton(),
                          if (!_running)
                            CircleAction(
                              label: S.pause,
                              bg: PacerColors.lime,
                              fg: PacerColors.ink,
                              onTap: () => setState(() => _running = true),
                            )
                          else
                            CircleAction(
                              label: S.continueLabel,
                              bg: Colors.white,
                              fg: PacerColors.ink,
                              labelSize: 14,
                              onTap: () => setState(() => _running = false),
                            ),
                          if (_running)
                            CircleAction(
                              label: S.finish,
                              bg: PacerColors.ink,
                              fg: PacerColors.lime,
                              onTap: () => setState(() => _finished = true),
                            )
                          else
                            const SizedBox(width: 98),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final route = Paint()
      ..color = PacerColors.lime
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.3, size.height * 0.25)
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.3,
        size.width * 0.55,
        size.height * 0.45,
      )
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.6,
        size.width * 0.7,
        size.height * 0.62,
      );
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Figma RUNNING FINISH: lime 329x92 summary + four 329x75 metric cards.
class RunFinishScreen extends StatelessWidget {
  final String? title;
  final bool isHistoryDetail;
  final VoidCallback? onBack;
  const RunFinishScreen({
    super.key,
    this.title,
    this.isHistoryDetail = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (S.stepLength, S.distanceBetweenSteps, '1,00', 'ft'),
      (S.calories, S.totalEnergyBurned, '854', 'kcal'),
      (S.cadence, S.stepsPerMinute, '212', 'spm'),
      (S.elevationGain, S.totalHeightClimb, '100', 'ft'),
    ];
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: CustomPaint(painter: _RouteGridPainter()),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 85 - 44),
                  Row(
                    children: [
                      IconButton(
                        onPressed: onBack ?? () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 32,
                          color: PacerColors.ink,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.edit,
                          size: 20,
                          color: PacerColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    title ?? S.running,
                    style: const TextStyle(
                      fontSize: 24,
                      color: PacerColors.ink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 329,
                    height: 1,
                    color: const Color(0x40000000),
                  ),
                  if (isHistoryDetail) ...[
                    const SizedBox(height: 28),
                    Container(
                      width: 161,
                      height: 158,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: PacerColors.lime, width: 5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: PacerColors.ink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ] else
                    const SizedBox(height: 216),
                  SummaryLimeCard(
                    distance: isHistoryDetail ? '3,00 Km' : '0,00 Km',
                    duration: isHistoryDetail ? '15.00' : '00.00',
                    pace: isHistoryDetail ? "5'00''" : "0'00''",
                  ),
                  const SizedBox(height: 18),
                  for (final m in metrics)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: MetricCard(
                        title: m.$1,
                        sub: m.$2,
                        value: isHistoryDetail ? m.$3 : null,
                        unit: isHistoryDetail ? m.$4 : null,
                      ),
                    ),
                  if (isHistoryDetail) ...[
                    const SizedBox(height: 9),
                    LimeActionBar(
                      S.done,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Center(
                      child: LimeActionBar(
                        S.done,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma CLUBS list: Outfit 400/32 title + 358 search + 329x133 cards + buat-teams pill.
class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.findTeamsNearby,
                style: TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 12),
              const SearchField(),
              const SizedBox(height: 16),
              const TeamCard(
                name: 'JakBar Pacer',
                location: 'Jakarta Barat, Indonesia',
                width: 329,
              ),
              const SizedBox(height: 12),
              const TeamCard(
                name: 'Tangerang Runners',
                location: 'Tangerang, Indonesia',
                width: 329,
              ),
              const SizedBox(height: 12),
              const TeamCard(
                name: 'Jakarta Night Striders',
                location: 'GBK Senayan • Gate 5',
                width: 329,
              ),
              const SizedBox(height: 12),
              const TeamCard(
                name: 'Senayan Squad',
                location: 'Jakarta Selatan, Indonesia',
                width: 329,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PersyaratanScreen()),
                ),
                child: Container(
                  width: 329,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: PacerColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(S.createTeam,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChallengeListScreen(),
                        ),
                      ),
                      child: Text(S.challenge),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChatScreen()),
                      ),
                      child: Text(S.teamChat),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(S.nearestGroupRun,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PacerColors.runCardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saturday Sunrise 10K',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'SABTU, 06:00 WIB • GBK Senayan',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _JoinButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.demoJoinSent)),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: PacerColors.joinYellow,
        foregroundColor: Colors.black,
        minimumSize: const Size(90, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(S.join),
    );
  }
}

/// Figma leaderboard podium page + rows 4-8 with lime-highlighted you-row.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  static const _rows = [
    ('Reza Pratama', '36.4 Km'),
    ('Indra Wijaya', '34.1 Km'),
    ('Siti Rahma (You)', '31.0 Km'),
    ('Budi Santoso', '28.5 Km'),
    ('Clara Angelica', '25.9 Km'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.teamsLeaderboard, style: PacerText.pageTitle),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _podium(
                    'A. Nugroho',
                    '42.1',
                    68,
                    PacerColors.podiumGray,
                    rank: 2,
                    medal: PacerColors.medalSilver,
                  ),
                  _podium(
                    'D. Kusuma',
                    '48.2',
                    89,
                    PacerColors.medalGold,
                    rank: 1,
                    medal: PacerColors.medalGold,
                  ),
                  _podium(
                    'F. Sanjaya',
                    '39.5',
                    63,
                    PacerColors.medalBronze,
                    rank: 3,
                    medal: PacerColors.medalBronze,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _rows.length; i++)
                Container(
                  width: 358,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _rows[i].$1.contains('(You)')
                          ? PacerColors.lime
                          : PacerColors.border,
                    ),
                    color: _rows[i].$1.contains('(You)')
                        ? PacerColors.lime.withValues(alpha: 0.1)
                        : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${i + 4}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _rows[i].$1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        _rows[i].$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StatisticScreen(),
                        ),
                      ),
                      child: const Text('Statistik'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StreaksScreen(),
                        ),
                      ),
                      child: Text(S.streaks),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _podium(
    String name,
    String km,
    double h,
    Color bar, {
    required int rank,
    required Color medal,
  }) {
    // Bronze bar is dark — white badge text there; dark text on gold/silver.
    final badgeFg = medal == PacerColors.medalBronze
        ? Colors.white
        : Colors.black;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          InitialAvatar(name.substring(0, 1)),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          Text(
            '$km Km',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          Container(
            width: 57,
            height: h,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 35,
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$rank',
              style: TextStyle(fontWeight: FontWeight.w800, color: badgeFg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma HISTORY: "46,00" Fugaz 88 + desc row + Monday cards.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.history, style: PacerText.pageTitle),
              Text('46,00', style: PacerText.giantNum(88)),
              const Text(
                'Kilometer',
                style: TextStyle(fontWeight: FontWeight.w300, fontSize: 24),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text(
                    '4 Run   ',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 24),
                  ),
                  Text(
                    '5,50 Average Pace   ',
                    style: TextStyle(fontWeight: FontWeight.w300, fontSize: 20),
                  ),
                  Text(
                    '4.10.00 Time',
                    style: TextStyle(fontWeight: FontWeight.w300, fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RunFinishScreen(
                      title: 'Monday Morning Run',
                      isHistoryDetail: true,
                    ),
                  ),
                ),
                child: const RunSessionCard(title: 'Monday : 07.30'),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RunFinishScreen(
                      title: 'Monday Morning Run',
                      isHistoryDetail: true,
                    ),
                  ),
                ),
                child: const RunSessionCard(
                  title: 'Monday : 07.30',
                  date: '8/7/2024',
                  time: '28.40',
                  pace: "6'10''",
                  distance: '5,00 Km',
                  limePill: true,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RunFinishScreen(
                      title: 'Monday Morning Run',
                      isHistoryDetail: true,
                    ),
                  ),
                ),
                child: const RunSessionCard(
                  title: 'Monday : 07.30',
                  date: '1/7/2024',
                  time: '1.00.00',
                  pace: "4'00''",
                  distance: '15,00 Km',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma challenge detail full page.
class ChallengeDetailSheet extends StatelessWidget {
  const ChallengeDetailSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const ChallengeDetailSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.challengeDetail, style: PacerText.pageTitle),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '10 ',
                  style: PacerText.giantNum(96)
                      .copyWith(color: PacerColors.primary),
                ),
                Text('KM', style: PacerText.kmSuffix),
              ],
            ),
            Text(S.distance,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 24),
            ),
            const Text(
              'Waktu: 1,30 Jam',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 24),
            ),
            const Text(
              'Tanggal: 29-10-2009',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 24),
            ),
            const SizedBox(height: 12),
            const MapPlaceholder(
              height: 185,
              label: 'Track — placeholder bebas hak cipta',
            ),
            const SizedBox(height: 16),
            Center(
              child: LimeActionBar(
                S.startChallenge,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(S.demoChallengeStarted)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Figma ACCOUNT + About Me (minimal faithful slice).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Widget _menuRow(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: PacerColors.slate400,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: PacerColors.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              const InitialAvatar('SR', size: 99),
              const SizedBox(height: 8),
              const Text(
                'Siti Rahma',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                width: 377,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PacerColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _menuRow(
                      context,
                      label: S.email,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Demo: sitirahma@pacer.id'),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: PacerColors.border),
                    _menuRow(
                      context,
                      label: S.aboutMe,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AboutMeScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: PacerColors.border),
                    _menuRow(
                      context,
                      label: S.features,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FiturScreen()),
                      ),
                    ),
                    const Divider(height: 1, color: PacerColors.border),
                    _menuRow(
                      context,
                      label: S.language,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LanguageSettingsScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: PacerColors.border),
                    _menuRow(
                      context,
                      label: S.out,
                      onTap: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => GetStartedScreen(
                            onSignIn: () => Navigator.of(context)
                                .pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const MainShell(),
                                  ),
                                  (route) => false,
                                ),
                            onLogIn: () => Navigator.of(context)
                                .pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const MainShell(),
                                  ),
                                  (route) => false,
                                ),
                          ),
                        ),
                        (route) => false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma Statistic: map card + total + 3 stat cards.
class StatisticScreen extends StatelessWidget {
  const StatisticScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PacerColors.ink),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.statistic, style: PacerText.pageTitle),
              const SizedBox(height: 12),
              const MapPlaceholder(
                height: 160,
                label: 'Senayan Loop (3x) • Elevasi +45m',
              ),
              const SizedBox(height: 12),
              const Text(
                '3,00 Km',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 32),
              ),
              Text(S.totalRunDistance,
                style: TextStyle(fontSize: 11, color: PacerColors.slate400),
              ),
              Text(S.targetAchieved,
                style: TextStyle(
                  color: PacerColors.chipGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatCard(S.averagePace, "5'00\"", '/km')),
                  SizedBox(width: 8),
                  Expanded(child: _StatCard(S.totalTime, '15.00', 'menit')),
                  SizedBox(width: 8),
                  Expanded(child: _StatCard(S.activeCalories, '542', 'kkal')),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _StatCard(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PacerColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: PacerColors.slate400),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: PacerColors.navy,
            ),
          ),
          Text(unit, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Figma Streaks: 7-day strip + streak card.
class StreaksScreen extends StatelessWidget {
  const StreaksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PacerColors.ink),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.streaks, style: PacerText.pageTitle),
              const Text(
                'MINGGU INI • 5 dari 7 Hari',
                style: TextStyle(
                  color: PacerColors.streakBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final done = i < 4;
                  final today = i == 4;
                  return Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? PacerColors.streakBlue : Colors.white,
                          border: Border.all(
                            color: done || today
                                ? PacerColors.streakBlue
                                : PacerColors.slate200,
                            width: 2,
                          ),
                          boxShadow: today
                              ? [
                                  const BoxShadow(
                                    color: Color(0xFFFFE600),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: done
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Text(
                        days[i],
                        style: const TextStyle(
                          fontSize: 11,
                          color: PacerColors.slate400,
                        ),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Center(child: StreakCard(width: 321, height: 157)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma CHALLENGE list: 10 KM + 8 KM hero cards.
class ChallengeListScreen extends StatelessWidget {
  const ChallengeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PacerColors.ink),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.challenge, style: PacerText.pageTitle),
              const SizedBox(height: 12),
              for (final c in const [('10', '29-10-2009'), ('8', '29-10-2009')])
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => const ChallengeDetailSheet(),
                  ),
                  child: Container(
                    width: 342,
                    height: 179,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2B2B2B), PacerColors.streakBg],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          c.$1,
                          style: PacerText.giantNum(96)
                              .copyWith(color: PacerColors.primary),
                        ),
                        Text(
                          ' KM',
                          style: PacerText.kmSuffix.copyWith(fontSize: 40),
                        ),
                        const Spacer(),
                        Text(
                          c.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateChallengeScreen(),
                    ),
                  ),
                  child: Text(S.createChallenge),
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

/// Figma persyaratan club: 3 rows + setuju pill.
class PersyaratanScreen extends StatelessWidget {
  const PersyaratanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = [
      (S.activeCaptain, S.activeCaptainDesc),
      (S.min3Members, S.min3MembersDesc),
      (S.routineGroupRun, S.routineGroupRunDesc),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PacerColors.ink),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.clubRequirements,
                style: PacerText.pageTitle.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 16),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: PacerColors.lime,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Color(0xFF0B1C30),
                              ),
                            ),
                            Text(
                              r.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                color: PacerColors.formText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Center(
                child: SizedBox(
                  height: 48,
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateClubScreen(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PacerColors.lime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(S.agree),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.back),
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

/// Figma buat club form.
class CreateClubScreen extends StatelessWidget {
  const CreateClubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PacerColors.ink),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.createTeam, style: PacerText.pageTitle),
              const SizedBox(height: 12),
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PacerColors.formBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PacerColors.formBorder, width: 2),
                ),
                child: Text(S.addLogo,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Text(S.teamName),
              TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: PacerColors.formBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(S.clubFocus),
              const Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('Road Run')),
                  Chip(label: Text('Trail')),
                  Chip(label: Text('Fun Run')),
                ],
              ),
              const SizedBox(height: 12),
              Text(S.cityHQ),
              TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: PacerColors.formBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(S.communityPrivacy),
              Row(
                children: [
                  Chip(label: Text(S.publicLabel)),
                  SizedBox(width: 8),
                  Chip(label: Text(S.privateLabel)),
                ],
              ),
              const SizedBox(height: 20),
              const Center(child: LimeActionBar('Buat Teams')),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.back),
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

/// Figma buat challenge teams form.
class CreateChallengeScreen extends StatelessWidget {
  const CreateChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PacerColors.ink),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'buat challenge teams',
                style: PacerText.pageTitle.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 12),
              for (final s in [
                ('JARAK', ['3 km', '5 km', '10 km', S.other]),
                (S.durationLabel, [S.todayLabel, S.days3, S.week1]),
                (S.target, ['25 km', '30 km', '45 km', S.custom]),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: PacerColors.slate500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [for (final o in s.$2) Chip(label: Text(o))],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Center(child: LimeActionBar(S.createChallenge)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma CLUBS chat: activity bubble + sent bubble + composer.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('jakarta night stride'),
        backgroundColor: Colors.white,
        foregroundColor: PacerColors.ink,
        elevation: 1,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Chip(label: Text('Hari ini, 24 Oktober')),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Morning Warmup Run',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Garmin Sync',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Text('JARAK\n5.2 km')),
                          Expanded(child: Text("PACE\n5'15\"/k")),
                          Expanded(child: Text('WAKTU\n27:18')),
                          Expanded(child: Text('DETAK\n142 bpm')),
                        ],
                      ),
                      Text('Elevasi: +18m', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Dh8  D12  D4', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: PacerColors.chatGreen,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(2),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Siap ikut Sabtu ini!',
                      style: TextStyle(color: Color(0xFF004105)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: S.writeMessage,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(22)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.demoMessageSent)),
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: PacerColors.chatGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma About Me data card.
class AboutMeScreen extends StatelessWidget {
  const AboutMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = [
      (S.fullName, 'Siti Rahma'),
      (S.birth, '14 Mei 1996'),
      (S.gender, 'Perempuan'),
      (S.height, '170 cm'),
      (S.weight, '40 kg'),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PacerColors.ink),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.aboutMe, style: PacerText.pageTitle),
              const SizedBox(height: 12),
              Container(
                width: 350,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PacerColors.border),
                ),
                child: Column(
                  children: [
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              r.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 350,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PacerColors.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(S.editPersonalDetails,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma FITUR grid: 6 tiles, each wired to its screen.
class FiturScreen extends StatelessWidget {
  const FiturScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, IconData, Widget Function(BuildContext))>[
      (
        S.challenge,
        Icons.emoji_events_outlined,
        (_) => const ChallengeListScreen(),
      ),
      (
        'leaderboard',
        Icons.leaderboard_outlined,
        (_) => const LeaderboardScreen(),
      ),
      ('teams', Icons.groups_outlined, (_) => const TeamsScreen()),
      (
        S.streaks,
        Icons.local_fire_department_outlined,
        (_) => const StreaksScreen(),
      ),
      (S.riwayat, Icons.history_outlined, (_) => const HistoryScreen()),
      (S.profile, Icons.person_outline, (_) => const AccountScreen()),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PacerColors.ink),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FITUR', style: PacerText.fugazBrand),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  for (final t in tiles)
                    InkWell(
                      onTap: () =>
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: t.$3)),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: PacerColors.border),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(t.$2, size: 28),
                            const SizedBox(height: 8),
                            // Long labels ("leaderboard") scale instead of clipping.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                t.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Language settings: ID/EN toggle. Persists to Supabase users.language
/// when signed in; local-only in demo mode.
class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadRemote();
  }

  Future<void> _loadRemote() async {
    try {
      final user = supa.auth.currentUser;
      if (user == null) return;
      final row = await supa
          .from('users')
          .select('language')
          .eq('id', user.id)
          .maybeSingle();
      final value = row?['language'] as String?;
      if (value == 'en' && langNotifier.value != Lang.en) {
        langNotifier.value = Lang.en;
      } else if (value == 'id' && langNotifier.value != Lang.id) {
        langNotifier.value = Lang.id;
      }
    } catch (_) {
      // Demo mode or column not migrated yet — local value stands.
    }
  }

  Future<void> _setLang(Lang lang) async {
    langNotifier.value = lang;
    try {
      final user = supa.auth.currentUser;
      if (user == null) return;
      await supa
          .from('users')
          .update({'language': lang == Lang.en ? 'en' : 'id'})
          .eq('id', user.id);
    } catch (_) {
      // Demo mode — local toggle only.
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = langNotifier.value;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PacerColors.ink),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.language, style: PacerText.pageTitle),
              const SizedBox(height: 16),
              _langOption(
                context,
                label: 'Bahasa Indonesia',
                sub: 'Default',
                selected: current == Lang.id,
                onTap: () => _setLang(Lang.id),
              ),
              const SizedBox(height: 12),
              _langOption(
                context,
                label: 'English',
                sub: 'Alternative',
                selected: current == Lang.en,
                onTap: () => _setLang(Lang.en),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langOption(
    BuildContext context, {
    required String label,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? PacerColors.primary : PacerColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PacerColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_off,
              color: selected ? PacerColors.primary : PacerColors.slate400,
            ),
          ],
        ),
      ),
    );
  }
}
