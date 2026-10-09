import 'package:flutter/material.dart';

import 'app_theme.dart';
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
                'Welcome runners !',
                style: PacerText.authTitle.copyWith(fontSize: 34),
              ),
              const SizedBox(height: 32),
              const AuthField(hint: 'Username', icon: Icons.person_outline),
              const SizedBox(height: 16),
              const AuthField(
                hint: 'Password',
                icon: Icons.lock_outline,
                obscure: true,
              ),
              const SizedBox(height: 28),
              Center(
                child: PrimaryButton(label: 'Log In', onPressed: onLoggedIn),
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
class RunSetupScreen extends StatelessWidget {
  final VoidCallback onStart;
  const RunSetupScreen({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Pilih Olahraga',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 24,
                color: Color(0xFF181C22),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(width: 2, color: Colors.black),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.directions_run, size: 28),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lari Luar',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'GPS, jarak & tempo',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'SASARAN SESI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('Bebas')),
                Chip(label: Text('3 km')),
                Chip(label: Text('5 km')),
                Chip(label: Text('30 mnt')),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 350,
              height: 48,
              child: ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Mulai Lari'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Figma tracker: full-bleed map overlay, Fugaz 78 distance, GPS pill, 3 stats, 98 circles.
class RunTrackerScreen extends StatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen> {
  bool _running = false;
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    if (_finished) return const RunFinishScreen();
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.satellite_alt_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('GPS', style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: PacerColors.gpsPill,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text('GPS'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const MapPlaceholder(height: 220),
            const SizedBox(height: 8),
            Text('00,00', style: PacerText.giantNum(78)),
            const Text(
              'Distance (Km)',
              style: TextStyle(fontWeight: FontWeight.w300, fontSize: 15),
            ),
            Container(
              width: 83,
              height: 10,
              decoration: BoxDecoration(
                color: PacerColors.slate200,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniStat('Avg Pace', "0'00''"),
                  _miniStat('Duration', '00.00'),
                  _miniStat('Calories', '0 kcal'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_running && !_finished)
              CircleAction(
                label: 'START',
                bg: PacerColors.lime,
                fg: PacerColors.ink,
                onTap: () => setState(() => _running = true),
              )
            else if (_running)
              CircleAction(
                label: 'PAUSE',
                bg: PacerColors.lime,
                fg: PacerColors.ink,
                onTap: () => setState(() => _running = false),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAction(
                    label: 'LANJUT',
                    bg: Colors.white,
                    fg: PacerColors.ink,
                    onTap: () => setState(() => _running = true),
                  ),
                  const SizedBox(width: 16),
                  CircleAction(
                    label: 'FINISH',
                    bg: PacerColors.ink,
                    fg: PacerColors.lime,
                    onTap: () => setState(() => _finished = true),
                  ),
                ],
              ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: PacerText.statValue),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w300,
            fontSize: 15,
            color: Color(0x99000000),
          ),
        ),
      ],
    );
  }
}

/// Figma RUNNING FINISH: lime 329x92 summary + four 329x75 metric cards.
class RunFinishScreen extends StatelessWidget {
  const RunFinishScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Running', style: TextStyle(fontSize: 24)),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.edit, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 329,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: PacerColors.lime,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text('Distance\n3,00 Km'),
                  Text('Duration\n15.00'),
                  Text('Avg Pace\n5\'00\'\''),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final m in const [
              ('Step Length', 'Distance between steps', '0,85 m'),
              ('Elevation Gain', 'Total height that you climb', '+18 m'),
              ('Cadence', 'Steps per minute', '100 spm'),
              ('Calories', 'Total energy burned', '854 kcal'),
            ])
              Container(
                width: 329,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFDFD),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.$1, style: const TextStyle(fontSize: 15)),
                          Text(
                            m.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(m.$3, style: PacerText.statValue),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Center(
              child: LimeActionBar(
                'selesai',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

/// Figma CLUBS list: Outfit 400/32 title + 358 search + 329x133 cards + buat-teams pill.
class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Temukan Team Di Sekitarmu',
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
                child: const Text(
                  'buat teams',
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
                    child: const Text('Challenge'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    ),
                    child: const Text('Obrolan Tim'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Group Run Terdekat',
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
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo: permintaan gabung terkirim')),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: PacerColors.joinYellow,
        foregroundColor: Colors.black,
        minimumSize: const Size(90, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Gabung'),
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Teams Leaderboard', style: PacerText.pageTitle),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _podium('A. Nugroho', '42.1', 68, PacerColors.podiumGray),
                _podium(
                  'D. Kusuma',
                  '48.2',
                  89,
                  PacerColors.medalGold,
                  first: true,
                ),
                _podium('F. Sanjaya', '39.5', 63, PacerColors.medalBronze),
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
                      MaterialPageRoute(builder: (_) => const StreaksScreen()),
                    ),
                    child: const Text('Streaks'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _podium(
    String name,
    String km,
    double h,
    Color bar, {
    bool first = false,
  }) {
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
          if (first)
            Container(
              width: 35,
              height: 27,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PacerColors.medalGold,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '1',
                style: TextStyle(fontWeight: FontWeight.w800),
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('History', style: PacerText.pageTitle),
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
            const RunSessionCard(title: 'Monday : 07.30'),
            const SizedBox(height: 12),
            const RunSessionCard(
              title: 'Monday : 07.30',
              date: '8/7/2024',
              time: '28.40',
              pace: "6'10''",
              distance: '5,00 Km',
              limePill: true,
            ),
            const SizedBox(height: 12),
            const RunSessionCard(
              title: 'Monday : 07.30',
              date: '1/7/2024',
              time: '1.00.00',
              pace: "4'00''",
              distance: '15,00 Km',
            ),
          ],
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
            Text('challenge detail', style: PacerText.pageTitle),
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
            const Text(
              'Jarak',
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
                'start chalenge',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo: challenge dimulai')),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: Column(
          children: [
            Text('ACCOUNT', style: PacerText.fugazBrand),
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
                  const Text('Email'),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutMeScreen()),
                    ),
                    child: const Text('About Me'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FiturScreen()),
                    ),
                    child: const Text('Fitur'),
                  ),
                  const Text('Out'),
                ],
              ),
            ),
          ],
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
              Text('Statistic', style: PacerText.pageTitle),
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
              const Text(
                'TOTAL JARAK LARI',
                style: TextStyle(fontSize: 11, color: PacerColors.slate400),
              ),
              const Text(
                'Target tercapai',
                style: TextStyle(
                  color: PacerColors.chipGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(child: _StatCard('Rata-rata Pace', "5'00\"", '/km')),
                  SizedBox(width: 8),
                  Expanded(child: _StatCard('Total Waktu', '15.00', 'menit')),
                  SizedBox(width: 8),
                  Expanded(child: _StatCard('Kalori Aktif', '542', 'kkal')),
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
              Text('Streaks', style: PacerText.pageTitle),
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
              Text('challenge', style: PacerText.pageTitle),
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
                  child: const Text('Buat challenge'),
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
    const rows = [
      ('Kapten Aktif', 'Klub butuh kapten yang aktif'),
      ('Min. 3 Anggota', 'Ajak minimal 3 pelari'),
      ('Group Run Rutin', 'Jadwalkan lari bersama rutin'),
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
                '3 hal utama sebelum menerbitkan klub...',
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
                    child: const Text('setuju'),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kembali'),
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
              Text('buat club', style: PacerText.pageTitle),
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
                child: const Text(
                  'Tambah Logo',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Nama Teams'),
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
              const Text('Fokus Klub'),
              const Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('Road Run')),
                  Chip(label: Text('Trail')),
                  Chip(label: Text('Fun Run')),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Kota / Markas'),
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
              const Text('Privasi Komunitas'),
              const Row(
                children: [
                  Chip(label: Text('Publik')),
                  SizedBox(width: 8),
                  Chip(label: Text('Privat')),
                ],
              ),
              const SizedBox(height: 20),
              const Center(child: LimeActionBar('Buat Teams')),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kembali'),
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
              for (final s in const [
                ('JARAK', ['3 km', '5 km', '10 km', 'Lainnya']),
                ('DURASI', ['Hari Ini', '3 Hari', '1 Minggu']),
                ('TARGET', ['25 km', '30 km', '45 km', 'Custom']),
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
              const Center(child: LimeActionBar('Buat challenge')),
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
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(22)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demo: pesan terkirim')),
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
    const rows = [
      ('Full Name', 'Siti Rahma'),
      ('Birth', '14 Mei 1996'),
      ('Gender', 'Perempuan'),
      ('Height', '170 cm'),
      ('Weight', '40 kg'),
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
              Text('About Me', style: PacerText.pageTitle),
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
                  child: const Text(
                    'Edit Personal Details',
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

/// Figma FITUR grid: 6 tiles.
class FiturScreen extends StatelessWidget {
  const FiturScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const tiles = [
      ('challenge', Icons.emoji_events_outlined),
      ('leaderboard', Icons.leaderboard_outlined),
      ('teams', Icons.groups_outlined),
      ('streaks', Icons.local_fire_department_outlined),
      ('riwayat', Icons.history_outlined),
      ('profile', Icons.person_outline),
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
                children: [
                  for (final t in tiles)
                    Container(
                      width: 118,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PacerColors.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.$2, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            t.$1,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
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
