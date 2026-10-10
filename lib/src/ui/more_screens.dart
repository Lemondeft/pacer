import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:pacer/core/responsive/responsive.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/aktivitas/activity_repository.dart';
import 'package:pacer/src/auth/auth_repository.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/challenge/challenge_repository.dart';
import 'package:pacer/src/tracking/recorder.dart';
import 'package:pacer/src/tracking/route_map.dart';
import 'package:pacer/src/leaderboard/leaderboard_model.dart';
import 'package:pacer/src/leaderboard/leaderboard_repository.dart';
import 'package:pacer/src/teams/team_model.dart';
import 'package:pacer/src/teams/team_repository.dart';
import 'package:pacer/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_strings.dart';
import 'app_theme.dart';
import 'coach_board.dart';
import 'format.dart';
import 'screens.dart';
import 'widgets.dart';

/// Figma LOG IN: "Welcome runners !" single line + Username/Password + Log In + divider.
/// The first field is the email credential Supabase Auth signs in with.
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;
  final VoidCallback? onBack;
  const LoginScreen({super.key, required this.onLoggedIn, this.onBack});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = S.errFillAll);
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = S.errEmail);
      return;
    }
    if (!_backend) {
      widget.onLoggedIn();
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthRepository().signIn(email: email, password: _password.text);
      if (mounted) widget.onLoggedIn();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = S.errLoginFailed);
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
              Text(
                S.welcomeRunners,
                style: PacerText.authTitle.copyWith(fontSize: 34),
              ),
              const SizedBox(height: 32),
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
              const SizedBox(height: 28),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(
                    color: PacerColors.errorRed,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              PrimaryButton(label: S.logIn, onPressed: _busy ? null : _submit),
              const SizedBox(height: 28),
              const Divider(color: Colors.black, height: 1),
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
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 65, bottom: 24),
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
              Column(
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
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(width: 2, color: Colors.black),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
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
                    Expanded(
                      child: Column(
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
                    ),
                    const SizedBox(width: 12),
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
                width: double.infinity,
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
  // _running == true means the session is paused (shows LANJUTKAN+SELESAI);
  // _started gates the initial MULAI action.
  late final RunRecorder _recorder = RunRecorder();
  bool _running = false;
  bool _started = false;
  bool _finished = false;
  RunSummary? _summary;

  /// True while start/finish network calls are in flight (double-tap guard).
  bool _opBusy = false;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  String _gpsMessage() {
    switch (_recorder.error) {
      case 'gpsOff':
        return S.gpsOff;
      default:
        return S.gpsDenied;
    }
  }

  Future<void> _begin() async {
    // Double-tap guard: recorder.start is reentrant-safe too, belt and braces.
    if (_opBusy) return;
    _opBusy = true;
    try {
      if (!await _recorder.ensureGps()) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_gpsMessage())));
        }
        return;
      }
      try {
        // Setup screen has no sport picker yet — default to outdoor run.
        await _recorder.start('lari');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(S.errSaveFailed)));
        }
        return;
      }
      setState(() {
        _started = true;
        _running = false;
      });
    } finally {
      _opBusy = false;
    }
  }

  void _pause() {
    _recorder.pause();
    setState(() => _running = true);
  }

  void _resume() {
    _recorder.resume();
    setState(() => _running = false);
  }

  Future<void> _finish() async {
    // Offline at finish is the expected failure mode: stay on the tracker
    // with the recording intact instead of red-screening.
    try {
      final summary = await _recorder.finish();
      if (mounted) {
        setState(() {
          _summary = summary;
          _finished = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.errSaveFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return RunFinishScreen(
        summary: _summary,
        onBack: () => setState(() => _finished = false),
      );
    }
    // Back mid-run asks to discard instead of leaking an unfinished row
    // (dispose cancels GPS but never finishes).
    return PopScope(
      canPop: !_recorder.started,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(S.discardTitle),
            content: Text(S.discardBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(S.back),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(S.discardYes),
              ),
            ],
          ),
        );
        if (discard == true) {
          await _recorder.discard();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Live OSM map behind the stats; falls back to Jakarta when empty.
            ListenableBuilder(
              listenable: _recorder,
              builder: (context, _) => Positioned.fill(
                child: RouteMap(
                  points: _recorder.points,
                  height: double.infinity,
                ),
              ),
            ),
            SafeArea(
              // Fluid layout: hero number and action circles scale with width
              // (fluid 72→160 / 84→112); on expanded widths the route visual
              // and the stats/actions sit side by side in two panes.
              // ListenableBuilder repaints hero + stats on every GPS fix.
              child: ListenableBuilder(
                listenable: _recorder,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final hero = fluid(w, 72, 160);
                    final circle = fluid(w, 84, 112);
                    Widget header = Padding(
                      padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
                      child: Row(
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
                              onPressed:
                                  widget.onBack ??
                                  () => Navigator.maybePop(context),
                              icon: const Icon(
                                Icons.arrow_back,
                                color: PacerColors.ink,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 83,
                            height: 10,
                            decoration: BoxDecoration(
                              color: PacerColors.ink.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(width: 24),
                          const GpsPill(),
                        ],
                      ),
                    );
                    Widget heroBlock = Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fmtKmNum(_recorder.distanceM),
                            style: PacerText.giantNum(hero),
                          ),
                          Text(
                            S.distanceKm,
                            style: const TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 15,
                              color: Color(0x99000000),
                            ),
                          ),
                        ],
                      ),
                    );
                    final livePace = _recorder.paceSecPerKm;
                    final paceSecs = livePace?.round();
                    final paceText = paceSecs == null
                        ? "0'00''"
                        : "${paceSecs ~/ 60}'${(paceSecs % 60).toString().padLeft(2, '0')}\"";
                    Widget stats = Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        children: [
                          Expanded(
                            child: TrackerStatColumn(
                              avatarSize: 20,
                              initials: 'A',
                              value: paceText,
                              label: S.avgPace,
                            ),
                          ),
                          Expanded(
                            child: TrackerStatColumn(
                              avatarSize: 25,
                              initials: 'B',
                              value: fmtDurasi(_recorder.elapsed.inSeconds),
                              label: S.duration,
                            ),
                          ),
                          Expanded(
                            child: TrackerStatColumn(
                              avatarSize: 30,
                              initials: 'C',
                              value: '0 kcal',
                              label: S.calories,
                            ),
                          ),
                        ],
                      ),
                    );
                    Widget actions = Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          MapCircleButton(size: circle),
                          if (!_started)
                            CircleAction(
                              label: S.startLabel,
                              bg: PacerColors.lime,
                              fg: PacerColors.ink,
                              size: circle,
                              onTap: _opBusy ? null : _begin,
                            )
                          else if (!_running)
                            CircleAction(
                              label: S.pause,
                              bg: PacerColors.lime,
                              fg: PacerColors.ink,
                              size: circle,
                              onTap: _pause,
                            )
                          else
                            CircleAction(
                              label: S.continueLabel,
                              bg: Colors.white,
                              fg: PacerColors.ink,
                              labelSize: 14,
                              size: circle,
                              onTap: _resume,
                            ),
                          if (_started && _running)
                            CircleAction(
                              label: S.finish,
                              bg: PacerColors.ink,
                              fg: PacerColors.lime,
                              labelSize: 14,
                              size: circle,
                              onTap: _finish,
                            )
                          else
                            SizedBox(width: circle),
                        ],
                      ),
                    );
                    if (w >= Breakpoints.expanded) {
                      // Two panes: route visual left, stats + actions right.
                      return Column(
                        children: [
                          header,
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: heroBlock),
                                SizedBox(width: fluid(w, 24, 64)),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      stats,
                                      const SizedBox(height: 32),
                                      actions,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        header,
                        Expanded(child: heroBlock),
                        stats,
                        const SizedBox(height: 24),
                        actions,
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
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

  /// Real totals from a just-finished recording; null shows mock values.
  final RunSummary? summary;

  /// Loads and draws the saved GPS route in history-detail mode.
  final String? aktivitasId;
  const RunFinishScreen({
    super.key,
    this.title,
    this.isHistoryDetail = false,
    this.onBack,
    this.summary,
    this.aktivitasId,
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
            child: ResponsiveScroll(
              maxWidth: 720,
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 41),
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
                  Container(height: 1, color: const Color(0x40000000)),
                  if (isHistoryDetail) ...[
                    const SizedBox(height: 28),
                    if (aktivitasId != null)
                      FutureBuilder<List<RutePoint>>(
                        future: ActivityRepository().getRoute(aktivitasId!),
                        builder: (context, snap) {
                          final pts = snap.data;
                          if (pts == null || pts.isEmpty) {
                            return const MapPlaceholder(
                              height: 185,
                              label: 'Belum ada rute tersimpan',
                            );
                          }
                          return RouteMap(
                            points: [for (final p in pts) LatLng(p.lat, p.lng)],
                            height: 185,
                          );
                        },
                      )
                    else
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
                    distance: summary != null
                        ? fmtKm(summary!.jarakM)
                        : (isHistoryDetail ? '3,00 Km' : '0,00 Km'),
                    duration: summary != null
                        ? fmtDurasi(summary!.durasiS)
                        : (isHistoryDetail ? '15.00' : '00.00'),
                    pace: summary != null
                        ? fmtPace(summary!.durasiS, summary!.jarakM)
                        : (isHistoryDetail ? "5'00''" : "0'00''"),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cards = [
                        for (final m in metrics)
                          MetricCard(
                            title: m.$1,
                            sub: m.$2,
                            value: isHistoryDetail ? m.$3 : null,
                            unit: isHistoryDetail ? m.$4 : null,
                          ),
                      ];
                      if (screenSizeOf(c.maxWidth) == ScreenSize.compact) {
                        return Column(
                          children: [
                            for (final card in cards)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: card,
                              ),
                          ],
                        );
                      }
                      // medium and up: metric cards flow into a 2+ column
                      // grid that grows with the width.
                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              mainAxisSpacing: 9,
                              crossAxisSpacing: 9,
                              mainAxisExtent: 90,
                            ),
                        children: cards,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  LimeActionBar(
                    S.done,
                    // Embedded in the tracker (not a pushed route) onBack
                    // returns to the tracker; pushed detail screens pop.
                    onPressed: onBack ?? () => Navigator.of(context).pop(),
                  ),
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
/// Live team list when signed in (search filters by name); Figma mock cards
/// in demo mode.
class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  Future<List<Team>>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  bool get _backend {
    try {
      supa;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Team>> _load() async {
    if (!_backend) return const [];
    if (supa.auth.currentUser == null) return const [];
    try {
      return await TeamRepository().listTeams();
    } catch (_) {
      return const [];
    }
  }

  /// Empty in demo/offline (mock cards show); null only before first frame.
  Widget _teamGrid(List<Widget> children) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 140,
      ),
      children: children,
    );
  }

  Widget _demoGrid() {
    return _teamGrid(const [
      TeamCard(name: 'JakBar Pacer', location: 'Jakarta Barat, Indonesia'),
      TeamCard(name: 'Tangerang Runners', location: 'Tangerang, Indonesia'),
      TeamCard(
        name: 'Jakarta Night Striders',
        location: 'GBK Senayan • Gate 5',
      ),
      TeamCard(name: 'Senayan Squad', location: 'Jakarta Selatan, Indonesia'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ResponsiveScroll(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.findTeamsNearby, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              SearchField(onChanged: (v) => setState(() => _query = v)),
              const SizedBox(height: 16),
              // Team cards flow into a grid: 1 column on phones, 2 on
              // tablets, 3+ on desktop — driven by max extent, never a
              // hardcoded count.
              FutureBuilder<List<Team>>(
                future: _future,
                builder: (context, snap) {
                  final teams = snap.data;
                  final live =
                      teams != null &&
                      (_backend && supa.auth.currentUser != null);
                  final filtered = (teams ?? const <Team>[])
                      .where(
                        (t) =>
                            _query.isEmpty ||
                            t.nama.toLowerCase().contains(_query.toLowerCase()),
                      )
                      .toList();
                  if (!live) {
                    return _demoGrid();
                  }
                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text('Tidak ada tim yang cocok.'),
                    );
                  }
                  return _teamGrid([
                    for (final t in filtered) TeamCard(name: t.nama),
                  ]);
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PersyaratanScreen()),
                ),
                child: Container(
                  width: double.infinity,
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
                  child: Text(
                    S.createTeam,
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
              Text(
                S.nearestGroupRun,
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
      onPressed: () =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(S.demoJoinSent))),
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
/// Live standings (first board) when signed in; Figma mock rows in demo mode.
/// Your own row is highlighted by user id, never by name matching.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

/// Live board data; [rows] null in demo mode (mock rows show).
class _BoardData {
  final String? boardNama;
  final List<({Peringkat entry, String nama})>? rows;
  final String? uid;
  const _BoardData({this.boardNama, this.rows, this.uid});
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Future<_BoardData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  bool get _backend {
    try {
      supa;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<_BoardData> _load() async {
    try {
      if (!_backend) return const _BoardData();
      final uid = supa.auth.currentUser?.id;
      if (uid == null) return const _BoardData();
      final repo = LeaderboardRepository();
      final boards = await repo.listLeaderboards(limit: 1);
      if (boards.isEmpty) return const _BoardData();
      final rows = await repo.getPeringkatWithNames(boards.first.id);
      return _BoardData(boardNama: boards.first.nama, rows: rows, uid: uid);
    } catch (_) {
      return const _BoardData();
    }
  }

  static const _rows = [
    ('Reza Pratama', '36.4 Km'),
    ('Indra Wijaya', '34.1 Km'),
    ('Siti Rahma (You)', '31.0 Km'),
    ('Budi Santoso', '28.5 Km'),
    ('Clara Angelica', '25.9 Km'),
  ];

  Widget _standingRow({
    required int rank,
    required String name,
    required String value,
    required bool mine,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? PacerColors.lime : PacerColors.border),
        color: mine ? PacerColors.lime.withValues(alpha: 0.1) : Colors.white,
      ),
      child: Row(
        children: [
          Text(
            '$rank',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Figma mock board (demo mode or fewer than 3 ranked rows).
  Widget _demoBoard() {
    return Column(
      children: [
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
          _standingRow(
            rank: i + 4,
            name: _rows[i].$1,
            value: _rows[i].$2,
            mine: _rows[i].$1.contains('(You)'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ResponsiveScroll(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.teamsLeaderboard, style: PacerText.pageTitle),
              const SizedBox(height: 16),
              FutureBuilder<_BoardData>(
                future: _future,
                builder: (context, snap) {
                  final d = snap.data;
                  final rows = d?.rows;
                  // Demo/offline only: never render mock names for signed-in users.
                  if (rows == null) return _demoBoard();
                  if (rows.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text('Belum ada peringkat.'),
                    );
                  }
                  // Live board with fewer than 3 rows: list without podium.
                  if (rows.length < 3) {
                    final uid = d?.uid;
                    return Column(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          _standingRow(
                            rank: i + 1,
                            name: rows[i].nama,
                            value: rows[i].entry.nilai.toStringAsFixed(1),
                            mine: rows[i].entry.userId == uid,
                          ),
                      ],
                    );
                  }
                  final uid = d?.uid;
                  final top = rows.take(3).toList();
                  final rest = rows.skip(3).toList();
                  String val(double v) => v.toStringAsFixed(1);
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _podium(
                            top[1].nama,
                            val(top[1].entry.nilai),
                            68,
                            PacerColors.podiumGray,
                            rank: 2,
                            medal: PacerColors.medalSilver,
                          ),
                          _podium(
                            top[0].nama,
                            val(top[0].entry.nilai),
                            89,
                            PacerColors.medalGold,
                            rank: 1,
                            medal: PacerColors.medalGold,
                          ),
                          _podium(
                            top[2].nama,
                            val(top[2].entry.nilai),
                            63,
                            PacerColors.medalBronze,
                            rank: 3,
                            medal: PacerColors.medalBronze,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < rest.length; i++)
                        _standingRow(
                          rank: i + 4,
                          name: rest[i].nama,
                          value: val(rest[i].entry.nilai),
                          mine: uid != null && rest[i].entry.userId == uid,
                        ),
                    ],
                  );
                },
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
/// Live activity list when signed in; Figma mock cards in demo mode.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<List<Activity>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Demo when offline or signed out (mock cards show, not the empty state).
  bool get _demo {
    try {
      return supa.auth.currentUser == null;
    } catch (_) {
      return true;
    }
  }

  Future<List<Activity>> _load() async {
    try {
      if (_demo) return const [];
      return await ActivityRepository().listActivities();
    } catch (_) {
      return const [];
    }
  }

  /// Session cards flow into a grid on medium and up.
  Widget _historyGrid(BuildContext context, List<Widget> cards) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 156,
      ),
      children: cards,
    );
  }

  Widget _activityCard(Activity a) {
    String cap(String j) =>
        j.isEmpty ? j : '${j[0].toUpperCase()}${j.substring(1)}';
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RunFinishScreen(
            title: '${cap(a.jenis)} ${fmtDate(a.mulaiAt)}'.trim(),
            isHistoryDetail: true,
            aktivitasId: a.id,
          ),
        ),
      ),
      child: RunSessionCard(
        title: cap(a.jenis),
        date: fmtDate(a.mulaiAt),
        time: fmtDurasi(a.durasiS),
        pace: fmtPace(a.durasiS, a.jarakM),
        distance: fmtKm(a.jarakM),
      ),
    );
  }

  /// Figma mock hero + cards (demo mode, loading, or error).
  Widget _demoHistory(double w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Hero number scales with width (fluid 88→140).
            Text('46,00', style: PacerText.giantNum(fluid(w, 88, 140))),
            const Text(
              'Kilometer',
              style: TextStyle(fontWeight: FontWeight.w300, fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Wrap instead of a fixed Row so the summary never overflows.
        const Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              '4 Run',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 24),
            ),
            Text(
              '5,50 Average Pace',
              style: TextStyle(fontWeight: FontWeight.w300, fontSize: 20),
            ),
            Text(
              '4.10.00 Time',
              style: TextStyle(fontWeight: FontWeight.w300, fontSize: 20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _historyGrid(context, [
          for (final card in const [
            RunSessionCard(title: 'Monday : 07.30'),
            RunSessionCard(
              title: 'Monday : 07.30',
              date: '8/7/2024',
              time: '28.40',
              pace: "6'10''",
              distance: '5,00 Km',
              limePill: true,
            ),
            RunSessionCard(
              title: 'Monday : 07.30',
              date: '1/7/2024',
              time: '1.00.00',
              pace: "4'00''",
              distance: '15,00 Km',
            ),
          ])
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RunFinishScreen(
                    title: 'Monday Morning Run',
                    isHistoryDetail: true,
                  ),
                ),
              ),
              child: card,
            ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ResponsiveScroll(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.history, style: PacerText.pageTitle),
              FutureBuilder<List<Activity>>(
                future: _future,
                builder: (context, snap) {
                  final activities = snap.data;
                  // Demo (or still loading / error): Figma mock content.
                  if (_demo || activities == null) return _demoHistory(w);
                  if (activities.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Text('Belum ada aktivitas. Mulai lari pertamamu!'),
                    );
                  }
                  final totalKm = activities.fold<double>(
                    0,
                    (s, a) => s + (a.jarakM ?? 0),
                  );
                  final totalS = activities.fold<int>(
                    0,
                    (s, a) => s + (a.durasiS ?? 0),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Hero number scales with width (fluid 88→140).
                          Text(
                            fmtKmNum(totalKm),
                            style: PacerText.giantNum(fluid(w, 88, 140)),
                          ),
                          const Text(
                            'Kilometer',
                            style: TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Wrap instead of a fixed Row so the summary never overflows.
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        children: [
                          Text(
                            '${activities.length} Run',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 24,
                            ),
                          ),
                          Text(
                            '${fmtPace(totalS, totalKm)} Average Pace',
                            style: const TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            '${fmtDurasi(totalS)} Time',
                            style: const TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _historyGrid(context, [
                        for (final a in activities) _activityCard(a),
                      ]),
                    ],
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

/// Figma challenge detail full page.
/// [challengeId] null in demo mode (join button shows a demo snackbar).
class ChallengeDetailSheet extends StatefulWidget {
  final String? challengeId;
  const ChallengeDetailSheet({super.key, this.challengeId});

  static void show(BuildContext context, {String? challengeId}) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ChallengeDetailSheet(challengeId: challengeId),
    );
  }

  @override
  State<ChallengeDetailSheet> createState() => _ChallengeDetailSheetState();
}

class _ChallengeDetailSheetState extends State<ChallengeDetailSheet> {
  bool? _joined;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  bool get _live {
    try {
      return supa.auth.currentUser != null && widget.challengeId != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _check() async {
    if (!_live) return;
    try {
      final parts = await ChallengeRepository().myParticipations();
      if (mounted) {
        setState(() {
          _joined = parts.any((p) => p.challengeId == widget.challengeId);
        });
      }
    } catch (_) {
      /* stays null → join attempt reports errors */
    }
  }

  Future<void> _toggle() async {
    final id = widget.challengeId;
    if (!_live || id == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.demoChallengeStarted)));
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ChallengeRepository();
      if (_joined == true) {
        await repo.leaveChallenge(id);
        if (mounted) setState(() => _joined = false);
      } else {
        await repo.joinChallenge(id);
        if (mounted) setState(() => _joined = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.errSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sheets cap at ~560 on wide screens instead of stretching edge to edge.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
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
                Text(
                  S.distance,
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
                LimeActionBar(
                  _joined == true ? S.leaveChallenge : S.startChallenge,
                  onPressed: _busy ? null : _toggle,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma ACCOUNT + About Me (minimal faithful slice).
/// Avatar, name, and email are live (profile row + auth); About Me details
/// have no backend columns and stay Figma-static.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  ({String? nama, String? email})? _profile;

  @override
  void initState() {
    super.initState();
    _load().then((p) {
      if (mounted) setState(() => _profile = p);
    });
  }

  Future<({String? nama, String? email})> _load() async {
    try {
      final user = supa.auth.currentUser;
      if (user == null) return (nama: null, email: null);
      final profile = await AuthRepository().getProfile();
      return (nama: profile?.nama, email: user.email);
    } catch (_) {
      return (nama: null, email: null);
    }
  }

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
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 120),
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
              InitialAvatar(initialsOf(_profile?.nama), size: 99),
              const SizedBox(height: 8),
              Text(
                _profile?.nama ?? '–',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Container(
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
                        SnackBar(content: Text(_profile?.email ?? '–')),
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
                      onTap: () async {
                        try {
                          await AuthRepository().signOut();
                        } catch (_) {
                          // Demo mode (no backend): just leave.
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
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
    );
  }
}

/// Figma Statistic: map card + total + 3 stat cards.
/// Weekly totals when signed in (kcal has no source — shows '–' live);
/// Figma mock values in demo mode.
class StatisticScreen extends StatefulWidget {
  const StatisticScreen({super.key});

  @override
  State<StatisticScreen> createState() => _StatisticScreenState();
}

class _StatisticScreenState extends State<StatisticScreen> {
  Future<({double km, int seconds})?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  bool get _demo {
    try {
      return supa.auth.currentUser == null;
    } catch (_) {
      return true;
    }
  }

  /// This week's distance + time; null in demo or when empty.
  Future<({double km, int seconds})?> _load() async {
    try {
      if (_demo) return null;
      final repo = ActivityRepository();
      final stats = await repo.getStatistik(periodeKey(DateTime.now()));
      if (stats == null || stats.jarakM <= 0) return null;
      return (km: stats.jarakM / 1000, seconds: stats.waktuS);
    } catch (_) {
      return null;
    }
  }

  /// Figma mock totals (demo mode or empty week).
  Widget _demoTotal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3,00 Km',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 32),
        ),
        Text(
          S.totalRunDistance,
          style: TextStyle(fontSize: 11, color: PacerColors.slate400),
        ),
        Text(
          S.targetAchieved,
          style: TextStyle(
            color: PacerColors.chipGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(S.averagePace, "5'00\"", '/km')),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(S.totalTime, '15.00', 'menit')),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(S.activeCalories, '542', 'kkal')),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
              Text(S.statistic, style: PacerText.pageTitle),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  Widget map = const MapPlaceholder(
                    height: 160,
                    label: 'Senayan Loop (3x) • Elevasi +45m',
                  );
                  Widget total = FutureBuilder<({double km, int seconds})?>(
                    future: _future,
                    builder: (context, snap) {
                      final d = snap.data;
                      // Demo (or empty week): Figma mock values.
                      if (d == null) return _demoTotal();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fmtKmNum(d.km * 1000),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 32,
                            ),
                          ),
                          Text(
                            S.totalRunDistance,
                            style: TextStyle(
                              fontSize: 11,
                              color: PacerColors.slate400,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  S.averagePace,
                                  fmtPace(d.seconds, d.km * 1000),
                                  '/km',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatCard(
                                  S.totalTime,
                                  fmtDurasi(d.seconds),
                                  'menit',
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(child: _StatCard('–', '', '')),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                  if (screenSizeOf(c.maxWidth) == ScreenSize.compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [map, const SizedBox(height: 12), total],
                    );
                  }
                  // medium and up: map pane beside the stats pane.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: map),
                      const SizedBox(width: 24),
                      Expanded(child: total),
                    ],
                  );
                },
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
/// Live streak row when signed in (done days reconstructed as the trailing
/// streak ending at the last workout day); Figma mock strip in demo mode.
/// Personal record has no source column — shows '–' live.
class StreaksScreen extends StatefulWidget {
  const StreaksScreen({super.key});

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen> {
  Future<({int count, DateTime? terakhir, double totalKm})?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  bool get _demo {
    try {
      return supa.auth.currentUser == null;
    } catch (_) {
      return true;
    }
  }

  Future<({int count, DateTime? terakhir, double totalKm})?> _load() async {
    try {
      if (_demo) return null;
      final repo = ActivityRepository();
      final streak = await repo.getStreak();
      final activities = await repo.listActivities(limit: 100);
      final totalKm =
          activities.fold<double>(0, (s, a) => s + (a.jarakM ?? 0)) / 1000;
      return (
        count: streak?.berjalan ?? 0,
        terakhir: streak?.terakhir,
        totalKm: totalKm,
      );
    } catch (_) {
      return null;
    }
  }

  /// Done flags for Mon..Sun: trailing [count] days ending at [terakhir].
  List<bool> _doneWeek(int count, DateTime? terakhir) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return [
      for (var i = 0; i < 7; i++)
        terakhir != null &&
            count > 0 &&
            () {
              final day = DateTime(monday.year, monday.month, monday.day + i);
              final last = DateTime(
                terakhir.year,
                terakhir.month,
                terakhir.day,
              );
              final back = last.difference(day).inDays;
              return back >= 0 && back < count;
            }(),
    ];
  }

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  /// 7-day strip; [done] flags per weekday Mon..Sun, [todayIdx] glows.
  Widget _weekRow(List<bool> done, int todayIdx) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final d = done[i];
        final today = i == todayIdx;
        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: d ? PacerColors.streakBlue : Colors.white,
                border: Border.all(
                  color: d || today
                      ? PacerColors.streakBlue
                      : PacerColors.slate200,
                  width: 2,
                ),
                boxShadow: today
                    ? [const BoxShadow(color: Color(0xFFFFE600), blurRadius: 8)]
                    : null,
              ),
              child: d
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            Text(
              _days[i],
              style: const TextStyle(fontSize: 11, color: PacerColors.slate400),
            ),
          ],
        );
      }),
    );
  }

  /// Figma mock strip (demo mode or no streak yet).
  Widget _demoWeek() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MINGGU INI • 5 dari 7 Hari',
          style: TextStyle(
            color: PacerColors.streakBlue,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        _weekRow(const [true, true, true, true, false, false, false], 4),
        const SizedBox(height: 16),
        const StreakCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
              Text(S.streaks, style: PacerText.pageTitle),
              const SizedBox(height: 12),
              FutureBuilder<({int count, DateTime? terakhir, double totalKm})?>(
                future: _future,
                builder: (context, snap) {
                  final d = snap.data;
                  // Demo (or no streak yet): Figma mock strip.
                  if (d == null) return _demoWeek();
                  final done = _doneWeek(d.count, d.terakhir);
                  final todayIdx = DateTime.now().weekday - 1;
                  final doneThisWeek = [
                    for (var i = 0; i < 7; i++)
                      if (done[i]) i,
                  ].length;
                  Widget week = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MINGGU INI • $doneThisWeek dari 7 Hari',
                        style: const TextStyle(
                          color: PacerColors.streakBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _weekRow(done, todayIdx),
                      const SizedBox(height: 16),
                      StreakCard(count: d.count),
                    ],
                  );
                  return LayoutBuilder(
                    builder: (context, c) {
                      if (screenSizeOf(c.maxWidth) == ScreenSize.compact) {
                        return week;
                      }
                      // medium and up: week + card left, streak stats right —
                      // no empty bottom half.
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: week),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                _StatCard(S.streaks, '${d.count}', ''),
                                const SizedBox(height: 12),
                                // No personal-record source column — honest dash.
                                _StatCard(S.personalRecord, '–', ''),
                                const SizedBox(height: 12),
                                _StatCard(
                                  S.history,
                                  fmtKmNum(d.totalKm * 1000),
                                  'km',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma CHALLENGE list: 10 KM + 8 KM hero cards.
/// Live challenges when signed in; Figma mock cards in demo mode.
class ChallengeListScreen extends StatefulWidget {
  const ChallengeListScreen({super.key});

  @override
  State<ChallengeListScreen> createState() => _ChallengeListScreenState();
}

class _ChallengeListScreenState extends State<ChallengeListScreen> {
  Future<List<Challenge>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  bool get _backend {
    try {
      supa;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Challenge>> _load() async {
    try {
      if (!_backend) return const [];
      if (supa.auth.currentUser == null) return const [];
      return await ChallengeRepository().listChallenges();
    } catch (_) {
      return const [];
    }
  }

  /// Hero number: km for jarak_m targets, minutes for waktu_s.
  String _heroValue(Challenge c) {
    final v = c.targetSatuan == 'jarak_m'
        ? c.targetNilai / 1000
        : c.targetNilai / 60;
    return v == v.truncateToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
  }

  String _heroUnit(Challenge c) => c.targetSatuan == 'jarak_m' ? ' KM' : ' MNT';

  String _heroDate(Challenge c) {
    final d = c.waktuSelesai ?? c.waktuMulai;
    if (d == null) return '-';
    return '${d.day}-${d.month}-${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
              Text(S.challenge, style: PacerText.pageTitle),
              const SizedBox(height: 12),
              FutureBuilder<List<Challenge>>(
                future: _future,
                builder: (context, snap) {
                  final live = snap.data;
                  // Signed in with zero challenges: honest empty state,
                  // never mock hero cards.
                  if (live != null && live.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text('Belum ada challenge.'),
                    );
                  }
                  final cards = (live == null)
                      ? const [
                          ('10', ' KM', '29-10-2009', null),
                          ('8', ' KM', '29-10-2009', null),
                        ]
                      : [
                          for (final c in live)
                            (_heroValue(c), _heroUnit(c), _heroDate(c), c.id),
                        ];
                  return Column(
                    children: [
                      for (final c in cards)
                        GestureDetector(
                          onTap: () => showModalBottomSheet(
                            context: context,
                            builder: (_) =>
                                ChallengeDetailSheet(challengeId: c.$4),
                          ),
                          child: Container(
                            width: double.infinity,
                            height: fluid(w, 179, 220),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2B2B2B),
                                  PacerColors.streakBg,
                                ],
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Hero number scales with width (fluid 96→140).
                                Text(
                                  c.$1,
                                  style: PacerText.giantNum(fluid(w, 96, 140))
                                      .copyWith(color: PacerColors.primary),
                                ),
                                Text(
                                  c.$2,
                                  style: PacerText.kmSuffix.copyWith(
                                    fontSize: 40,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  c.$3,
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
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
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
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateClubScreen()),
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

/// Figma buat club form. Creates the team server-side (coach/admin only —
/// regular users get a "coach only" message); demo mode pops with a demo note.
class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _live {
    try {
      return supa.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final nama = _name.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = S.errFillAll);
      return;
    }
    if (!_live) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.demoJoinSent)));
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await TeamRepository().createTeam(nama: nama);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.teamCreated)));
        Navigator.of(context).pop();
      }
    } on PostgrestException catch (e) {
      setState(
        () => _error = e.code == '42501' ? S.coachOnly : S.errSaveFailed,
      );
    } catch (_) {
      setState(() => _error = S.errSaveFailed);
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
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
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
                child: Text(
                  S.addLogo,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Text(S.teamName),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: PacerColors.formBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: PacerColors.errorRed,
                    fontSize: 15,
                  ),
                ),
              ],
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
              LimeActionBar(S.createTeam, onPressed: _busy ? null : _submit),
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
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
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
              LimeActionBar(S.createChallenge),
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
      body: Center(
        // Chat content caps at 720 on wide screens instead of stretching.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
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
        ),
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
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
              Text(S.aboutMe, style: PacerText.pageTitle),
              const SizedBox(height: 12),
              Container(
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
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PacerColors.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    S.editPersonalDetails,
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
      (S.coachBoard, Icons.school_outlined, (_) => const CoachBoardScreen()),
    ];
    return Scaffold(
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
              Text('FITUR', style: PacerText.fugazBrand),
              const SizedBox(height: 12),
              // Tiles flow into a grid driven by max extent — never a
              // hardcoded column count.
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
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
    // Never let a backend read silently undo an explicit choice made
    // this session (e.g. profile row still holds the old default because
    // a write failed or RLS denied it).
    if (langUserLocked) return;
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
    langUserLocked = true;
    langNotifier.value = lang;
    try {
      final user = supa.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() {});
        return;
      }
      await supa
          .from('users')
          .update({'language': lang == Lang.en ? 'en' : 'id'})
          .eq('id', user.id)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Demo mode, missing column, RLS denial, or offline: the choice
      // still applies locally — say so instead of failing silently.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.langSaveFailed)));
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = langNotifier.value;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
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
