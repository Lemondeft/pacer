import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:pacer/core/responsive/responsive.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/aktivitas/activity_repository.dart';
import 'package:pacer/src/auth/auth_repository.dart';
import 'package:pacer/src/auth/profile_input.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/challenge/challenge_repository.dart';
import 'package:pacer/src/chat/chat_model.dart';
import 'package:pacer/src/chat/chat_repository.dart';
import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/leaderboard/leaderboard_model.dart';
import 'package:pacer/src/leaderboard/leaderboard_repository.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:pacer/src/teams/team_model.dart';
import 'package:pacer/src/teams/team_repository.dart';
import 'package:pacer/src/tracking/recorder.dart';
import 'package:pacer/src/tracking/route_map.dart';
import 'package:pacer/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_strings.dart';
import 'app_theme.dart';
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
                style: PacerText.authTitleOf(context).copyWith(fontSize: 34),
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
              const SizedBox(height: 32),
              if (_error != null) ...[
                AuthErrorText(_error!),
                const SizedBox(height: 16),
              ],
              PrimaryButton(label: S.logIn, onPressed: _busy ? null : _submit),
              const SizedBox(height: 32),
              Divider(color: PacerScheme.of(context).border, height: 1),
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
  final void Function(String jenis, String goal)? onStartWithConfig;
  final VoidCallback? onStart;
  const RunSetupScreen({super.key, this.onStartWithConfig, this.onStart});

  @override
  State<RunSetupScreen> createState() => _RunSetupScreenState();
}

class _RunSetupScreenState extends State<RunSetupScreen> {
  int _selectedSport = 0;
  int _goal = 0;

  static const _sports = [
    (
      key: 'lari',
      icon: Icons.directions_run,
      title: 'Lari',
      subtitle: 'GPS, jarak & tempo',
    ),
    (
      key: 'joging',
      icon: Icons.directions_walk,
      title: 'Joging',
      subtitle: 'Tempo sedang & daya tahan',
    ),
    (
      key: 'bersepeda',
      icon: Icons.directions_bike,
      title: 'Bersepeda',
      subtitle: 'Kecepatan, elevasi & rute',
    ),
    (
      key: 'berjalan',
      icon: Icons.nordic_walking,
      title: 'Berjalan',
      subtitle: 'Irama langkah & jarak tempuh',
    ),
  ];

  List<String> get _goals => [
    S.free,
    '3 km',
    '5 km',
    langNotifier.value == Lang.en ? '30 min' : '30 mnt',
  ];

  String _sportTitle(int index) {
    switch (index) {
      case 0:
        return S.outdoorRun;
      case 1:
        return S.jogging;
      case 2:
        return S.cycling;
      case 3:
        return S.walking;
      default:
        return _sports[index].title;
    }
  }

  String _sportSubtitle(int index) {
    switch (index) {
      case 0:
        return S.runSubtitle;
      case 1:
        return S.jogSubtitle;
      case 2:
        return S.cyclingSubtitle;
      case 3:
        return S.walkingSubtitle;
      default:
        return _sports[index].subtitle;
    }
  }

  void _handleStart() {
    HapticFeedback.mediumImpact();
    final chosenSport = _sports[_selectedSport].key;
    final chosenGoal = _goals[_goal];
    if (widget.onStartWithConfig != null) {
      widget.onStartWithConfig!(chosenSport, chosenGoal);
    } else if (widget.onStart != null) {
      widget.onStart!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 64, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.card,
                  shape: BoxShape.circle,
                  boxShadow: [scheme.shadowBox],
                ),
                child: BackButton(color: scheme.ink),
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
                      color: scheme.chipFg,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    S.setupSubtitle,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      height: 20 / 14,
                      color: scheme.bodyGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 450;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isCompact ? 1 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: isCompact ? 3.8 : 2.5,
                    ),
                    itemCount: _sports.length,
                    itemBuilder: (context, index) {
                      final item = _sports[index];
                      final isSelected = _selectedSport == index;
                      return PacerTapScale(
                        pressedScale: 0.97,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedSport = index);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (scheme.isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9))
                                  : scheme.card,
                              border: Border.all(
                                color: isSelected
                                    ? PacerColors.lime
                                    : scheme.hairline,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: PacerColors.lime.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [scheme.shadowBox],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? PacerColors.lime
                                        : scheme.softBorder,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    size: 24,
                                    color: isSelected
                                        ? PacerColors.navy
                                        : scheme.ink,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _sportTitle(index),
                                        style: GoogleFonts.spaceGrotesk(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: scheme.chipFg,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _sportSubtitle(index),
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 11,
                                          color: scheme.bodyGray,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? PacerColors.lime
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? PacerColors.lime
                                          : scheme.chipBorder,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: PacerColors.navy,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: scheme.hairline)),
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
                            color: scheme.bodyGray,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '5.0 km',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12,
                            color: scheme.bodyGray,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _goals.length; i++)
                          PacerTapScale(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _goal = i);
                              },
                              child: GoalChip(
                                label: _goals[i],
                                selected: _goal == i,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PacerTapScale(
                pressedScale: 0.98,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.chipSelBg,
                      foregroundColor: scheme.chipSelFg,
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
  final String sportType;
  final String? goal;
  final ActiveDraftRun? initialDraft;
  const RunTrackerScreen({
    super.key,
    this.onBack,
    this.sportType = 'lari',
    this.goal,
    this.initialDraft,
  });

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

  /// Interactive Map Focus mode: collapses the hero readout into a compact
  /// top HUD strip so the live vector map can be explored and zoomed freely.
  bool _mapFocus = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    if (draft != null) {
      _recorder.restoreDraft(draft);
      _started = true;
      _running = true;
    }
  }

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

  /// Confirm-and-discard dialog shared by system-back and header-back.
  /// Returns true when recording was discarded (or nothing was recording).
  Future<bool> _confirmDiscard() async {
    if (!_recorder.started) return true;
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
      return true;
    }
    return false;
  }

  /// Header back: never leaks an unfinished row, never pops the app shell.
  Future<void> _handleBack() async {
    if (!await _confirmDiscard()) return;
    if (!mounted) return;
    HapticFeedback.selectionClick();
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _begin() async {
    // Double-tap guard: recorder.start is reentrant-safe too, belt and braces.
    if (_opBusy) return;
    _opBusy = true;
    try {
      if (!await _recorder.ensureGps()) {
        // No GPS (desktop/emulator): offer explicit synthetic tracking so
        // the map and pipeline stay testable without a phone. Never implicit.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_gpsMessage()),
              action: SnackBarAction(
                label: 'Simulasi',
                onPressed: () async {
                  // Grabbed synchronously: safe to use after the awaits.
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await _recorder.simulate(widget.sportType);
                  } catch (_) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(S.errSaveFailed)),
                    );
                    return;
                  }
                  if (!mounted) return;
                  setState(() {
                    _started = true;
                    _running = false;
                  });
                },
              ),
            ),
          );
        }
        return;
      }
      try {
        await _recorder.start(widget.sportType);
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
    HapticFeedback.lightImpact();
    _recorder.pause();
    setState(() => _running = true);
  }

  void _resume() {
    HapticFeedback.lightImpact();
    _recorder.resume();
    setState(() => _running = false);
  }

  Future<void> _finish() async {
    // Offline at finish is the expected failure mode: stay on the tracker
    // with the recording intact instead of red-screening.
    try {
      final summary = await _recorder.finish();
      if (mounted) {
        HapticFeedback.mediumImpact();
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
    final disableAnims = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration:
          disableAnims ? Duration.zero : const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _finished
          ? KeyedSubtree(
              key: const ValueKey('finish'),
              child: RunFinishScreen(
                summary: _summary,
                title: S.sportName(_summary?.jenis ?? widget.sportType),
                isHistoryDetail: true,
                aktivitasId: _summary?.aktivitasId,
                onBack: widget.onBack ??
                    () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => _finished = false);
                      }
                    },
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('tracker'),
              child: _buildActiveTracker(context),
            ),
    );
  }

  Widget _buildActiveTracker(BuildContext context) {
    // Back mid-run asks to discard instead of leaking an unfinished row
    // (dispose cancels GPS but never finishes).
    return PopScope(
      canPop: widget.onBack == null && !_recorder.started,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Live vector map behind the HUD; unobstructed & interactive in Map Focus mode.
            Positioned.fill(
              child: ListenableBuilder(
                listenable: _recorder,
                builder: (context, _) => RouteMap(
                  points: _recorder.points,
                  height: double.infinity,
                  fitBounds: _mapFocus,
                  showControls: _mapFocus,
                  showEmptyChip: false,
                  controlsPadding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + 148,
                    right: 24,
                  ),
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
                    final scheme = PacerScheme.of(context);
                    Widget header = Padding(
                      padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: scheme.card,
                              shape: BoxShape.circle,
                              boxShadow: [scheme.shadowBox],
                            ),
                            child: IconButton(
                              onPressed: _handleBack,
                              icon: Icon(Icons.arrow_back, color: scheme.ink),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.card.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: PacerColors.lime.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  switch (widget.sportType) {
                                    'bersepeda' => Icons.directions_bike,
                                    'joging' => Icons.directions_walk,
                                    'berjalan' => Icons.nordic_walking,
                                    _ => Icons.directions_run,
                                  },
                                  size: 14,
                                  color: PacerColors.lime,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.sportType.toUpperCase(),
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.ink,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          const GpsPill(),
                        ],
                      ),
                    );
                    Widget heroBlock = SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              fmtKmNum(_recorder.distanceM),
                              style: PacerText.giantNumOf(context, hero),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Text(
                            S.distanceKm,
                            style: TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 15,
                              color: scheme.overlay,
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
                    final kcal = estimateCaloriesKcal(
                      jenis: widget.sportType,
                      durasiS: _recorder.elapsed.inSeconds,
                      jarakM: _recorder.distanceM,
                    );
                    Widget stats = Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
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
                                  value: '$kcal ${S.unitKcal}',
                                  label: S.calories,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    Widget actions = Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              MapCircleButton(
                                size: circle,
                                active: _mapFocus,
                                icon: _mapFocus
                                    ? Icons.speed_rounded
                                    : Icons.map_outlined,
                                onTap: () =>
                                    setState(() => _mapFocus = !_mapFocus),
                              ),
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
                        ),
                      ),
                    );
                    if (_mapFocus) {
                      return Column(
                        children: [
                          header,
                          const SizedBox(height: 12),
                          _buildMapFocusHud(
                            context,
                            scheme,
                            paceText: paceText,
                            kcal: kcal,
                          ),
                          // Non-blocking spacer lets pan/zoom gestures pass to RouteMap.
                          const Expanded(
                            child: IgnorePointer(child: SizedBox.expand()),
                          ),
                          actions,
                          const SizedBox(height: 24),
                        ],
                      );
                    }
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

  Widget _buildMapFocusHud(
    BuildContext context,
    PacerScheme scheme, {
    required String paceText,
    required int kcal,
  }) {
    final items = <(String, String)>[
      ('${fmtKmNum(_recorder.distanceM)} km', S.metricDistance),
      (paceText, S.pace),
      (fmtDurasi(_recorder.elapsed.inSeconds), S.metricDuration),
      ('$kcal ${S.unitKcal}', S.metricCalories),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.card.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.softBorder),
              boxShadow: [scheme.shadowBox],
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        indent: 4,
                        endIndent: 4,
                        color: scheme.softBorder,
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                items[i].$1,
                                maxLines: 1,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              items[i].$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteGridPainter extends CustomPainter {
  final Color line;
  const _RouteGridPainter({this.line = const Color(0xFFCBD5E1)});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteGridPainter oldDelegate) =>
      oldDelegate.line != line;
}

/// Post-activity summary screen showing the recorded OSM route, totals, and
/// derived biomechanical/physiological metrics.
class RunFinishScreen extends StatefulWidget {
  final String? title;
  final bool isHistoryDetail;
  final VoidCallback? onBack;

  /// Real totals from a just-finished recording or selected history item.
  final RunSummary? summary;

  /// Loads and draws the saved GPS route when [summary.points] is empty.
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
  State<RunFinishScreen> createState() => _RunFinishScreenState();
}

class _RunFinishScreenState extends State<RunFinishScreen> {
  Future<List<RutePoint>>? _routeFuture;
  Future<UserProfile?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = _loadRoute();
    _profileFuture = _loadProfile();
  }

  @override
  void didUpdateWidget(covariant RunFinishScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.aktivitasId != oldWidget.aktivitasId ||
        widget.summary?.points != oldWidget.summary?.points) {
      _routeFuture = _loadRoute();
    }
  }

  Future<List<RutePoint>> _loadRoute() async {
    final pts = widget.summary?.points;
    if (pts != null && pts.isNotEmpty) return pts;
    final id = widget.aktivitasId;
    if (id == null || id.isEmpty) return const [];
    try {
      return await ActivityRepository().getRoute(id);
    } catch (_) {
      return const [];
    }
  }

  Future<UserProfile?> _loadProfile() async {
    try {
      return await AuthRepository().getProfile();
    } catch (_) {
      return null;
    }
  }

  void _goBack() {
    HapticFeedback.selectionClick();
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  List<(String, String, String, String)> _buildMetrics(
    RunSummary? summary,
    List<RutePoint> routePts,
    UserProfile? profile,
  ) {
    if (summary == null) {
      return [
        (S.stepLength, S.distanceBetweenSteps, '–', ''),
        (S.calories, S.totalEnergyBurned, '–', ''),
        (S.cadence, S.stepsPerMinute, '–', ''),
        (S.elevationGain, S.totalHeightClimb, '–', ''),
      ];
    }
    final m = computeRunMetrics(
      jenis: summary.jenis,
      durasiS: summary.durasiS,
      jarakM: summary.jarakM,
      points: routePts,
      weightKg: profile?.beratKg,
      heightCm: profile?.tinggiCm,
    );
    return [
      (
        S.stepLength,
        S.distanceBetweenSteps,
        m.stepLengthCm == null ? '–' : m.stepLengthCm!.round().toString(),
        m.stepLengthCm == null ? '' : 'cm',
      ),
      (S.calories, S.totalEnergyBurned, m.caloriesKcal.toString(), S.unitKcal),
      (
        S.cadence,
        S.stepsPerMinute,
        m.cadenceSpm == null ? '–' : m.cadenceSpm.toString(),
        m.cadenceSpm == null ? '' : 'spm',
      ),
      (
        S.elevationGain,
        S.totalHeightClimb,
        m.elevationGainM.round().toString(),
        'm',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final summary = widget.summary;
    final hasInlinePts = summary?.points.isNotEmpty ?? false;
    final hasLookupId =
        widget.aktivitasId != null && widget.aktivitasId!.isNotEmpty;
    final initialRouteData = hasInlinePts
        ? summary!.points
        : (!hasLookupId ? const <RutePoint>[] : null);
    final rawPace = summary != null
        ? fmtPace(summary.durasiS, summary.jarakM)
        : '';
    final paceText = summary != null
        ? (rawPace.isEmpty ? "0'00\"" : rawPace)
        : (widget.isHistoryDetail ? "5'00\"" : "0'00\"");

    return PopScope(
      canPop: widget.onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.onBack?.call();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.finishTop, scheme.finishBottom],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: CustomPaint(
                  painter: _RouteGridPainter(line: scheme.gridLine),
                ),
              ),
            ),
            SafeArea(
              child: ResponsiveScroll(
                maxWidth: 720,
                padding: const EdgeInsets.only(bottom: 120),
                child: FutureBuilder<List<RutePoint>>(
                  future: _routeFuture,
                  initialData: initialRouteData,
                  builder: (context, routeSnap) {
                    final waitingRoute =
                        routeSnap.connectionState == ConnectionState.waiting &&
                        !routeSnap.hasData;
                    final routePts = routeSnap.data ?? const <RutePoint>[];
                    final latLngs = [
                      for (final p in routePts) LatLng(p.lat, p.lng),
                    ];
                    final anchor =
                        (summary?.anchorLat != null &&
                            summary?.anchorLng != null)
                        ? LatLng(summary!.anchorLat!, summary.anchorLng!)
                        : null;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            PacerTapScale(
                              child: IconButton(
                                onPressed: _goBack,
                                icon: Icon(
                                  Icons.arrow_back,
                                  size: 28,
                                  color: scheme.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.title ?? S.running,
                          style: TextStyle(fontSize: 24, color: scheme.ink),
                        ),
                        const SizedBox(height: 20),
                        Container(height: 1, color: scheme.border),
                        const SizedBox(height: 20),
                        if (waitingRoute)
                          Container(
                            height: 250,
                            decoration: BoxDecoration(
                              color: scheme.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: scheme.hairline),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  S.loadingRoute,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.soft,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          RouteMap(
                            points: latLngs,
                            height: 250,
                            fitBounds: true,
                            showControls: true,
                            fallbackCenter: anchor,
                            emptyLabel: S.noGpsPoints,
                            borderRadius: 20,
                          ),
                        const SizedBox(height: 20),
                        SummaryLimeCard(
                          distance: summary != null
                              ? fmtKm(summary.jarakM)
                              : (widget.isHistoryDetail
                                    ? '3,00 Km'
                                    : '0,00 Km'),
                          duration: summary != null
                              ? fmtDurasi(summary.durasiS)
                              : (widget.isHistoryDetail ? '15.00' : '00.00'),
                          pace: paceText,
                        ),
                        const SizedBox(height: 18),
                        FutureBuilder<UserProfile?>(
                          future: _profileFuture,
                          builder: (context, profileSnap) {
                            final metrics = _buildMetrics(
                              summary,
                              routePts,
                              profileSnap.data,
                            );
                            return LayoutBuilder(
                              builder: (context, c) {
                                final cards = [
                                  for (final m in metrics)
                                    MetricCard(
                                      title: m.$1,
                                      sub: m.$2,
                                      value: m.$3,
                                      unit: m.$4,
                                    ),
                                ];
                                if (screenSizeOf(c.maxWidth) ==
                                    ScreenSize.compact) {
                                  return Column(
                                    children: [
                                      for (final card in cards)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 9,
                                          ),
                                          child: card,
                                        ),
                                    ],
                                  );
                                }
                                // medium and up: metric cards flow into a 2+
                                // column grid that grows with the width. Cells
                                // are 108 tall so two-line Indonesian subs
                                // never overflow the card.
                                return GridView(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 400,
                                        mainAxisSpacing: 9,
                                        crossAxisSpacing: 9,
                                        mainAxisExtent: 108,
                                      ),
                                  children: cards,
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        LimeActionBar(
                          S.done,
                          // Embedded in the tracker (not a pushed route)
                          // onBack returns cleanly; pushed detail screens pop.
                          onPressed: _goBack,
                        ),
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

/// Figma CLUBS list: Outfit 400/32 title + 358 search + 329x133 cards + buat-teams pill.
/// Live team list when signed in (search filters by name); Figma mock cards
/// in demo mode.
class TeamsScreen extends StatefulWidget {
  /// Returns to the Home tab (tabs have no pushed route to pop).
  final VoidCallback? onBack;
  const TeamsScreen({super.key, this.onBack});

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

  Future<List<Team>> _load({bool forceRefresh = false}) async {
    if (await isDemoAccount()) {
      return PacerDummyData.teams;
    }
    try {
      return await TeamRepository().listTeams(forceRefresh: forceRefresh);
    } catch (_) {
      return const [];
    }
  }

  /// Private teams are not listed: members join with the coach's code.
  Future<void> _joinByCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.joinByCode),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: S.teamCodeLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(S.join),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await isDemoAccount()) {
        messenger.showSnackBar(SnackBar(content: Text(S.demoJoinSent)));
        return;
      }
      await TeamRepository().joinByCode(code);
      if (!mounted) return;
      setState(() => _future = _load());
      messenger.showSnackBar(SnackBar(content: Text(S.join)));
    } on PostgrestException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kode salah. Coba lagi.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(offlineActionErrorMessage(e))),
      );
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

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Scaffold(
      backgroundColor: scheme.scaffold,
      body: SafeArea(
        child: ResponsiveScroll(
          onRefresh: () async {
            setState(() => _future = _load(forceRefresh: true));
            await _future;
          },
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onBack != null) ...[
                PageHeader(onBack: widget.onBack),
                const SizedBox(height: 12),
              ],
              Text(S.findTeamsNearby, style: PacerText.pageTitleOf(context)),
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
                  final live = teams != null && teams.isNotEmpty;
                  final filtered = (teams ?? const <Team>[])
                      .where(
                        (t) =>
                            !t.isPrivate &&
                            (_query.isEmpty ||
                                t.nama.toLowerCase().contains(
                                  _query.toLowerCase(),
                                )),
                      )
                      .toList();
                  // Grid shell always renders (stable layout); honest empty
                  // text underneath when there is nothing to show.
                  final emptyMsg = !live || _query.isEmpty
                      ? 'Belum ada tim.'
                      : 'Tidak ada tim yang cocok.';
                  final emptyIcon = !live || _query.isEmpty
                      ? Icons.groups_outlined
                      : Icons.search_off_outlined;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _teamGrid([
                        for (final t in filtered)
                          GestureDetector(
                            onTap: () => TeamDetailSheet.show(
                              context,
                              teamId: t.id,
                              teamName: t.nama,
                            ),
                            child: TeamCard(name: t.nama),
                          ),
                      ]),
                      if (filtered.isEmpty)
                        PacerEmptyState(emptyMsg, icon: emptyIcon),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _joinByCode,
                icon: const Icon(Icons.vpn_key_outlined),
                label: Text(S.joinByCode),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PersyaratanScreen()),
                ),
                child: Container(
                  width: double.infinity,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.card,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: scheme.border),
                    boxShadow: [scheme.shadowBox],
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
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(S.challenge),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        // Opens the first joined team's channel; falls back
                        // to the unscoped screen when signed out/offline.
                        try {
                          final mine = await TeamRepository().myTeams();
                          if (!context.mounted) return;
                          if (mine.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Belum gabung tim mana pun.'),
                              ),
                            );
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                teamId: mine.first.id,
                                teamName: mine.first.nama,
                              ),
                            ),
                          );
                        } catch (_) {
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ChatScreen(),
                              ),
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(S.teamChat),
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

/// Team detail bottom sheet: member count + join/leave + chat entry.
/// Chat stays reachable only after joining (RLS hides the channel otherwise).
class TeamDetailSheet extends StatefulWidget {
  final String teamId;
  final String teamName;
  const TeamDetailSheet({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  static void show(
    BuildContext context, {
    required String teamId,
    required String teamName,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (_) => TeamDetailSheet(teamId: teamId, teamName: teamName),
    );
  }

  @override
  State<TeamDetailSheet> createState() => _TeamDetailSheetState();
}

class _TeamDetailSheetState extends State<TeamDetailSheet> {
  bool? _joined;
  int? _memberCount;
  List<({String userId, String nama, String peran, String appPeran})>? _roster;
  bool _busy = false;
  Team? _team;
  bool _isCoach = false;
  String? _uid;
  // Server-decided: admin / creator / ketua / coach-member of THIS team.
  bool _canManage = false;
  String? _inviteCode;
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final uid = await AuthRepository().resolveUserId();
      final repo = TeamRepository();
      final team = await repo.getTeam(widget.teamId);
      String? peran;
      try {
        peran = (await AuthRepository().getProfile())?.peran;
      } catch (_) {
        /* stays null */
      }
      if (!mounted) return;
      setState(() {
        _uid = uid;
        _team = team;
        _isCoach = peran == 'coach' || peran == 'admin';
      });
      if (uid == null) {
        if (mounted) setState(() => _joined = false);
        return;
      }
      final roster = await repo.teamRoster(widget.teamId);
      // Secret code: the rpc answers only for managers of this team.
      String? code;
      try {
        code = await repo.getInviteCode(widget.teamId);
      } catch (_) {
        code = null;
      }
      if (!mounted) return;
      setState(() {
        _canManage = code != null;
        _inviteCode = code;
        _joined = roster.any((m) => m.userId == uid);
        // Exact for members/coaches; outsiders see only themselves.
        _memberCount = roster.length;
        _roster = roster;
      });
    } catch (_) {
      // Stays null: join attempt reports errors via snackbar.
    }
  }

  /// Coach kick: removes any member (server enforces coach-only).
  Future<void> _kick(String userId, String nama) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.kickMemberTitle),
        content: Text(S.kickMemberBody(nama)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.kickMemberConfirm),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await TeamRepository().removeMember(widget.teamId, userId);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineActionErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _toggle() async {
    // Leave path needs no code.
    if (_joined == true) {
      setState(() => _busy = true);
      try {
        await TeamRepository().leaveTeam(widget.teamId);
        if (mounted) setState(() => _joined = false);
        await _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(offlineActionErrorMessage(e))),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    final code = _code.text.trim();
    final isPublic = _team != null && !_team!.isPrivate;
    if (code.isEmpty && !isPublic) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Masukkan kode tim dulu.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await TeamRepository().joinTeam(widget.teamId, code);
      if (!mounted) return;
      setState(() => _joined = true);
      await _refresh();
    } on PostgrestException {
      // Wrong code (server-checked): distinct message, no raw error text.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Kode salah. Coba lagi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineActionErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Replaces the secret code (managers only; server enforces).
  Future<void> _regenerateCode() async {
    setState(() => _busy = true);
    try {
      final code = await TeamRepository().regenerateInviteCode(widget.teamId);
      if (mounted) setState(() => _inviteCode = code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineActionErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Coach CRUD: rename / retarget the team.
  Future<void> _editTeam() async {
    final team = _team;
    if (team == null) return;
    final name = TextEditingController(text: team.nama);
    final target = TextEditingController(
      text: team.targetNilai == null ? '' : '${team.targetNilai!.toInt()}',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.editTeamTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: S.teamName),
            ),
            TextField(
              controller: target,
              decoration: const InputDecoration(labelText: 'Target (m)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.saveLabel),
          ),
        ],
      ),
    );
    final nama = name.text.trim();
    final targetNilai = double.tryParse(target.text.trim());
    name.dispose();
    target.dispose();
    if (saved != true || nama.isEmpty || !mounted) return;
    try {
      await TeamRepository().updateTeam(
        team.id,
        nama: nama,
        targetNilai: targetNilai,
      );
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineActionErrorMessage(e))),
        );
      }
    }
  }

  /// Coach CRUD: delete the team (members cascade server-side).
  Future<void> _deleteTeam() async {
    final team = _team;
    if (team == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.deleteTeamTitle),
        content: Text(S.deleteTeamBody(team.nama)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.deleteConfirm),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await TeamRepository().deleteTeam(team.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineActionErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.teamName,
                        style: PacerText.pageTitleOf(context),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: PacerColors.ink),
                    ),
                  ],
                ),
                if (_joined == true && _memberCount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$_memberCount anggota',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
                // Member list: visible once joined (or to coaches, who see
                // the full roster). Coaches/admins get a tag; a coach can
                // kick anyone but themselves.
                if ((_joined == true || _isCoach) && _roster != null) ...[
                  const SizedBox(height: 12),
                  for (final m in _roster!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        m.nama,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (m.appPeran == 'coach' ||
                                        m.appPeran == 'admin') ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: PacerColors.lime,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          m.appPeran.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: PacerColors.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  m.peran,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isCoach && m.userId != _uid)
                            TextButton(
                              onPressed: () => _kick(m.userId, m.nama),
                              child: const Text('Keluarkan'),
                            ),
                        ],
                      ),
                    ),
                ],
                // Invite code: shown once joined (or to coaches) — never to
                // outsiders, or the code gate would be decorative.
                if (_canManage && _inviteCode != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${S.teamCodeLabel}: ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Flexible(
                        child: SelectableText(
                          _inviteCode!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _regenerateCode,
                        child: Text(S.regenerateCode),
                      ),
                    ],
                  ),
                ],
                // Private teams: joiners type the shared code; the server
                // verifies it. Public teams join directly.
                if (_joined != true && (_team?.isPrivate ?? true)) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Kode tim',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                // Coach CRUD.
                if (_isCoach) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _editTeam,
                          child: const Text('Ubah'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _deleteTeam,
                          child: const Text('Hapus'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                LimeActionBar(
                  _joined == true ? S.leaveChallenge : S.join,
                  onPressed: _busy ? null : _toggle,
                ),
                if (_joined == true) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              teamId: widget.teamId,
                              teamName: widget.teamName,
                            ),
                          ),
                        );
                      },
                      child: Text(S.teamChat),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma leaderboard podium page + rows 4-8 with lime-highlighted you-row.
/// Live standings (first board) when signed in; Figma mock rows in demo mode.
/// Your own row is highlighted by user id, never by name matching.
class LeaderboardScreen extends StatefulWidget {
  /// Returns to the Home tab (tabs have no pushed route to pop).
  final VoidCallback? onBack;
  const LeaderboardScreen({super.key, this.onBack});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

/// Live board data; [rows] null in demo mode (mock rows show).
class _BoardData {
  final String? boardNama;
  final List<({Peringkat entry, String nama})>? rows;
  final String? uid;
  final List<Leaderboard> allBoards;

  /// Region scope picked but the user never set a region.
  final bool needsRegion;
  const _BoardData({
    this.boardNama,
    this.rows,
    this.uid,
    this.allBoards = const [],
    this.needsRegion = false,
  });
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Future<_BoardData>? _future;
  String _selectedMetric = 'semua';
  String _selectedPeriod = 'semua';
  // 'team' | 'region' | 'global' — Tim Saya is the default (class view).
  String _scope = 'team';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BoardData> _load({bool forceRefresh = false}) async {
    try {
      if (await isDemoAccount()) {
        final d = PacerDummyData.getLeaderboardData(
          metric: _selectedMetric,
          period: _selectedPeriod,
          scope: _scope,
        );
        return _BoardData(boardNama: d.boardNama, rows: d.rows, uid: d.uid);
      }
      final uid = await AuthRepository().resolveUserId();
      if (_scope == 'region') {
        final me = await AuthRepository().getProfile(
          forceRefresh: forceRefresh,
        );
        if (me?.region == null) {
          return _BoardData(uid: uid, needsRegion: true);
        }
      }
      final repo = LeaderboardRepository();
      final boards = await repo.listLeaderboards(
        limit: 20,
        forceRefresh: forceRefresh,
      );
      if (boards.isEmpty) {
        return _BoardData(uid: uid, allBoards: boards);
      }

      Leaderboard activeBoard = boards.first;
      for (final b in boards) {
        final matchMetric =
            _selectedMetric == 'semua' ||
            b.kriteria.toLowerCase().contains(_selectedMetric.toLowerCase());
        final matchPeriod =
            _selectedPeriod == 'semua' ||
            b.periode.toLowerCase().contains(_selectedPeriod.toLowerCase());
        if (matchMetric && matchPeriod) {
          activeBoard = b;
          break;
        }
      }

      var rows = await repo.getPeringkatWithNames(
        activeBoard.id,
        forceRefresh: forceRefresh,
      );
      if (rows.isNotEmpty && _scope != 'global') {
        // Server-side scope: only people sharing my team / region.
        try {
          final ids = await repo.scopeUserIds(
            _scope,
            forceRefresh: forceRefresh,
          );
          rows = rows.where((r) => ids.contains(r.entry.userId)).toList();
        } catch (_) {
          // Scope unavailable (migration not applied): keep the full board.
        }
        return _BoardData(
          boardNama: activeBoard.nama,
          rows: rows,
          uid: uid,
          allBoards: boards,
        );
      }
      return _BoardData(
        boardNama: activeBoard.nama,
        rows: rows,
        uid: uid,
        allBoards: boards,
      );
    } catch (_) {
      if (await isDemoAccount()) {
        final d = PacerDummyData.getLeaderboardData(
          metric: _selectedMetric,
          period: _selectedPeriod,
          scope: _scope,
        );
        return _BoardData(boardNama: d.boardNama, rows: d.rows, uid: d.uid);
      }
      return _BoardData(uid: await AuthRepository().resolveUserId());
    }
  }

  void _onFilterChanged({String? metric, String? period, String? scope}) {
    setState(() {
      if (metric != null) _selectedMetric = metric;
      if (period != null) _selectedPeriod = period;
      if (scope != null) _scope = scope;
      _future = _load();
    });
  }

  Widget _standingRow({
    required int rank,
    required String name,
    required String value,
    required bool mine,
  }) {
    final scheme = PacerScheme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? PacerColors.lime : scheme.border),
        color: mine ? PacerColors.lime.withValues(alpha: 0.1) : scheme.card,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = PacerScheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? PacerColors.lime : scheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? PacerColors.lime : scheme.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: PacerColors.lime.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? PacerColors.navy : scheme.ink,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? PacerColors.navy : scheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Figma mock board (demo mode or fewer than 3 ranked rows).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PacerScheme.of(context).scaffold,
      body: SafeArea(
        child: ResponsiveScroll(
          onRefresh: () async {
            setState(() => _future = _load(forceRefresh: true));
            await _future;
          },
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onBack != null) ...[
                PageHeader(onBack: widget.onBack),
                const SizedBox(height: 12),
              ],
              Text(S.teamsLeaderboard, style: PacerText.pageTitleOf(context)),
              const SizedBox(height: 12),
              // Scope: who am I ranked against.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: S.scopeMyTeam,
                      icon: Icons.groups,
                      selected: _scope == 'team',
                      onTap: () => _onFilterChanged(scope: 'team'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: S.scopeRegion,
                      icon: Icons.location_on,
                      selected: _scope == 'region',
                      onTap: () => _onFilterChanged(scope: 'region'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: S.scopeGlobal,
                      icon: Icons.public,
                      selected: _scope == 'global',
                      onTap: () => _onFilterChanged(scope: 'global'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: S.allTime,
                      selected:
                          _selectedMetric == 'semua' &&
                          _selectedPeriod == 'semua',
                      onTap: () =>
                          _onFilterChanged(metric: 'semua', period: 'semua'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: S.metricDistance,
                      icon: Icons.straighten,
                      selected: _selectedMetric == 'jarak',
                      onTap: () => _onFilterChanged(
                        metric: _selectedMetric == 'jarak' ? 'semua' : 'jarak',
                      ),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: S.metricCalories,
                      icon: Icons.local_fire_department,
                      selected: _selectedMetric == 'kalori',
                      onTap: () => _onFilterChanged(
                        metric: _selectedMetric == 'kalori'
                            ? 'semua'
                            : 'kalori',
                      ),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: S.metricDuration,
                      icon: Icons.timer,
                      selected: _selectedMetric == 'durasi',
                      onTap: () => _onFilterChanged(
                        metric: _selectedMetric == 'durasi'
                            ? 'semua'
                            : 'durasi',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      height: 20,
                      width: 1,
                      color: PacerScheme.of(context).border,
                    ),
                    const SizedBox(width: 16),
                    _filterChip(
                      label: S.periodWeekly,
                      selected: _selectedPeriod == 'mingguan',
                      onTap: () => _onFilterChanged(
                        period: _selectedPeriod == 'mingguan'
                            ? 'semua'
                            : 'mingguan',
                      ),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: S.periodMonthly,
                      selected: _selectedPeriod == 'bulanan',
                      onTap: () => _onFilterChanged(
                        period: _selectedPeriod == 'bulanan'
                            ? 'semua'
                            : 'bulanan',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<_BoardData>(
                future: _future,
                builder: (context, snap) {
                  final d = snap.data;
                  final rows = d?.rows;
                  if (d?.needsRegion == true) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: PacerScheme.of(context).border,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.location_off_outlined, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            S.regionNotSet,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(S.regionPrompt, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AboutMeScreen(),
                                ),
                              );
                              if (mounted) {
                                setState(() => _future = _load());
                              }
                            },
                            child: Text(S.setRegion),
                          ),
                        ],
                      ),
                    );
                  }
                  // No mocks: offline and empty both show the empty state.
                  if (rows == null || rows.isEmpty) {
                    return PacerEmptyState(
                      S.emptyLeaderboard,
                      icon: Icons.leaderboard_outlined,
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
                            value: _formatMetricValue(rows[i].entry.nilai),
                            mine: rows[i].entry.userId == uid,
                          ),
                      ],
                    );
                  }
                  final uid = d?.uid;
                  final top = rows.take(3).toList();
                  final rest = rows.skip(3).toList();
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _podium(
                            top[1].nama,
                            _formatMetricValue(top[1].entry.nilai),
                            68,
                            PacerColors.podiumGray,
                            rank: 2,
                            medal: PacerColors.medalSilver,
                          ),
                          _podium(
                            top[0].nama,
                            _formatMetricValue(top[0].entry.nilai),
                            89,
                            PacerColors.medalGold,
                            rank: 1,
                            medal: PacerColors.medalGold,
                          ),
                          _podium(
                            top[2].nama,
                            _formatMetricValue(top[2].entry.nilai),
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
                          value: _formatMetricValue(rest[i].entry.nilai),
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
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(S.statistic),
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
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
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

  String _formatMetricValue(double v) {
    if (_selectedMetric == 'kalori') {
      final unit = langNotifier.value == Lang.en ? 'kcal' : 'kkal';
      return '${v.round()} $unit';
    } else if (_selectedMetric == 'durasi') {
      final totalMin = v.round();
      if (totalMin >= 60) {
        final h = totalMin ~/ 60;
        final m = totalMin % 60;
        final hUnit = langNotifier.value == Lang.en ? 'h' : 'j';
        return m > 0 ? '$h$hUnit ${m}m' : '$h$hUnit';
      }
      final unit = langNotifier.value == Lang.en ? 'min' : 'mnt';
      return '$totalMin $unit';
    } else {
      // 'jarak' or 'semua'
      return '${v.toStringAsFixed(1)} Km';
    }
  }

  Widget _podium(
    String name,
    String valueText,
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
          InitialAvatar(initialsOf(name)),
          SizedBox(
            width: 88,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          Text(
            valueText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
  Future<List<LocalActivity>>? _future;
  bool _isDemo = false;
  bool _wasSyncing = false;

  @override
  void initState() {
    super.initState();
    SyncEngine.instance.addListener(_onSyncChanged);
    _future = _load();
  }

  @override
  void dispose() {
    SyncEngine.instance.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    final syncing = SyncEngine.instance.status.isSyncing;
    if (_wasSyncing && !syncing && mounted) {
      setState(() => _future = _load());
    }
    _wasSyncing = syncing;
  }

  Future<List<LocalActivity>> _load({bool forceRefresh = false}) async {
    if (await isDemoAccount()) {
      _isDemo = true;
      final now = DateTime.now();
      return [
        for (final a in PacerDummyData.activities)
          LocalActivity(
            activity: a,
            syncState: SyncState.synced,
            updatedAt: a.selesaiAt ?? a.mulaiAt ?? now,
          ),
      ];
    }
    _isDemo = false;
    try {
      return await ActivityRepository().listLocalActivities(
        limit: 50,
        forceRefresh: forceRefresh,
      );
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

  Widget _activityCard(LocalActivity item) {
    final a = item.activity;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RunFinishScreen(
            title: '${S.sportName(a.jenis)} ${fmtDate(a.mulaiAt)}'.trim(),
            isHistoryDetail: true,
            aktivitasId: a.id,
            summary: RunSummary(
              aktivitasId: a.id,
              jenis: a.jenis,
              jarakM: a.jarakM ?? 0,
              durasiS: a.durasiS ?? 0,
              pointCount: 0,
            ),
          ),
        ),
      ),
      child: RunSessionCard(
        title: S.sportName(a.jenis),
        date: fmtDate(a.mulaiAt),
        time: fmtDurasi(a.durasiS),
        pace: fmtPace(a.durasiS, a.jarakM),
        distance: fmtKm(a.jarakM),
        syncState: _isDemo ? null : item.syncState,
      ),
    );
  }

  /// Figma mock hero + cards (demo mode) or offline-first SSOT activities.
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: PacerScheme.of(context).scaffold,
      body: SafeArea(
        child: ResponsiveScroll(
          onRefresh: () async {
            setState(() => _future = _load(forceRefresh: true));
            await _future;
          },
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
              Text(S.history, style: PacerText.pageTitleOf(context)),
              if (!_isDemo) const SizedBox(height: 8),
              if (!_isDemo) const SyncStatusBanner(),
              FutureBuilder<List<LocalActivity>>(
                future: _future,
                builder: (context, snap) {
                  final list = snap.data ?? const <LocalActivity>[];
                  final totalKm = list.fold<double>(
                    0,
                    (s, item) => s + (item.activity.jarakM ?? 0),
                  );
                  final totalS = list.fold<int>(
                    0,
                    (s, item) => s + (item.activity.durasiS ?? 0),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero scales down instead of overflowing at 360px.
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Hero number scales with width (fluid 88→140).
                              Text(
                                fmtKmNum(totalKm),
                                style: PacerText.giantNumOf(
                                  context,
                                  fluid(w, 88, 140),
                                ),
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
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Wrap instead of a fixed Row so the summary never overflows.
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        children: [
                          Text(
                            '${list.length} Run',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 24,
                            ),
                          ),
                          Text(
                            list.isEmpty
                                ? '– Average Pace'
                                : '${fmtPace(totalS, totalKm)} Average Pace',
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
                        for (final a in list) _activityCard(a),
                      ]),
                      if (list.isEmpty &&
                          snap.connectionState != ConnectionState.waiting)
                        PacerEmptyState(
                          S.noRunsOfflineEmpty,
                          icon: Icons.directions_run_outlined,
                        ),
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
class _ChallengeBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _ChallengeBadge(this.label, {required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _challengeWindowText(Challenge c) {
  final start = c.waktuMulai;
  final end = c.waktuSelesai;
  if (start != null && end != null) {
    return '${fmtDate(start)} - ${fmtDate(end)}';
  }
  if (end != null) return 's/d ${fmtDate(end)}';
  if (start != null) return '${fmtDate(start)} - ${S.challengeOpenEnded}';
  return S.challengeOpenEnded;
}

class ChallengeDetailSheet extends StatefulWidget {
  final String? challengeId;
  final Challenge? challenge;
  final PartisipasiChallenge? participation;

  const ChallengeDetailSheet({
    super.key,
    this.challengeId,
    this.challenge,
    this.participation,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? challengeId,
    Challenge? challenge,
    PartisipasiChallenge? participation,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChallengeDetailSheet(
        challengeId: challengeId ?? challenge?.id,
        challenge: challenge,
        participation: participation,
      ),
    );
  }

  @override
  State<ChallengeDetailSheet> createState() => _ChallengeDetailSheetState();
}

class _ChallengeDetailSheetState extends State<ChallengeDetailSheet> {
  Challenge? _challenge;
  PartisipasiChallenge? _participation;
  bool? _joined;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    _participation = widget.participation;
    if (widget.participation != null) _joined = true;
    _load();
  }

  @override
  void didUpdateWidget(covariant ChallengeDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challengeId != widget.challengeId ||
        oldWidget.challenge != widget.challenge ||
        oldWidget.participation != widget.participation) {
      _challenge = widget.challenge;
      _participation = widget.participation;
      _joined = widget.participation != null ? true : null;
      _load();
    }
  }

  String? get _resolvedId => widget.challengeId ?? _challenge?.id;

  Future<bool> _isLive() async =>
      !(await isDemoAccount()) && _resolvedId != null;

  Challenge? _findDemoChallenge(String? id) {
    if (id != null) {
      for (final c in PacerDummyData.challenges) {
        if (c.id == id) return c;
      }
    }
    return PacerDummyData.challenges.isEmpty
        ? null
        : PacerDummyData.challenges.first;
  }

  PartisipasiChallenge? _matchParticipation(
    List<PartisipasiChallenge> parts,
    String id,
  ) {
    for (final p in parts) {
      if (p.challengeId == id) return p;
    }
    return null;
  }

  Future<void> _load() async {
    final id = _resolvedId;
    if (await isDemoAccount()) {
      final demo = _challenge ?? _findDemoChallenge(id);
      if (mounted) {
        setState(() {
          _challenge = demo;
          _joined ??= false;
        });
      }
      return;
    }
    if (id == null) return;
    try {
      final repo = ChallengeRepository();
      final chal = _challenge ?? await repo.getChallengeById(id);
      final parts = await repo.myParticipations();
      final matched = _matchParticipation(parts, id);
      if (mounted) {
        setState(() {
          _challenge = chal ?? _challenge;
          _participation = matched;
          _joined = matched != null;
        });
      }
    } catch (_) {
      /* stays in current state → toggle handles offline/network errors */
    }
  }

  Future<void> _toggle() async {
    final id = _resolvedId;
    if (!await _isLive() || id == null) {
      if (mounted) {
        final next = !(_joined == true);
        setState(() {
          _joined = next;
          _participation = next && _challenge != null
              ? PartisipasiChallenge(
                  id: 'demo-part-${_challenge!.id}',
                  challengeId: _challenge!.id,
                  userId: 'demo',
                )
              : null;
          _changed = true;
        });
        if (next) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.demoChallengeStarted)),
          );
        }
      }
      return;
    }
    final chal = _challenge;
    if (_joined != true && chal != null && !isChallengeActive(chal, DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.challengeEndedJoinBlocked)),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ChallengeRepository();
      if (_joined == true) {
        await repo.leaveChallenge(id);
        if (mounted) {
          setState(() {
            _joined = false;
            _participation = null;
            _changed = true;
          });
        }
      } else {
        await repo.joinChallenge(id);
        final parts = await repo.myParticipations();
        final matched = _matchParticipation(parts, id);
        if (mounted) {
          setState(() {
            _joined = true;
            _participation =
                matched ??
                PartisipasiChallenge(
                  id: 'local-$id',
                  challengeId: id,
                  userId: '',
                  createdAt: DateTime.now(),
                );
            _changed = true;
          });
        }
      }
      if (mounted && !ConnectivityService.instance.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.queuedOfflineSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineActionErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final chal = _challenge;
    final part = _participation;
    final active = chal == null || isChallengeActive(chal, DateTime.now());
    final canToggle = _joined == true || active;
    final pct = (chal != null && part != null)
        ? progressPercent(part.progressNilai, chal.targetNilai)
        : 0.0;
    final pctLabel = pct == pct.truncateToDouble()
        ? '${pct.toInt()}%'
        : '${pct.toStringAsFixed(1)}%';
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.challengeDetail,
                        style: PacerText.pageTitleOf(context),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(_changed),
                      icon: Icon(Icons.close, color: scheme.ink),
                    ),
                  ],
                ),
                if (chal == null) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 24),
                ] else ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChallengeBadge(
                        S.sportName(chal.jenis),
                        bg: scheme.card,
                        fg: scheme.ink,
                      ),
                      if (part?.berhasil == true)
                        _ChallengeBadge(
                          S.challengeCompletedLabel,
                          bg: scheme.success.withValues(alpha: 0.16),
                          fg: scheme.success,
                        )
                      else if (!active)
                        _ChallengeBadge(
                          S.challengeEnded,
                          bg: scheme.error.withValues(alpha: 0.14),
                          fg: scheme.error,
                        )
                      else
                        _ChallengeBadge(
                          S.challengeActive,
                          bg: PacerColors.primary.withValues(alpha: 0.22),
                          fg: scheme.ink,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            S.challengeTargetValue(
                              chal.targetNilai,
                              chal.targetSatuan,
                            ),
                            style: PacerText.giantNum(88)
                                .copyWith(color: PacerColors.primary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            S.challengeTargetUnit(chal.targetSatuan),
                            style: PacerText.kmSuffix,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${chal.targetSatuan == 'jarak_m' ? S.distance : S.targetTime}: '
                    '${S.challengeTargetSummary(chal.targetNilai, chal.targetSatuan)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: scheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${S.date}: ${_challengeWindowText(chal)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: scheme.soft,
                    ),
                  ),
                  if (_joined == true && part != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.softBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  S.challengeProgressLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: scheme.ink,
                                  ),
                                ),
                              ),
                              Text(
                                pctLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: part.berhasil
                                      ? scheme.success
                                      : PacerColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (pct / 100).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: scheme.softBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                part.berhasil
                                    ? scheme.success
                                    : PacerColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${S.challengeTargetSummary(part.progressNilai, chal.targetSatuan)} / '
                            '${S.challengeTargetSummary(chal.targetNilai, chal.targetSatuan)}'
                            '${part.berhasil ? ' • ${S.challengeCompletedLabel}' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.soft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                LimeActionBar(
                  _joined == true
                      ? S.leaveChallenge
                      : (!active ? S.challengeEnded : S.startChallenge),
                  onPressed: (_busy || !canToggle) ? null : _toggle,
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
  bool _isDemo = true;

  @override
  void initState() {
    super.initState();
    _load().then((p) {
      if (mounted) {
        setState(() {
          _profile = (nama: p.nama, email: p.email);
          _isDemo = p.isDemo;
        });
      }
    });
  }

  Future<({String? nama, String? email, bool isDemo})> _load() async {
    try {
      if (await isDemoAccount()) {
        return (nama: null, email: null, isDemo: true);
      }
      final auth = AuthRepository();
      final profile = await auth.getProfile();
      final email = await auth.getSavedEmail();
      return (nama: profile?.nama, email: email, isDemo: false);
    } catch (_) {
      return (nama: null, email: null, isDemo: await isDemoAccount());
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
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
            Icon(
              Icons.chevron_right,
              size: 20,
              color: PacerScheme.of(context).soft,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Scaffold(
      backgroundColor: scheme.scaffold,
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
                    decoration: BoxDecoration(
                      color: scheme.card,
                      shape: BoxShape.circle,
                      boxShadow: [scheme.shadowBox],
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: Icon(Icons.arrow_back, color: scheme.ink),
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
                  border: Border.all(color: scheme.border),
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
                    Divider(height: 1, color: scheme.border),
                    _menuRow(
                      context,
                      label: S.aboutMe,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AboutMeScreen(),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: scheme.border),
                    _menuRow(
                      context,
                      label: S.features,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FiturScreen()),
                      ),
                    ),
                    Divider(height: 1, color: scheme.border),
                    _menuRow(
                      context,
                      label: S.language,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LanguageSettingsScreen(),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: scheme.border),
                    _menuRow(
                      context,
                      // Theme toggle lives next to the language setting;
                      // hardcoded label follows that screen's precedent.
                      label: 'Tema',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ThemeSettingsScreen(),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: scheme.border),
                    _menuRow(
                      context,
                      label: S.out,
                      onTap: () async {
                        if (!_isDemo) {
                          final pending = await AuthRepository()
                              .pendingSyncCount();
                          if (pending > 0) {
                            if (!context.mounted) return;
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(S.unsyncedSignOutTitle),
                                content: Text(S.unsyncedSignOutBody(pending)),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: Text(S.cancelLabel),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text(S.signOutAnyway),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) return;
                          }
                        }
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
              if (!_isDemo) ...[
                const SizedBox(height: 16),
                const SyncStatusBanner(margin: EdgeInsets.zero),
              ],
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
  Future<List<LatLng>>? _latestRouteFuture;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _latestRouteFuture = _loadLatestRoute();
  }

  /// Loads GPS route points from the most recent recorded workout for OSM.
  Future<List<LatLng>> _loadLatestRoute() async {
    if (await isDemoAccount()) return const [];
    try {
      final repo = ActivityRepository();
      final acts = await repo.listLocalActivities(limit: 1);
      if (acts.isEmpty) return const [];
      final pts = await repo.getRoute(acts.first.activity.id);
      return [for (final p in pts) LatLng(p.lat, p.lng)];
    } catch (_) {
      return const [];
    }
  }

  /// This week's distance + time; null when signed in and empty.
  Future<({double km, int seconds})?> _load() async {
    if (await isDemoAccount()) return PacerDummyData.statistics;
    try {
      final repo = ActivityRepository();
      final stats = await repo.getStatistik(periodeKey(DateTime.now()));
      if (stats == null || (stats.jarakM <= 0 && stats.waktuS <= 0)) {
        return null;
      }
      return (km: stats.jarakM / 1000, seconds: stats.waktuS);
    } catch (_) {
      return null;
    }
  }

  /// Figma mock totals (demo mode or empty week).
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
              Text(S.statistic, style: PacerText.pageTitleOf(context)),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  Widget map = FutureBuilder<List<LatLng>>(
                    future: _latestRouteFuture,
                    builder: (context, snap) => RouteMap(
                      points: snap.data ?? const [],
                      height: 180,
                      fitBounds: true,
                      showControls: true,
                      emptyLabel: S.noGpsPoints,
                      borderRadius: 16,
                    ),
                  );
                  Widget total = FutureBuilder<({double km, int seconds})?>(
                    future: _future,
                    builder: (context, snap) {
                      final d = snap.data;
                      // No mocks: offline and empty week show zeros.
                      if (d == null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '0,00 Km',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 32,
                              ),
                            ),
                            Text(
                              S.totalRunDistance,
                              style: TextStyle(
                                fontSize: 11,
                                color: PacerScheme.of(context).soft,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(S.averagePace, '–', '/km'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatCard(S.totalTime, '–', 'menit'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatCard(
                                    S.activeCalories,
                                    '–',
                                    'kkal',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
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
                              color: PacerScheme.of(context).soft,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                  if (screenSizeOf(c.maxWidth) != ScreenSize.expanded) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [map, const SizedBox(height: 16), total],
                    );
                  }
                  // Expanded only: map pane beside the stats pane. Medium
                  // keeps the stacked column so the 3 stat cards keep full
                  // width instead of squeezing into half a tablet.
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
    final scheme = PacerScheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.soft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: scheme.headline,
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 12, color: scheme.soft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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

  Future<({int count, DateTime? terakhir, double totalKm})?> _load() async {
    if (await isDemoAccount()) {
      return (
        count: 5,
        terakhir: DateTime.now().subtract(const Duration(hours: 4)),
        totalKm: 45.2,
      );
    }
    try {
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
      return (count: 0, terakhir: null, totalKm: 0.0);
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

  /// Honest empty week for offline / no-streak states (rendered inside
  /// the card now — the strip lives in [StreakCard]).
  static const _emptyWeek = [false, false, false, false, false, false, false];

  /// Figma mock strip (demo mode or no streak yet).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PacerScheme.of(context).scaffold,
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
              Text(S.streaks, style: PacerText.pageTitleOf(context)),
              const SizedBox(height: 12),
              FutureBuilder<({int count, DateTime? terakhir, double totalKm})?>(
                future: _future,
                builder: (context, snap) {
                  final d = snap.data;
                  // No mocks: offline and no streak show an empty week.
                  if (d == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MINGGU INI • 0 dari 7 Hari',
                          style: TextStyle(
                            color: PacerColors.streakBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StreakCard(
                          count: 0,
                          done: _emptyWeek,
                          todayIndex: DateTime.now().weekday - 1,
                        ),
                      ],
                    );
                  }
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
                      StreakCard(
                        count: d.count,
                        done: done,
                        todayIndex: todayIdx,
                      ),
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
typedef _ChallengeListData = ({
  List<Challenge> challenges,
  Map<String, PartisipasiChallenge> participations,
});

class ChallengeListScreen extends StatefulWidget {
  const ChallengeListScreen({super.key});

  @override
  State<ChallengeListScreen> createState() => _ChallengeListScreenState();
}

class _ChallengeListScreenState extends State<ChallengeListScreen> {
  Future<_ChallengeListData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Future<_ChallengeListData> _load() async {
    if (await isDemoAccount()) {
      return (
        challenges: PacerDummyData.challenges
            .where((c) => c.diumumkan)
            .toList(),
        participations: const <String, PartisipasiChallenge>{},
      );
    }
    try {
      final repo = ChallengeRepository();
      final challenges = (await repo.listChallenges())
          .where((c) => c.diumumkan)
          .toList();
      final parts = await repo.myParticipations();
      return (
        challenges: challenges,
        participations: {for (final p in parts) p.challengeId: p},
      );
    } catch (_) {
      return (
        challenges: const <Challenge>[],
        participations: const <String, PartisipasiChallenge>{},
      );
    }
  }

  String _heroDate(Challenge c) {
    final d = c.waktuSelesai ?? c.waktuMulai;
    if (d == null) return S.challengeOpenEnded;
    return '${d.day}-${d.month}-${d.year}';
  }

  Widget _challengeCard(
    BuildContext context,
    double w,
    Challenge c,
    PartisipasiChallenge? part,
  ) {
    final active = isChallengeActive(c, DateTime.now());
    final pct = part == null
        ? 0.0
        : progressPercent(part.progressNilai, c.targetNilai);
    final statusLabel = part?.berhasil == true
        ? S.challengeCompletedLabel
        : !active
        ? S.challengeEnded
        : part != null
        ? S.joinedChallenge
        : S.challengeActive;
    final statusBg = part?.berhasil == true
        ? Colors.green.withValues(alpha: 0.25)
        : !active
        ? Colors.white12
        : part != null
        ? PacerColors.primary.withValues(alpha: 0.25)
        : Colors.white12;
    final statusFg = part?.berhasil == true
        ? Colors.greenAccent
        : !active
        ? Colors.white70
        : part != null
        ? PacerColors.primary
        : Colors.white;

    return GestureDetector(
      onTap: () async {
        await ChallengeDetailSheet.show(
          context,
          challengeId: c.id,
          challenge: c,
          participation: part,
        );
        _reload();
      },
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: fluid(w, 179, 220)),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [
              PacerColors.teamShade,
              PacerColors.streakBg,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _ChallengeBadge(
                  S.sportName(c.jenis),
                  bg: Colors.white12,
                  fg: Colors.white,
                ),
                const Spacer(),
                _ChallengeBadge(
                  statusLabel,
                  bg: statusBg,
                  fg: statusFg,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Hero number flexes and scales down so long
                // live values never push the date off-screen.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      S.challengeTargetValue(c.targetNilai, c.targetSatuan),
                      style: PacerText.giantNum(
                        fluid(w, 84, 128),
                      ).copyWith(color: PacerColors.primary),
                    ),
                  ),
                ),
                Text(
                  ' ${S.challengeTargetUnit(c.targetSatuan)}',
                  style: PacerText.kmSuffix.copyWith(fontSize: 36),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _heroDate(c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            if (part != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    part.berhasil ? Colors.greenAccent : PacerColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${S.challengeTargetSummary(part.progressNilai, c.targetSatuan)} / '
                '${S.challengeTargetSummary(c.targetNilai, c.targetSatuan)} • '
                '${pct.toInt()}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
              Text(S.challenge, style: PacerText.pageTitleOf(context)),
              const SizedBox(height: 12),
              FutureBuilder<_ChallengeListData>(
                future: _future,
                builder: (context, snap) {
                  final data = snap.data;
                  final live = data?.challenges;
                  // No mocks: offline and empty both show the empty state.
                  if (live == null || live.isEmpty) {
                    return PacerEmptyState(
                      S.noChallengesCachedEmpty,
                      icon: Icons.emoji_events_outlined,
                    );
                  }
                  final parts = data!.participations;
                  return Column(
                    children: [
                      for (final c in live)
                        _challengeCard(context, w, c, parts[c.id]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateChallengeScreen(),
                      ),
                    );
                    _reload();
                  },
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
                style: PacerText.pageTitleOf(context).copyWith(fontSize: 24),
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
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: PacerScheme.of(context).deepInk,
                              ),
                            ),
                            Text(
                              r.$2,
                              style: TextStyle(
                                fontSize: 12,
                                color: PacerScheme.of(context).formMuted,
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
                    foregroundColor: PacerColors.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    S.agree,
                    style: TextStyle(color: PacerColors.ink),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
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
  // Private by default: joining needs the coach's secret code.
  bool _private = true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final nama = _name.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = S.errFillAll);
      return;
    }
    if (await isDemoAccount()) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.demoJoinSent)));
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await TeamRepository().createTeam(nama: nama, isPrivate: _private);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.teamCreated)));
        Navigator.of(context).pop();
      }
    } on PostgrestException catch (e) {
      setState(
        () => _error = e.code == '42501' ? S.coachOnly : S.errSaveFailed,
      );
    } catch (e) {
      setState(() => _error = offlineActionErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
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
              Text(S.createTeam, style: PacerText.pageTitleOf(context)),
              const SizedBox(height: 12),
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.formField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.formEdge, width: 2),
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
                  fillColor: scheme.formField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AuthErrorText(_error!),
              ],
              const SizedBox(height: 16),
              Text(S.clubFocus),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
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
                  fillColor: scheme.formField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(S.communityPrivacy),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.public, size: 16),
                    label: Text(S.publicLabel),
                    selected: !_private,
                    onSelected: (_) => setState(() => _private = false),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.lock, size: 16),
                    label: Text(S.privateLabel),
                    selected: _private,
                    onSelected: (_) => setState(() => _private = true),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _private ? S.privateTeamHint : S.publicTeamHint,
                style: TextStyle(
                  fontSize: 12,
                  color: PacerScheme.of(context).soft,
                ),
              ),
              const SizedBox(height: 24),
              LimeActionBar(S.createTeam, onPressed: _busy ? null : _submit),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
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

/// Figma buat challenge teams form (coach only — server rejects others).
/// JARAK presets or TARGET presets define the distance (TARGET wins when
/// touched; Lainnya/Custom open a km dialog). DURASI sets the window.
class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  int _jenisIdx = 0; // 'lari'
  int _jarak = 1; // '5 km'
  int _durasi = 2; // week
  int _target = -1; // untouched
  double? _customKm;
  bool _busy = false;
  String? _error;

  static const _jarakKm = [3.0, 5.0, 10.0];
  static const _durasiDays = [1, 3, 7];
  static const _targetKm = [25.0, 30.0, 45.0];

  Future<double?> _askCustomKm() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jarak custom (km)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(S.saveLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return null;
    final v = double.tryParse(result.replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  Future<void> _tapCustom(ValueChanged<double> apply) async {
    final v = await _askCustomKm();
    if (v == null || !mounted) return;
    setState(() {
      _customKm = v;
      apply(v);
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    double? targetKm;
    if (_target >= 0 && _target < _targetKm.length) {
      targetKm = _targetKm[_target];
    } else if (_target == 3) {
      targetKm = _customKm;
    } else if (_jarak >= 0 && _jarak < _jarakKm.length) {
      targetKm = _jarakKm[_jarak];
    } else {
      targetKm = _customKm;
    }
    if (targetKm == null) {
      setState(() => _error = S.errFillAll);
      return;
    }
    final now = DateTime.now();
    final windowDays = _durasiDays[_durasi.clamp(0, _durasiDays.length - 1)];
    setState(() => _busy = true);
    try {
      await ChallengeRepository().createChallenge(
        jenis: aktivitasJenis[_jenisIdx],
        targetNilai: targetKm * 1000,
        targetSatuan: 'jarak_m',
        waktuMulai: now,
        waktuSelesai: now.add(Duration(days: windowDays)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Challenge dibuat.')));
      Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      setState(
        () => _error = e.code == '42501' ? S.coachOnly : S.errSaveFailed,
      );
    } catch (e) {
      if (mounted) setState(() => _error = offlineActionErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _group(
    String title,
    List<String> options,
    int selected,
    ValueChanged<int> onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PacerScheme.of(context).soft,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < options.length; i++)
                GestureDetector(
                  onTap: () => onTap(i),
                  child: GoalChip(label: options[i], selected: selected == i),
                ),
            ],
          ),
        ],
      ),
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
              Text(
                'buat challenge teams',
                style: PacerText.pageTitleOf(context).copyWith(fontSize: 26),
              ),
              const SizedBox(height: 12),
              _group(
                S.challengeSportLabel,
                [for (final j in aktivitasJenis) S.sportName(j)],
                _jenisIdx,
                (i) => setState(() => _jenisIdx = i),
              ),
              _group('JARAK', ['3 km', '5 km', '10 km', S.other], _jarak, (i) {
                if (i == 3) {
                  _tapCustom((_) {
                    _jarak = 3;
                    _target = -1;
                  });
                } else {
                  setState(() {
                    _jarak = i;
                    _target = -1;
                  });
                }
              }),
              _group(
                S.durationLabel,
                [S.todayLabel, S.days3, S.week1],
                _durasi,
                (i) => setState(() => _durasi = i),
              ),
              _group(S.target, ['25 km', '30 km', '45 km', S.custom], _target, (
                i,
              ) {
                if (i == 3) {
                  _tapCustom((_) {
                    _target = 3;
                    _jarak = -1;
                  });
                } else {
                  setState(() {
                    _target = i;
                    _jarak = -1;
                  });
                }
              }),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(
                    color: PacerColors.errorRed,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
              ] else
                const SizedBox(height: 12),
              LimeActionBar(
                S.createChallenge,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Team channel chat (IN DEVELOPMENT — beyond the class manual).
/// [teamId] scopes the channel ([teamName] titles the bar with a beta
/// badge). Null teamId (demo / no team yet) shows an empty state.
/// Live messages via initial fetch + realtime inserts; own messages right,
/// others left with sender names.
class ChatScreen extends StatefulWidget {
  final String? teamId;
  final String? teamName;
  const ChatScreen({super.key, this.teamId, this.teamName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChatRepository? _repo;
  List<LocalChatMessage> _messages = [];
  bool _loading = true;
  bool _demo = true;
  bool _wasSyncing = false;
  String? _uid;
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    SyncEngine.instance.addListener(_onSyncChanged);
    _open();
  }

  @override
  void dispose() {
    SyncEngine.instance.removeListener(_onSyncChanged);
    _repo?.dispose();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSyncChanged() {
    final syncing = SyncEngine.instance.status.isSyncing;
    if (_wasSyncing && !syncing && !_demo && _repo != null && widget.teamId != null) {
      _repo!.fetchRecentLocal(widget.teamId!).then((recent) {
        if (mounted) setState(() => _messages = recent);
      }).catchError((_) {});
    }
    _wasSyncing = syncing;
  }

  Future<void> _open() async {
    final teamId = widget.teamId;
    final demo = await isDemoAccount();
    final uid = await AuthRepository().resolveUserId();
    try {
      if (teamId == null || demo || uid == null) {
        if (mounted) {
          setState(() {
            _demo = true;
            _messages = [
              for (final m in PacerDummyData.chatMessages)
                LocalChatMessage(message: m, syncState: SyncState.synced),
            ];
            _loading = false;
          });
          _jumpToBottom();
        }
        return;
      }
      final repo = ChatRepository();
      final recent = await repo.fetchRecentLocal(teamId);
      if (!mounted) return;
      setState(() {
        _demo = false;
        _repo = repo;
        _uid = uid;
        _messages = recent;
        _loading = false;
      });
      repo.watchTeam(teamId, (msg) {
        if (!mounted) return;
        setState(() {
          if (_messages.any((m) => m.message.id == msg.id)) return;
          _messages = [
            ..._messages,
            LocalChatMessage(message: msg, syncState: SyncState.synced),
          ];
        });
        _jumpToBottom();
      });
      _jumpToBottom();
    } catch (_) {
      if (mounted) {
        setState(() {
          _demo = demo || teamId == null;
          _messages = demo || teamId == null
              ? [
                  for (final m in PacerDummyData.chatMessages)
                    LocalChatMessage(message: m, syncState: SyncState.synced),
                ]
              : const [];
          _loading = false;
        });
        _jumpToBottom();
      }
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _composer.text;
    if (!isSendableBody(text)) return;
    _composer.clear();
    final repo = _repo;
    if (repo == null || widget.teamId == null) {
      final dummyMsg = LocalChatMessage(
        message: ChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          teamId: widget.teamId ?? 'demo-team',
          userId: _uid ?? 'demo-user-me',
          userNama: 'Kamu',
          body: text,
          createdAt: DateTime.now(),
        ),
        syncState: SyncState.synced,
      );
      if (mounted) {
        setState(() {
          _messages = [..._messages, dummyMsg];
        });
        _jumpToBottom();
      }
      return;
    }
    try {
      final sent = await repo.sendLocal(widget.teamId!, text);
      if (!mounted) return;
      setState(() {
        if (_messages.any((m) => m.message.id == sent.message.id)) return;
        _messages = [..._messages, sent];
      });
      _jumpToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.errSaveFailed)));
      }
    }
  }

  String _clock(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.teamName ?? S.teamChat,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: PacerColors.lime,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'BETA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: PacerColors.ink,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: scheme.card,
        foregroundColor: scheme.ink,
        elevation: 1,
      ),
      body: Center(
        // Chat content caps at 720 on wide screens instead of stretching.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              if (!_demo)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: SyncStatusBanner(margin: EdgeInsets.zero),
                ),
              Expanded(child: _body()),
              _composerBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: PacerScheme.of(context).accent),
      );
    }
    if (_messages.isEmpty) {
      return const Center(child: Text('Belum ada pesan. Mulai duluan!'));
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _bubble(_messages[i]),
    );
  }

  Widget _bubble(LocalChatMessage lm) {
    final m = lm.message;
    final mine = _uid != null && m.userId == _uid;
    final scheme = PacerScheme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? PacerColors.chatGreen : scheme.chatBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: mine
                ? const Radius.circular(2)
                : const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            bottomRight: mine
                ? const Radius.circular(16)
                : const Radius.circular(2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine && m.userNama.isNotEmpty)
              Text(
                m.userNama,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            Text(m.body),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _clock(m.createdAt),
                  style: TextStyle(fontSize: 10, color: scheme.subtle),
                ),
                if (mine && lm.syncState != SyncState.synced) ...[
                  const SizedBox(width: 4),
                  Icon(
                    lm.syncState == SyncState.failed
                        ? Icons.error_outline
                        : Icons.schedule,
                    size: 11,
                    color: scheme.subtle,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composerBar() {
    final live = _repo != null;
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, _, _) {
        final online = ConnectivityService.instance.value;
        final hint = !live
            ? 'Pilih tim dulu.'
            : (online ? S.writeMessage : S.chatOfflineComposerHint);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  enabled: live,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(22)),
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: live ? _send : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: live
                        ? PacerColors.chatGreen
                        : PacerScheme.of(context).softBorder,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Figma About Me data card. Reads/updates offline-first profile locally
/// when signed in and syncs automatically when online.
class AboutMeScreen extends StatefulWidget {
  const AboutMeScreen({super.key});

  @override
  State<AboutMeScreen> createState() => _AboutMeScreenState();
}

class _AboutMeScreenState extends State<AboutMeScreen> {
  UserProfile? _profile;
  bool _demo = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (await isDemoAccount()) {
      if (mounted) {
        setState(() {
          _demo = true;
          _profile = UserProfile(
            id: 'demo-user-me',
            nama: 'Pacer Demo',
            lahir: DateTime.utc(2006, 5, 14),
            jenisKelamin: 'Laki-laki',
            tinggiCm: 172,
            beratKg: 64,
            region: 'DKI Jakarta',
          );
        });
      }
      return;
    }
    try {
      final profile = await AuthRepository().getProfile();
      if (mounted) {
        setState(() {
          _demo = false;
          _profile = profile;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _demo = false);
    }
  }

  /// Full-stats editor (own dialog widget so its controllers are disposed
  /// with the dialog, not while it is still animating closed).
  Future<void> _editDetails() async {
    final result = await showDialog<ProfileEditResult>(
      context: context,
      builder: (context) => ProfileEditDialog(initial: _profile),
    );
    if (result == null || !mounted) return;
    if (_demo) {
      setState(() {
        _profile = UserProfile(
          id: _profile?.id ?? 'demo-user-me',
          nama: result.nama,
          lahir: result.lahir,
          jenisKelamin: result.jenisKelamin,
          tinggiCm: result.tinggiCm,
          beratKg: result.beratKg,
          region: result.region,
        );
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.nameSaved)));
      return;
    }
    try {
      await AuthRepository().updateProfile(
        nama: result.nama,
        lahir: result.lahir,
        jenisKelamin: result.jenisKelamin,
        tinggiCm: result.tinggiCm,
        beratKg: result.beratKg,
        region: result.region,
        clear: {
          if (result.lahir == null) 'lahir',
          if (result.jenisKelamin == null) 'jenis_kelamin',
          if (result.tinggiCm == null) 'tinggi_cm',
          if (result.beratKg == null) 'berat_kg',
          if (result.region == null) 'region',
        },
      );
      await _reloadProfile();
      if (!mounted) return;
      final msg = ConnectivityService.instance.value
          ? S.nameSaved
          : S.queuedOfflineSaved;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.errSaveFailed)));
      }
    }
  }

  Future<void> _reloadProfile() async {
    try {
      final profile = await AuthRepository().getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      /* keep stale */
    }
  }

  String _bulan(int m) {
    const idNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    const enNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final names = langNotifier.value == Lang.en ? enNames : idNames;
    return (m >= 1 && m <= 12) ? names[m - 1] : '';
  }

  String _trimNum(double? v) {
    if (v == null) return '–';
    final t = v.truncateToDouble();
    return (v - t).abs() < 1e-9 ? '${t.toInt()}' : '$v';
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final rows = [
      (S.fullName, p?.nama ?? '–'),
      (
        S.birth,
        p?.lahir == null
            ? '–'
            : '${p!.lahir!.day} ${_bulan(p.lahir!.month)} ${p.lahir!.year}',
      ),
      (
        S.gender,
        p?.jenisKelamin == 'Laki-laki'
            ? S.genderMale
            : p?.jenisKelamin == 'Perempuan'
            ? S.genderFemale
            : p?.jenisKelamin ?? '–',
      ),
      (S.height, p?.tinggiCm == null ? '–' : '${_trimNum(p?.tinggiCm)} cm'),
      (S.weight, p?.beratKg == null ? '–' : '${_trimNum(p?.beratKg)} kg'),
      (S.region, p?.region ?? '–'),
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
              Text(S.aboutMe, style: PacerText.pageTitleOf(context)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PacerScheme.of(context).border),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                r.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
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
                  onPressed: _editDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PacerScheme.of(context).editBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    S.editPersonalDetails,
                    style: TextStyle(color: PacerScheme.of(context).actionFg),
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

/// Result of [ProfileEditDialog]: null optional fields mean "cleared".
class ProfileEditResult {
  final String nama;
  final DateTime? lahir;
  final String? jenisKelamin;
  final double? tinggiCm;
  final double? beratKg;
  final String? region;
  const ProfileEditResult({
    required this.nama,
    this.lahir,
    this.jenisKelamin,
    this.tinggiCm,
    this.beratKg,
    this.region,
  });
}

/// Personal-details editor. Validates inline (name required, height/weight
/// within the DB checks, comma decimals accepted) instead of silently
/// dropping bad input; birth date comes from a picker, not free text.
class ProfileEditDialog extends StatefulWidget {
  final UserProfile? initial;
  const ProfileEditDialog({super.key, this.initial});

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  late final TextEditingController _nama;
  late final TextEditingController _tinggi;
  late final TextEditingController _berat;
  DateTime? _lahir;
  String? _gender;
  String? _region;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _nama = TextEditingController(text: p?.nama ?? '');
    _tinggi = TextEditingController(text: _num(p?.tinggiCm));
    _berat = TextEditingController(text: _num(p?.beratKg));
    _lahir = p?.lahir;
    _gender = p?.jenisKelamin;
    _region = indonesianRegions.contains(p?.region) ? p?.region : null;
  }

  @override
  void dispose() {
    _nama.dispose();
    _tinggi.dispose();
    _berat.dispose();
    super.dispose();
  }

  static String _num(double? v) {
    if (v == null) return '';
    return v == v.truncateToDouble() ? '${v.toInt()}' : '$v';
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lahir ?? DateTime(now.year - 17, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _lahir = DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  void _save() {
    final nama = _nama.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = S.errFillAll);
      return;
    }
    final tinggi = parseDecimal(_tinggi.text);
    final berat = parseDecimal(_berat.text);
    if (_tinggi.text.trim().isNotEmpty &&
        (tinggi == null || !validHeightCm(tinggi))) {
      setState(() => _error = S.invalidHeight);
      return;
    }
    if (_berat.text.trim().isNotEmpty &&
        (berat == null || !validWeightKg(berat))) {
      setState(() => _error = S.invalidWeight);
      return;
    }
    Navigator.of(context).pop(
      ProfileEditResult(
        nama: nama,
        lahir: _lahir,
        jenisKelamin: _gender,
        tinggiCm: tinggi,
        beratKg: berat,
        region: _region,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.editPersonalDetails),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nama,
              autofocus: true,
              decoration: InputDecoration(hintText: S.fullName),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _lahir == null ? S.birth : _fmt(_lahir!),
                    style: TextStyle(
                      color: _lahir == null
                          ? PacerScheme.of(context).soft
                          : PacerScheme.of(context).ink,
                    ),
                  ),
                ),
                if (_lahir != null)
                  IconButton(
                    tooltip: S.notSet,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _lahir = null),
                  ),
                TextButton(onPressed: _pickDate, child: Text(S.pickDate)),
              ],
            ),
            DropdownButtonFormField<String?>(
              initialValue: _gender,
              decoration: InputDecoration(hintText: S.gender),
              items: [
                DropdownMenuItem(value: null, child: Text(S.notSet)),
                DropdownMenuItem(
                  value: 'Laki-laki',
                  child: Text(S.genderMale),
                ),
                DropdownMenuItem(
                  value: 'Perempuan',
                  child: Text(S.genderFemale),
                ),
              ],
              onChanged: (v) => _gender = v,
            ),
            TextField(
              controller: _tinggi,
              decoration: InputDecoration(hintText: '${S.height} (cm)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: _berat,
              decoration: InputDecoration(hintText: '${S.weight} (kg)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _region,
              isExpanded: true,
              decoration: InputDecoration(hintText: S.region),
              items: [
                DropdownMenuItem(value: null, child: Text(S.notSet)),
                for (final r in indonesianRegions)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => _region = v,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthErrorText(_error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancelLabel),
        ),
        TextButton(onPressed: _save, child: Text(S.saveLabel)),
      ],
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
        S.leaderboard,
        Icons.leaderboard_outlined,
        (ctx) => LeaderboardScreen(onBack: () => Navigator.of(ctx).pop()),
      ),
      (
        S.teams,
        Icons.groups_outlined,
        (ctx) => TeamsScreen(onBack: () => Navigator.of(ctx).pop()),
      ),
      (
        S.streaks,
        Icons.local_fire_department_outlined,
        (_) => const StreaksScreen(),
      ),
      (S.riwayat, Icons.history_outlined, (_) => const HistoryScreen()),
      (S.profile, Icons.person_outline, (_) => const AccountScreen()),
      (
        S.notifications,
        Icons.notifications_active_outlined,
        (_) => const NotificationMockScreen(),
      ),
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
              Text(S.features.toUpperCase(), style: PacerText.fugazOf(context)),
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
                          border: Border.all(
                            color: PacerScheme.of(context).border,
                          ),
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
      if (await isDemoAccount()) return;
      final value = await AuthRepository().getLanguage();
      if (value == 'en' && langNotifier.value != Lang.en) {
        langNotifier.value = Lang.en;
      } else if (value == 'id' && langNotifier.value != Lang.id) {
        langNotifier.value = Lang.id;
      }
    } catch (_) {
      // Demo mode or offline — local value stands.
    }
  }

  Future<void> _setLang(Lang lang) async {
    langUserLocked = true;
    langNotifier.value = lang;
    await persistLanguagePreference(lang);
    try {
      if (await isDemoAccount()) {
        if (mounted) setState(() {});
        return;
      }
      await AuthRepository().updateLanguage(lang == Lang.en ? 'en' : 'id');
    } catch (_) {
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
      backgroundColor: PacerScheme.of(context).scaffold,
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
              Text(S.language, style: PacerText.pageTitleOf(context)),
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
            color: selected
                ? PacerScheme.of(context).accent
                : PacerScheme.of(context).border,
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
                    style: TextStyle(
                      fontSize: 12,
                      color: PacerScheme.of(context).soft,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_off,
              color: selected
                  ? PacerScheme.of(context).accent
                  : PacerScheme.of(context).soft,
            ),
          ],
        ),
      ),
    );
  }
}

/// Theme settings: system / light / dark. Session-local (no backend
/// column); PacerApp listens to [themeModeNotifier] and rebuilds the whole
/// tree, mirroring the language toggle. Option labels are hardcoded,
/// following this file's language-option precedent (S.* untouched).
class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PacerScheme.of(context).scaffold,
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
              Text(S.theme, style: PacerText.pageTitleOf(context)),
              const SizedBox(height: 16),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeModeNotifier,
                builder: (context, current, _) => Column(
                  children: [
                    _themeOption(
                      context,
                      label: S.themeSystem,
                      sub: S.themeSystemSub,
                      selected: current == ThemeMode.system,
                      onTap: () => setThemeMode(ThemeMode.system),
                    ),
                    const SizedBox(height: 12),
                    _themeOption(
                      context,
                      label: S.themeLight,
                      sub: S.themeLightSub,
                      selected: current == ThemeMode.light,
                      onTap: () => setThemeMode(ThemeMode.light),
                    ),
                    const SizedBox(height: 12),
                    _themeOption(
                      context,
                      label: S.themeDark,
                      sub: S.themeDarkSub,
                      selected: current == ThemeMode.dark,
                      onTap: () => setThemeMode(ThemeMode.dark),
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

  Widget _themeOption(
    BuildContext context, {
    required String label,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = PacerScheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.accent : scheme.border,
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
                  Text(sub, style: TextStyle(fontSize: 12, color: scheme.soft)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_off,
              color: selected ? scheme.accent : scheme.soft,
            ),
          ],
        ),
      ),
    );
  }
}

/// Push notification center & activity reminders
/// Directly addresses Context Diagram ("Push Notification Eksternal: Challenge, Streak, Remind Aktivitas")
class NotificationMockScreen extends StatefulWidget {
  const NotificationMockScreen({super.key});

  @override
  State<NotificationMockScreen> createState() => _NotificationMockScreenState();
}

class _NotificationMockScreenState extends State<NotificationMockScreen> {
  final List<
    ({String title, String body, String time, IconData icon, Color color})
  >
  _notifs = [
    (
      title: S.reminderTitle,
      body: S.reminderBody,
      time: '17:00',
      icon: Icons.local_fire_department,
      color: PacerColors.lime,
    ),
    (
      title: 'Challenge Update',
      body: 'Tim Pacer mendekati target mingguan 25 km! Tetap semangat 🏃',
      time: '14:30',
      icon: Icons.emoji_events,
      color: Colors.amber,
    ),
    (
      title: 'Streak Saved',
      body: 'Streak kamu tetap menyala berkat lari kemarin.',
      time: 'Kemarin',
      icon: Icons.check_circle_outline,
      color: Colors.lightGreen,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Scaffold(
      backgroundColor: scheme.scaffold,
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
              Text(S.notifications, style: PacerText.pageTitleOf(context)),
              const SizedBox(height: 16),
              for (final n in _notifs)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.border),
                    boxShadow: [scheme.shadowBox],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: n.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(n.icon, size: 22, color: n.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: scheme.chipFg,
                                    ),
                                  ),
                                ),
                                Text(
                                  n.time,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.body,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.bodyGray,
                                height: 1.4,
                              ),
                            ),
                          ],
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
