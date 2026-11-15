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
import 'package:pacer/src/notifications/notification_model.dart';
import 'package:pacer/src/notifications/notification_repository.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:pacer/src/teams/team_model.dart';
import 'package:pacer/src/teams/team_repository.dart';
import 'package:pacer/src/tracking/recorder.dart';
import 'package:pacer/src/tracking/route_map.dart';
import 'package:pacer/src/update/github_update_service.dart';
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
  final String? initialSport;
  final void Function(String jenis, String goal, List<String>? challengeIds)?
  onStartWithChallenges;
  final void Function(String jenis, String goal)? onStartWithConfig;
  final VoidCallback? onStart;
  const RunSetupScreen({
    super.key,
    this.initialSport,
    this.onStartWithChallenges,
    this.onStartWithConfig,
    this.onStart,
  });

  @override
  State<RunSetupScreen> createState() => _RunSetupScreenState();
}

class _RunSetupScreenState extends State<RunSetupScreen> {
  int _selectedSport = 0;
  int _goal = 0;
  List<Challenge> _allChallenges = const [];
  List<PartisipasiChallenge> _participations = const [];
  final Set<String> _optedOutIds = {};

  @override
  void initState() {
    super.initState();
    final sportKey = widget.initialSport;
    if (sportKey != null) {
      final idx = _sports.indexWhere((s) => s.key == sportKey);
      if (idx >= 0) _selectedSport = idx;
    }
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    try {
      final List<Challenge> chals;
      final List<PartisipasiChallenge> parts;
      if (await isDemoAccount()) {
        chals = PacerDummyData.demoChallenges;
        parts = PacerDummyData.getDemoParticipations();
      } else {
        final repo = ChallengeRepository();
        chals = await repo.listChallenges();
        parts = await repo.myParticipations();
      }
      if (!mounted) return;
      setState(() {
        _allChallenges = chals;
        _participations = parts;
      });
    } catch (_) {}
  }

  List<({Challenge challenge, PartisipasiChallenge participation})>
  _eligibleForSelectedSport() {
    final sport = _sports[_selectedSport].key;
    final now = DateTime.now().toUtc();
    final chalById = {for (final c in _allChallenges) c.id: c};
    final out =
        <({Challenge challenge, PartisipasiChallenge participation})>[];
    for (final p in _participations) {
      if (p.berhasil || !p.isActive) continue;
      final c = chalById[p.challengeId];
      if (c == null || c.jenis != sport || !isChallengeActive(c, now)) {
        continue;
      }
      out.add((challenge: c, participation: p));
    }
    out.sort((a, b) {
      final aTeam = a.challenge.isTeamChallenge ? 0 : 1;
      final bTeam = b.challenge.isTeamChallenge ? 0 : 1;
      return aTeam.compareTo(bTeam);
    });
    return out;
  }

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
    final eligible = _eligibleForSelectedSport();
    final selectedChallengeIds = [
      for (final item in eligible)
        if (!_optedOutIds.contains(item.challenge.id)) item.challenge.id,
    ];
    if (widget.onStartWithChallenges != null) {
      widget.onStartWithChallenges!(
        chosenSport,
        chosenGoal,
        selectedChallengeIds,
      );
    } else if (widget.onStartWithConfig != null) {
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
              if (_eligibleForSelectedSport().isNotEmpty) ...[
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final eligible = _eligibleForSelectedSport();
                    final selectedIds = {
                      for (final e in eligible)
                        if (!_optedOutIds.contains(e.challenge.id))
                          e.challenge.id,
                    };
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.activeChallengesForSport,
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: scheme.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            S.activeChallengesAutoNote,
                            style: TextStyle(fontSize: 12, color: scheme.muted),
                          ),
                          const SizedBox(height: 10),
                          _ChallengeToggleList(
                            items: eligible,
                            selectedIds: selectedIds,
                            onToggle: (id, on) {
                              setState(() {
                                if (on) {
                                  _optedOutIds.remove(id);
                                } else {
                                  _optedOutIds.add(id);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
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
  final List<String>? initialChallengeIds;
  const RunTrackerScreen({
    super.key,
    this.onBack,
    this.sportType = 'lari',
    this.goal,
    this.initialDraft,
    this.initialChallengeIds,
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
      List<({Challenge challenge, PartisipasiChallenge participation})>
      eligible = const [];
      try {
        eligible = await ChallengeRepository().eligibleActiveChallengesForSport(
          widget.sportType,
        );
      } catch (_) {}

      List<String>? challengeIds;
      if (eligible.isNotEmpty) {
        if (!mounted) return;
        final initialSelected = widget.initialChallengeIds != null
            ? {
                for (final e in eligible)
                  if (widget.initialChallengeIds!.contains(e.challenge.id))
                    e.challenge.id,
              }
            : {for (final e in eligible) e.challenge.id};
        final picked = await _showFinishChallengeOptInSheet(
          context,
          eligible: eligible,
          initialSelected: initialSelected,
        );
        if (picked == null) return;
        challengeIds = picked;
      }

      final summary = await _recorder.finish(challengeIds: challengeIds);
      if (summary != null && await isDemoAccount()) {
        final now = DateTime.now().toUtc();
        PacerDummyData.recordDemoActivityProgress(
          Activity(
            id: summary.aktivitasId,
            userId: 'demo-user-me',
            jenis: summary.jenis,
            mulaiAt: now.subtract(Duration(seconds: summary.durasiS)),
            selesaiAt: now,
            durasiS: summary.durasiS,
            jarakM: summary.jarakM,
            challengeIds: challengeIds,
          ),
        );
        NotificationRepository.syncDemoUnread();
      }
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
  Future<List<({Challenge challenge, PartisipasiChallenge participation})>>?
  _appliedChallengesFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = _loadRoute();
    _profileFuture = _loadProfile();
    _appliedChallengesFuture = _loadAppliedChallenges();
  }

  @override
  void didUpdateWidget(covariant RunFinishScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.aktivitasId != oldWidget.aktivitasId ||
        widget.summary?.points != oldWidget.summary?.points) {
      _routeFuture = _loadRoute();
    }
    if (widget.summary?.challengeIds != oldWidget.summary?.challengeIds) {
      _appliedChallengesFuture = _loadAppliedChallenges();
    }
  }

  Future<List<({Challenge challenge, PartisipasiChallenge participation})>>
  _loadAppliedChallenges() async {
    final ids = widget.summary?.challengeIds;
    if (ids == null || ids.isEmpty) return const [];
    try {
      final List<Challenge> all;
      final List<PartisipasiChallenge> parts;
      if (await isDemoAccount()) {
        all = PacerDummyData.demoChallenges;
        parts = PacerDummyData.getDemoParticipations();
      } else {
        final repo = ChallengeRepository();
        all = await repo.listChallenges();
        parts = await repo.myParticipations();
      }
      final chalMap = {for (final c in all) c.id: c};
      final partMap = {for (final p in parts) p.challengeId: p};
      return [
        for (final id in ids)
          if (chalMap[id] != null && partMap[id] != null)
            (challenge: chalMap[id]!, participation: partMap[id]!),
      ];
    } catch (_) {
      return const [];
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
                        FutureBuilder<
                          List<
                            ({
                              Challenge challenge,
                              PartisipasiChallenge participation,
                            })
                          >
                        >(
                          future: _appliedChallengesFuture,
                          builder: (context, cSnap) {
                            final applied = cSnap.data ?? const [];
                            if (applied.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: scheme.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: scheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    S.challengeProgressUpdated,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: scheme.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _ChallengeToggleList(items: applied),
                                ],
                              ),
                            );
                          },
                        ),
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
typedef _TeamsViewData = ({List<Team> all, Set<String> myIds, bool isDemo});

class TeamsScreen extends StatefulWidget {
  /// Returns to the Home tab (tabs have no pushed route to pop).
  final VoidCallback? onBack;
  const TeamsScreen({super.key, this.onBack});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  Future<_TeamsViewData>? _future;
  String _query = '';
  String _filter = 'all'; // 'all' | 'joined' | 'public'

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TeamsViewData> _load({bool forceRefresh = false}) async {
    if (await isDemoAccount()) {
      return (
        all: PacerDummyData.demoTeams,
        myIds: PacerDummyData.demoMyTeams.map((t) => t.id).toSet(),
        isDemo: true,
      );
    }
    try {
      final repo = TeamRepository();
      final results = await Future.wait([
        repo.listTeams(forceRefresh: forceRefresh),
        repo.myTeams(forceRefresh: forceRefresh),
      ]);
      final listed = results[0];
      final mine = results[1];
      final byId = <String, Team>{for (final t in listed) t.id: t};
      for (final m in mine) {
        byId[m.id] = m;
      }
      return (
        all: byId.values.toList(),
        myIds: mine.map((t) => t.id).toSet(),
        isDemo: false,
      );
    } catch (_) {
      return (all: const <Team>[], myIds: const <String>{}, isDemo: false);
    }
  }

  void _reload({bool forceRefresh = true}) {
    setState(() => _future = _load(forceRefresh: forceRefresh));
  }

  Future<void> _openTeam(Team team) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TeamDashboardScreen(
          teamId: team.id,
          initialTeam: team,
          teamName: team.nama,
        ),
      ),
    );
    if (changed == true && mounted) {
      _reload(forceRefresh: true);
    }
  }

  /// Private teams are not listed publicly: members join with an invite code.
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
        final joined = PacerDummyData.joinDemoByCode(code);
        if (!mounted) return;
        if (joined == null) {
          messenger.showSnackBar(
            SnackBar(content: Text(S.invalidTeamCode)),
          );
          return;
        }
        _reload(forceRefresh: true);
        messenger.showSnackBar(SnackBar(content: Text(S.join)));
        return;
      }
      await TeamRepository().joinByCode(code);
      if (!mounted) return;
      _reload(forceRefresh: true);
      messenger.showSnackBar(SnackBar(content: Text(S.join)));
    } on PostgrestException {
      messenger.showSnackBar(
        SnackBar(content: Text(S.invalidTeamCode)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(offlineActionErrorMessage(e))),
      );
    }
  }

  Future<void> _openTeamChat() async {
    try {
      final mine = await isDemoAccount()
          ? PacerDummyData.demoMyTeams
          : await TeamRepository().myTeams();
      if (!mounted) return;
      if (mine.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.emptyTeams)),
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
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
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

  Widget _teamCardTile(
    Team team, {
    required bool isJoined,
    double? width,
  }) {
    return GestureDetector(
      onTap: () => _openTeam(team),
      child: TeamCard(
        name: team.nama,
        width: width,
        memberCount: team.memberCount,
        isJoined: isJoined,
        isPrivate: team.isPrivate,
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, int count) {
    final scheme = PacerScheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: PacerText.statValueOf(context).copyWith(fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.border),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final scheme = PacerScheme.of(context);
    final selected = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? scheme.brandAccent : scheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.brandAccent : scheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.onBrandAccent : scheme.ink,
          ),
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
          onRefresh: () async {
            _reload(forceRefresh: true);
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
              const SizedBox(height: 12),
              // Team sections flow cleanly: Joined strip + Public grid on All,
              // or single grid when filtered. Preserves 1 GridView on screen.
              FutureBuilder<_TeamsViewData>(
                future: _future,
                builder: (context, snap) {
                  final all = snap.data?.all ?? const <Team>[];
                  final myIds = snap.data?.myIds ?? const <String>{};
                  final q = _query.trim().toLowerCase();
                  bool matches(Team t) =>
                      q.isEmpty || t.nama.toLowerCase().contains(q);

                  final joinedTeams =
                      all.where((t) => myIds.contains(t.id) && matches(t)).toList();
                  final publicTeams =
                      all.where((t) => !t.isPrivate && matches(t)).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _filterPill(
                            context,
                            value: 'all',
                            label: S.filterAll,
                          ),
                          _filterPill(
                            context,
                            value: 'joined',
                            label: '${S.filterJoined} (${joinedTeams.length})',
                          ),
                          _filterPill(
                            context,
                            value: 'public',
                            label: '${S.filterPublic} (${publicTeams.length})',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_filter == 'all') ...[
                        _sectionHeader(
                          context,
                          S.joinedTeams,
                          joinedTeams.length,
                        ),
                        if (joinedTeams.isEmpty)
                          PacerEmptyState(
                            q.isEmpty ? S.noJoinedTeamsHint : S.noPublicTeamsHint,
                            icon: Icons.groups_outlined,
                            compact: true,
                          )
                        else
                          SizedBox(
                            height: 140,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: joinedTeams.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, i) => _teamCardTile(
                                joinedTeams[i],
                                isJoined: true,
                                width: 260,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        _sectionHeader(
                          context,
                          S.openPublicTeams,
                          publicTeams.length,
                        ),
                        _teamGrid([
                          for (final t in publicTeams)
                            _teamCardTile(t, isJoined: myIds.contains(t.id)),
                        ]),
                        if (publicTeams.isEmpty)
                          PacerEmptyState(
                            all.isEmpty || q.isEmpty
                                ? 'Belum ada tim.'
                                : S.noPublicTeamsHint,
                            icon: all.isEmpty || q.isEmpty
                                ? Icons.groups_outlined
                                : Icons.search_off_outlined,
                          ),
                      ] else if (_filter == 'joined') ...[
                        _sectionHeader(
                          context,
                          S.joinedTeams,
                          joinedTeams.length,
                        ),
                        _teamGrid([
                          for (final t in joinedTeams)
                            _teamCardTile(t, isJoined: true),
                        ]),
                        if (joinedTeams.isEmpty)
                          PacerEmptyState(
                            q.isEmpty ? S.noJoinedTeamsHint : S.noPublicTeamsHint,
                            icon: q.isEmpty
                                ? Icons.groups_outlined
                                : Icons.search_off_outlined,
                          ),
                      ] else ...[
                        _sectionHeader(
                          context,
                          S.openPublicTeams,
                          publicTeams.length,
                        ),
                        _teamGrid([
                          for (final t in publicTeams)
                            _teamCardTile(t, isJoined: myIds.contains(t.id)),
                        ]),
                        if (publicTeams.isEmpty)
                          PacerEmptyState(
                            q.isEmpty ? 'Belum ada tim.' : S.noPublicTeamsHint,
                            icon: q.isEmpty
                                ? Icons.groups_outlined
                                : Icons.search_off_outlined,
                          ),
                      ],
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
                onTap: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const PersyaratanScreen(),
                    ),
                  );
                  if (created == true && mounted) {
                    _reload(forceRefresh: true);
                  }
                },
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
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                      onPressed: _openTeamChat,
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

/// Full Teams Dashboard: team overview stats, target progress, invite code
/// (strictly hidden for non-members/non-creators on private teams), actions
/// (join/leave, chat, leaderboard, coach controls), and searchable members roster.
class TeamDashboardScreen extends StatefulWidget {
  final String teamId;
  final Team? initialTeam;
  final String? teamName;

  const TeamDashboardScreen({
    super.key,
    required this.teamId,
    this.initialTeam,
    this.teamName,
  });

  @override
  State<TeamDashboardScreen> createState() => _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends State<TeamDashboardScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  bool _isDemo = false;
  bool _isCoach = false;
  bool _isKetua = false;
  bool? _joined;
  int? _memberCount;
  Team? _team;
  TeamDashboardStats? _stats;
  List<TeamRosterMember>? _roster;
  List<Challenge> _teamChallenges = const [];
  Map<String, PartisipasiChallenge> _myParticipations = const {};
  String? _uid;
  bool _canViewCode = false;
  bool _canManageCode = false;
  String? _inviteCode;
  bool _revealCode = false;
  String _memberQuery = '';
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _team = widget.initialTeam;
    _refresh();
  }

  @override
  void didUpdateWidget(covariant TeamDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId) {
      _loading = true;
      _changed = false;
      _revealCode = false;
      _memberQuery = '';
      _code.clear();
      _team = widget.initialTeam;
      _stats = null;
      _roster = null;
      _joined = null;
      _inviteCode = null;
      _canViewCode = false;
      _canManageCode = false;
      _refresh();
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool forceRefresh = false}) async {
    try {
      final demo = await isDemoAccount();
      if (demo) {
        final team = PacerDummyData.demoTeams.cast<Team?>().firstWhere(
          (t) => t?.id == widget.teamId,
          orElse: () => widget.initialTeam,
        );
        final stats = PacerDummyData.getTeamDashboardStats(widget.teamId);
        final roster = PacerDummyData.getTeamRoster(widget.teamId);
        final code = PacerDummyData.getDemoInviteCode(widget.teamId);
        final isKetua =
            team?.dibuatOleh == 'demo-user-me' ||
            roster.any(
              (m) => m.userId == 'demo-user-me' && m.peran == 'ketua',
            );
        final teamChals = PacerDummyData.demoChallenges
            .where((c) => c.teamId == widget.teamId)
            .toList();
        final parts = {
          for (final p in PacerDummyData.getDemoParticipations())
            p.challengeId: p,
        };
        if (!mounted) return;
        setState(() {
          _loading = false;
          _isDemo = true;
          _uid = 'demo-user-me';
          _isCoach = false;
          _isKetua = isKetua;
          _team = team;
          _stats = stats;
          _roster = roster;
          _teamChallenges = teamChals;
          _myParticipations = parts;
          _joined = stats.isMember;
          _memberCount = team?.memberCount ?? stats.memberCount;
          _canViewCode = stats.canViewCode && code != null;
          _canManageCode = stats.canManageCode && code != null;
          _inviteCode = _canViewCode ? code : null;
        });
        return;
      }

      final auth = AuthRepository();
      final repo = TeamRepository();
      final uid = await auth.resolveUserId();
      final team =
          await repo.getTeam(widget.teamId, forceRefresh: forceRefresh) ??
          _team;
      String? peran;
      try {
        peran = (await auth.getProfile(forceRefresh: forceRefresh))?.peran;
      } catch (_) {
        /* keeps prior null */
      }

      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _isDemo = false;
          _uid = null;
          _isCoach = false;
          _team = team;
          _joined = false;
          _stats = null;
          _roster = null;
          _memberCount = team?.memberCount;
          _canViewCode = false;
          _canManageCode = false;
          _inviteCode = null;
        });
        return;
      }

      List<TeamRosterMember> roster = const [];
      TeamDashboardStats? stats;
      String? code;
      List<Challenge> teamChals = const [];
      Map<String, PartisipasiChallenge> myParts = const {};

      await Future.wait([
        () async {
          try {
            roster = await repo.teamRoster(
              widget.teamId,
              forceRefresh: forceRefresh,
            );
          } catch (_) {}
        }(),
        () async {
          try {
            stats = await repo.getTeamDashboardStats(widget.teamId);
          } catch (_) {}
        }(),
        () async {
          try {
            code = await repo.getInviteCode(widget.teamId);
          } catch (_) {
            code = null;
          }
        }(),
        () async {
          try {
            final chRepo = ChallengeRepository();
            final results = await Future.wait([
              chRepo.listTeamChallenges(
                widget.teamId,
                forceRefresh: forceRefresh,
              ),
              chRepo.myParticipations(forceRefresh: forceRefresh),
            ]);
            teamChals = results[0] as List<Challenge>;
            myParts = {
              for (final p in results[1] as List<PartisipasiChallenge>)
                p.challengeId: p,
            };
          } catch (_) {}
        }(),
      ]);

      final joined = stats?.isMember ?? roster.any((m) => m.userId == uid);
      final isPrivate = team?.isPrivate ?? true;
      final inTeam = joined || team?.dibuatOleh == uid;
      final isKetua =
          team?.dibuatOleh == uid ||
          roster.any((m) => m.userId == uid && m.peran == 'ketua');
      final isCoach = peran == 'admin' || (peran == 'coach' && inTeam);
      // Strict client-side defense-in-depth matching SQL: private team codes
      // are shown ONLY when the signed-in user is creator or in the team.
      final canViewCode = code != null &&
          (isPrivate
              ? inTeam && (stats?.canViewCode ?? true)
              : (stats?.canViewCode ?? (inTeam || isCoach)));
      final canManageCode = code != null &&
          canViewCode &&
          (stats?.canManageCode ??
              (isPrivate ? isKetua : isCoach));

      if (!mounted) return;
      setState(() {
        _loading = false;
        _isDemo = false;
        _uid = uid;
        _isCoach = isCoach;
        _isKetua = isKetua;
        _team = team;
        _stats = stats;
        _roster = roster;
        _teamChallenges = teamChals;
        _myParticipations = myParts;
        _joined = joined;
        _memberCount = stats?.memberCount ?? team?.memberCount ?? roster.length;
        _canViewCode = canViewCode;
        _canManageCode = canManageCode;
        _inviteCode = canViewCode ? code : null;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleJoin() async {
    final displayName = _team?.nama ?? widget.teamName ?? '';
    if (_joined == true) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.leaveTeamConfirmTitle),
          content: Text(S.leaveTeamConfirmBody(displayName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(S.cancelLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(S.leaveTeamAction),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      setState(() => _busy = true);
      try {
        if (_isDemo) {
          PacerDummyData.leaveDemoTeam(widget.teamId);
        } else {
          await TeamRepository().leaveTeam(widget.teamId);
        }
        _changed = true;
        await _refresh(forceRefresh: true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.enterTeamCodeFirst)),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (_isDemo) {
        final ok = PacerDummyData.joinDemoTeam(widget.teamId, code: code);
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.invalidTeamCode)),
          );
          return;
        }
        _code.clear();
        _changed = true;
        await _refresh(forceRefresh: true);
        return;
      }
      await TeamRepository().joinTeam(widget.teamId, code);
      if (!mounted) return;
      _code.clear();
      _changed = true;
      await _refresh(forceRefresh: true);
    } on PostgrestException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.invalidTeamCode)),
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
      if (_isDemo) {
        PacerDummyData.removeDemoMember(widget.teamId, userId);
      } else {
        await TeamRepository().removeMember(widget.teamId, userId);
      }
      _changed = true;
      await _refresh(forceRefresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineActionErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _setMemberRole(TeamRosterMember m, String peran) async {
    setState(() => _busy = true);
    try {
      if (_isDemo) {
        PacerDummyData.setDemoMemberRole(widget.teamId, m.userId, peran);
        NotificationRepository.syncDemoUnread();
      } else {
        await TeamRepository().setMemberRole(
          teamId: widget.teamId,
          userId: m.userId,
          peran: peran,
        );
      }
      _changed = true;
      await _refresh(forceRefresh: true);
      if (mounted) {
        final roleLabel = peran == 'ketua' ? S.roleKetua : S.roleAnggota;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.roleUpdatedMsg(m.nama, roleLabel))),
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

  Future<void> _activateTeamChallenge(String challengeId) async {
    setState(() => _busy = true);
    try {
      await ChallengeRepository().activateChallenge(challengeId);
      _changed = true;
      await _refresh(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.challengeActivatedMsg)),
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

  Future<void> _regenerateCode() async {
    setState(() => _busy = true);
    try {
      final code = _isDemo
          ? PacerDummyData.regenerateDemoInviteCode(widget.teamId)
          : await TeamRepository().regenerateInviteCode(widget.teamId);
      if (!mounted) return;
      _changed = true;
      setState(() {
        _inviteCode = code;
        _revealCode = true;
      });
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

  Future<void> _copyInviteCode() async {
    final code = _inviteCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.codeCopied)),
    );
  }

  Future<void> _editTeam() async {
    final team = _team;
    if (team == null) return;
    final name = TextEditingController(text: team.nama);
    final target = TextEditingController(
      text: team.targetNilai == null ? '' : '${team.targetNilai!.toInt()}',
    );
    var isPrivate = team.isPrivate;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                decoration: InputDecoration(labelText: S.teamTargetMeters),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(S.teamPrivacyLabel),
                value: isPrivate,
                onChanged: (v) => setDialogState(() => isPrivate = v),
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
        isPrivate: isPrivate,
      );
      _changed = true;
      await _refresh(forceRefresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineActionErrorMessage(e))),
        );
      }
    }
  }

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
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineActionErrorMessage(e))),
        );
      }
    }
  }

  Widget _buildHeroCard(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final team = _team;
    final title = team?.nama ?? widget.teamName ?? S.teamDashboard;
    final isPrivate = team?.isPrivate ?? false;
    final targetKm = team?.targetNilai == null ? null : team!.targetNilai! / 1000.0;
    final totalKm = _stats?.totalAllKm ?? 0.0;
    final progress = (targetKm != null && targetKm > 0)
        ? (totalKm / targetKm).clamp(0.0, 1.0)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: scheme.heroCardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [scheme.shadowBox],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPrivate ? Icons.lock_outline : Icons.public,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPrivate ? S.privateBadge : S.publicBadge,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (_joined == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.brandAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    S.joinedBadge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scheme.onBrandAccent,
                    ),
                  ),
                ),
              if (_memberCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.group_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        S.membersCount(_memberCount!),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: PacerText.pageTitle.copyWith(color: Colors.white, fontSize: 28),
          ),
          if (targetKm != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.targetGoal,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${totalKm.toStringAsFixed(1)} / ${targetKm.toStringAsFixed(targetKm == targetKm.truncateToDouble() ? 0 : 1)} km',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    scheme.brandAccent,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statTile(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final scheme = PacerScheme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: PacerText.statValueOf(context).copyWith(fontSize: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.muted),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final count = _stats?.memberCount ?? _memberCount ?? _roster?.length ?? 0;
    final active = _stats == null ? '–' : '${_stats!.activeMembersWeek}';
    final weekKm =
        _stats == null ? '–' : '${_stats!.totalWeekKm.toStringAsFixed(1)} km';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.teamOverview,
            style: PacerText.cardTitleOf(context).copyWith(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statTile(context, value: '$count', label: S.membersSection),
              _statTile(context, value: active, label: S.activeThisWeek),
              _statTile(context, value: weekKm, label: S.weeklyDistance),
            ],
          ),
          if (_stats != null) ...[
            const SizedBox(height: 10),
            Divider(color: scheme.hairline, height: 1),
            const SizedBox(height: 10),
            Text(
              '${S.weeklySessions}: ${_stats!.totalWeekSessions}  ·  ${S.totalDistanceAll}: ${_stats!.totalAllKm.toStringAsFixed(1)} km',
              style: TextStyle(fontSize: 12, color: scheme.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInviteCodeCard(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final isPrivate = _team?.isPrivate ?? false;
    final code = _inviteCode!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_key_outlined, size: 18, color: scheme.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  S.inviteCodeSection,
                  style: PacerText.cardTitleOf(context).copyWith(fontSize: 14),
                ),
              ),
              IconButton(
                tooltip: _revealCode ? S.hideCode : S.showCode,
                onPressed: () => setState(() => _revealCode = !_revealCode),
                icon: Icon(
                  _revealCode
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: scheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  _revealCode ? code : '••••••••',
                  style: PacerText.mono.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: scheme.ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _copyInviteCode,
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: Text(S.copyCode),
              ),
              if (_canManageCode)
                TextButton(
                  onPressed: _busy ? null : _regenerateCode,
                  child: Text(S.regenerateCode),
                ),
            ],
          ),
          if (isPrivate)
            Text(
              S.inviteCodeHint,
              style: TextStyle(fontSize: 11, color: scheme.muted),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final teamName = _team?.nama ?? widget.teamName ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_joined != true) ...[
          if (_joined == false && (_team?.isPrivate ?? true)) ...[
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: S.teamCodeLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          LimeActionBar(
            S.join,
            onPressed: (_busy || _joined == null) ? null : _toggleJoin,
          ),
        ] else ...[
          LimeActionBar(
            S.teamChat,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  teamId: widget.teamId,
                  teamName: teamName,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LeaderboardScreen(
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: Text(S.teamsLeaderboard),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _toggleJoin,
                  icon: Icon(Icons.logout, size: 18, color: scheme.error),
                  label: Text(
                    S.leaveTeamAction,
                    style: TextStyle(color: scheme.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_isCoach) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CoachBoardScreen()),
                  ),
                  child: Text(S.coachBoardTitle),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _editTeam,
                  child: Text(S.editLabel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _deleteTeam,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                  child: Text(S.deleteLabel),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRosterSection(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final isPublic = _team != null && !_team!.isPrivate;
    final canViewRoster = (_joined == true || isPublic || _isCoach) && _roster != null;
    if (!canViewRoster) {
      return const SizedBox.shrink();
    }

    final roster = _roster!;
    final q = _memberQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? roster
        : roster
            .where(
              (m) =>
                  m.nama.toLowerCase().contains(q) ||
                  m.peran.toLowerCase().contains(q),
            )
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.membersSection,
                style: PacerText.statValueOf(context).copyWith(fontSize: 18),
              ),
            ),
            Text(
              S.membersCount(roster.length),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.muted,
              ),
            ),
          ],
        ),
        if (roster.length > 3 || q.isNotEmpty) ...[
          const SizedBox(height: 10),
          SearchField(
            hint: S.searchMembersHint,
            onChanged: (v) => setState(() => _memberQuery = v),
          ),
        ],
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          PacerEmptyState(
            roster.isEmpty ? S.noMembers : S.noMembersMatch,
            icon: Icons.person_search_outlined,
            compact: true,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: scheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: scheme.hairline),
                  _memberTile(context, filtered[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _memberTile(BuildContext context, TeamRosterMember m) {
    final scheme = PacerScheme.of(context);
    final isMe = m.userId == _uid;
    final isCaptain = m.peran == 'ketua';
    final joinedStr = m.joinedAt == null ? '' : fmtDate(m.joinedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          InitialAvatar(initialsOf(m.nama), size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      isMe ? '${m.nama} (${S.you})' : m.nama,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: scheme.ink,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isCaptain
                            ? scheme.brandAccent.withValues(alpha: 0.25)
                            : scheme.searchBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isCaptain ? S.captainRole : S.memberRole,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: scheme.ink,
                        ),
                      ),
                    ),
                    if (m.appPeran == 'coach' || m.appPeran == 'admin')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.brandAccent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          m.appPeran.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: scheme.onBrandAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                if (joinedStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    S.joinedOn(joinedStr),
                    style: TextStyle(fontSize: 12, color: scheme.muted),
                  ),
                ],
              ],
            ),
          ),
          if (_isCoach && !isMe)
            PopupMenuButton<String>(
              enabled: !_busy,
              icon: Icon(Icons.more_vert, color: scheme.muted),
              onSelected: (value) {
                if (value == 'promote') {
                  _setMemberRole(m, 'ketua');
                } else if (value == 'demote') {
                  _setMemberRole(m, 'anggota');
                } else if (value == 'kick') {
                  _kick(m.userId, m.nama);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: isCaptain ? 'demote' : 'promote',
                  child: Text(
                    isCaptain ? S.demoteToAnggota : S.promoteToKetua,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'kick',
                  child: Text(
                    S.kickMemberConfirm,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTeamChallengesSection(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final canCreate = _isCoach || _isKetua;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.teamChallengesHeading,
                style: PacerText.cardTitleOf(context).copyWith(fontSize: 16),
              ),
            ),
            if (canCreate)
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final created = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => CreateChallengeScreen(
                              initialTeamId: widget.teamId,
                            ),
                          ),
                        );
                        if (created == true && mounted) {
                          _changed = true;
                          await _refresh(forceRefresh: true);
                        }
                      },
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text(S.createTeamChallenge),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_teamChallenges.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.border),
            ),
            child: Text(
              S.noTeamChallengesYet,
              style: TextStyle(fontSize: 13, color: scheme.muted),
            ),
          )
        else ...[
          for (final c in _teamChallenges)
            Builder(
              builder: (context) {
                final part = _myParticipations[c.id];
                final active = isChallengeActive(c, DateTime.now());
                final pct = part == null
                    ? 0.0
                    : progressPercent(part.progressNilai, c.targetNilai);
                final String badgeText;
                final Color badgeBg;
                final Color badgeFg;
                if (part?.berhasil == true) {
                  badgeText = S.challengeCompletedLabel;
                  badgeBg = scheme.success.withValues(alpha: 0.16);
                  badgeFg = scheme.success;
                } else if (part != null && part.isActive) {
                  badgeText = S.activeSlotBadge;
                  badgeBg = scheme.brandAccent.withValues(alpha: 0.28);
                  badgeFg = scheme.ink;
                } else if (part != null) {
                  badgeText = S.waitingSlotBadge;
                  badgeBg = scheme.searchBg;
                  badgeFg = scheme.soft;
                } else if (!active) {
                  badgeText = S.challengeEnded;
                  badgeBg = scheme.error.withValues(alpha: 0.14);
                  badgeFg = scheme.error;
                } else {
                  badgeText = S.challengeActive;
                  badgeBg = PacerColors.primary.withValues(alpha: 0.18);
                  badgeFg = scheme.ink;
                }
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final changed = await ChallengeDetailSheet.show(
                      context,
                      challengeId: c.id,
                      challenge: c,
                      participation: part,
                    );
                    if (changed == true && mounted) {
                      _changed = true;
                      await _refresh(forceRefresh: true);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: part?.isActive == true
                            ? scheme.brandAccent
                            : scheme.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _challengeDisplayTitle(c),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: scheme.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ChallengeBadge(badgeText, bg: badgeBg, fg: badgeFg),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${S.sportName(c.jenis)} • '
                          '${S.challengeTargetSummary(c.targetNilai, c.targetSatuan)} • '
                          '${_challengeWindowText(c)}',
                          style: TextStyle(fontSize: 12, color: scheme.soft),
                        ),
                        if (part != null) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (pct / 100).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: scheme.softBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                part.berhasil
                                    ? scheme.success
                                    : PacerColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${S.challengeTargetSummary(part.progressNilai, c.targetSatuan)} / '
                                  '${S.challengeTargetSummary(c.targetNilai, c.targetSatuan)} • '
                                  '${pct.toInt()}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.soft,
                                  ),
                                ),
                              ),
                              if (!part.berhasil && !part.isActive)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _activateTeamChallenge(c.id),
                                  child: Text(S.chooseActiveChallenge),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: scheme.scaffold,
        body: SafeArea(
          child: ResponsiveScroll(
            onRefresh: () => _refresh(forceRefresh: true),
            padding: const EdgeInsets.only(top: 16, bottom: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  onBack: () => Navigator.of(context).pop(_changed),
                ),
                const SizedBox(height: 16),
                if (_loading && _team == null)
                  const PacerLoading()
                else ...[
                  _buildHeroCard(context),
                  const SizedBox(height: 16),
                  _buildOverviewCard(context),
                  const SizedBox(height: 16),
                  _buildActionsSection(context),
                  if (_canViewCode && _inviteCode != null) ...[
                    const SizedBox(height: 16),
                    _buildInviteCodeCard(context),
                  ],
                  const SizedBox(height: 20),
                  _buildTeamChallengesSection(context),
                  const SizedBox(height: 20),
                  _buildRosterSection(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Backward-compatible helper delegating to [TeamDashboardScreen].
class TeamDetailSheet extends StatelessWidget {
  final String teamId;
  final String teamName;
  const TeamDetailSheet({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String teamId,
    required String teamName,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TeamDashboardScreen(teamId: teamId, teamName: teamName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      TeamDashboardScreen(teamId: teamId, teamName: teamName);
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
        border: Border.all(color: mine ? scheme.brandAccent : scheme.border),
        color: mine
            ? scheme.brandAccent.withValues(alpha: 0.1)
            : scheme.card,
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
          color: selected ? scheme.brandAccent : scheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.brandAccent : scheme.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.brandAccent.withValues(alpha: 0.25),
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
                color: selected ? scheme.onBrandAccent : scheme.ink,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.onBrandAccent : scheme.ink,
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
                      label: S.filterAll,
                      selected: _selectedMetric == 'semua',
                      onTap: () => _onFilterChanged(metric: 'semua'),
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
                      label: S.allTime,
                      selected: _selectedPeriod == 'semua',
                      onTap: () => _onFilterChanged(period: 'semua'),
                    ),
                    const SizedBox(width: 8),
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
                          Flexible(
                            child: _podium(
                              top[1].nama,
                              _formatMetricValue(top[1].entry.nilai),
                              68,
                              PacerColors.podiumGray,
                              rank: 2,
                              medal: PacerColors.medalSilver,
                            ),
                          ),
                          Flexible(
                            child: _podium(
                              top[0].nama,
                              _formatMetricValue(top[0].entry.nilai),
                              89,
                              PacerColors.medalGold,
                              rank: 1,
                              medal: PacerColors.medalGold,
                            ),
                          ),
                          Flexible(
                            child: _podium(
                              top[2].nama,
                              _formatMetricValue(top[2].entry.nilai),
                              63,
                              PacerColors.medalBronze,
                              rank: 3,
                              medal: PacerColors.medalBronze,
                            ),
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
                              Text(
                                S.kilometersUnit,
                                style: const TextStyle(
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
                            S.runsCount(list.length),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 24,
                            ),
                          ),
                          Text(
                            list.isEmpty
                                ? '– ${S.averagePace}'
                                : '${fmtPace(totalS, totalKm)} ${S.averagePace}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            '${fmtDurasi(totalS)} ${S.time}',
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

String _challengeDisplayTitle(Challenge c) {
  final t = c.judul?.trim();
  if (t != null && t.isNotEmpty) return t;
  return '${S.sportName(c.jenis)} • ${S.challengeTargetSummary(c.targetNilai, c.targetSatuan)}';
}

class _ChallengeScopeBadge extends StatelessWidget {
  final Challenge challenge;
  final String? teamName;
  final bool lightOnDark;

  const _ChallengeScopeBadge(
    this.challenge, {
    this.teamName,
    this.lightOnDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final isTeam = challenge.isTeamChallenge;
    final label = isTeam
        ? (teamName != null && teamName!.isNotEmpty
              ? '${S.teamChallengeTag} • $teamName'
              : S.teamChallengeTag)
        : S.soloChallengeTag;
    final bg = lightOnDark
        ? (isTeam
              ? scheme.brandAccent.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.16))
        : (isTeam
              ? scheme.brandAccent.withValues(alpha: 0.28)
              : scheme.searchBg);
    final fg = lightOnDark
        ? (isTeam ? scheme.brandAccent : Colors.white)
        : scheme.ink;
    return _ChallengeBadge(label, bg: bg, fg: fg);
  }
}

/// Shared compact challenge progress list used on RunSetupScreen,
/// Finish opt-in sheet (interactive with toggles), and RunFinishScreen (read-only).
class _ChallengeToggleList extends StatelessWidget {
  final List<({Challenge challenge, PartisipasiChallenge participation})> items;
  final Set<String>? selectedIds;
  final void Function(String challengeId, bool selected)? onToggle;

  const _ChallengeToggleList({
    required this.items,
    this.selectedIds,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final item = items[i];
              final c = item.challenge;
              final p = item.participation;
              final isSelected = selectedIds?.contains(c.id) ?? true;
              final pct = progressPercent(p.progressNilai, c.targetNilai);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onToggle == null
                    ? null
                    : () => onToggle!(c.id, !isSelected),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.scaffold
                        : scheme.searchBg.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (onToggle != null && isSelected)
                          ? scheme.brandAccent
                          : scheme.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _ChallengeScopeBadge(c),
                                    if (p.berhasil)
                                      _ChallengeBadge(
                                        S.challengeCompletedLabel,
                                        bg: scheme.success.withValues(
                                          alpha: 0.16,
                                        ),
                                        fg: scheme.success,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _challengeDisplayTitle(c),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: scheme.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onToggle != null)
                            Switch(
                              value: isSelected,
                              activeThumbColor: scheme.brandAccent,
                              onChanged: (v) => onToggle!(c.id, v),
                            )
                          else
                            Text(
                              '${pct.toInt()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: p.berhasil
                                    ? scheme.success
                                    : PacerColors.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: scheme.softBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            p.berhasil ? scheme.success : PacerColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${S.challengeTargetSummary(p.progressNilai, c.targetSatuan)} / '
                        '${S.challengeTargetSummary(c.targetNilai, c.targetSatuan)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

Future<List<String>?> _showFinishChallengeOptInSheet(
  BuildContext context, {
  required List<({Challenge challenge, PartisipasiChallenge participation})>
  eligible,
  required Set<String> initialSelected,
}) {
  final selected = Set<String>.from(initialSelected);
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final scheme = PacerScheme.of(sheetCtx);
      return StatefulBuilder(
        builder: (sheetCtx, setModalState) => SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.finishOptInTitle,
                        style: PacerText.pageTitleOf(
                          sheetCtx,
                        ).copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        S.finishOptInSubtitle,
                        style: TextStyle(fontSize: 13, color: scheme.soft),
                      ),
                      const SizedBox(height: 14),
                      _ChallengeToggleList(
                        items: eligible,
                        selectedIds: selected,
                        onToggle: (id, on) => setModalState(() {
                          if (on) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        }),
                      ),
                      const SizedBox(height: 18),
                      LimeActionBar(
                        S.finishSaveAndContinue,
                        onPressed: () =>
                            Navigator.of(sheetCtx).pop(selected.toList()),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(null),
                          child: Text(S.cancelLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
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
  String? _teamName;
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
      _teamName = null;
      _joined = widget.participation != null ? true : null;
      _load();
    }
  }

  String? get _resolvedId => widget.challengeId ?? _challenge?.id;

  Future<bool> _isLive() async =>
      !(await isDemoAccount()) && _resolvedId != null;

  Challenge? _findDemoChallenge(String? id) {
    final pool = PacerDummyData.demoChallenges;
    if (id != null) {
      for (final c in pool) {
        if (c.id == id) return c;
      }
    }
    return pool.isEmpty ? null : pool.first;
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

  String? _lookupDemoTeamName(String? teamId) {
    if (teamId == null) return null;
    for (final t in PacerDummyData.demoTeams) {
      if (t.id == teamId) return t.nama;
    }
    return null;
  }

  Future<void> _load() async {
    final id = _resolvedId;
    if (await isDemoAccount()) {
      final demo = _challenge ?? _findDemoChallenge(id);
      final matched = demo == null
          ? null
          : _matchParticipation(PacerDummyData.getDemoParticipations(), demo.id);
      final fallback =
          widget.participation != null &&
              widget.participation!.challengeId == demo?.id
          ? widget.participation
          : null;
      final resolvedPart = matched ?? fallback;
      if (mounted) {
        setState(() {
          _challenge = demo;
          _teamName = _lookupDemoTeamName(demo?.teamId);
          _participation = resolvedPart;
          _joined = resolvedPart != null;
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
      String? tName;
      if (chal?.teamId != null) {
        try {
          tName = (await TeamRepository().getTeam(chal!.teamId!))?.nama;
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _challenge = chal ?? _challenge;
          _teamName = tName ?? _teamName;
          _participation = matched;
          _joined = matched != null;
        });
      }
    } catch (_) {
      /* stays in current state → toggle handles offline/network errors */
    }
  }

  Future<void> _activate() async {
    final id = _resolvedId;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await ChallengeRepository().activateChallenge(id);
      final matched = _matchParticipation(updated, id);
      if (mounted) {
        setState(() {
          _participation = matched ?? _participation;
          _changed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.challengeActivatedMsg)),
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

  Future<void> _toggle() async {
    final id = _resolvedId;
    if (!await _isLive() || id == null) {
      final demoId = id ?? _challenge?.id;
      if (demoId == null) return;
      final next = !(_joined == true);
      PartisipasiChallenge? nextPart;
      if (next) {
        nextPart = PacerDummyData.joinDemoChallenge(demoId);
      } else {
        PacerDummyData.leaveDemoChallenge(demoId);
      }
      if (mounted) {
        setState(() {
          _joined = next;
          _participation = nextPart;
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
    if (_joined != true &&
        chal != null &&
        !isChallengeActive(chal, DateTime.now())) {
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
                        chal?.judul?.trim().isNotEmpty == true
                            ? chal!.judul!.trim()
                            : S.challengeDetail,
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
                      _ChallengeScopeBadge(chal, teamName: _teamName),
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
                      else if (part != null && part.isActive)
                        _ChallengeBadge(
                          S.activeSlotBadge,
                          bg: scheme.brandAccent.withValues(alpha: 0.28),
                          fg: scheme.ink,
                        )
                      else if (part != null)
                        _ChallengeBadge(
                          S.waitingSlotBadge,
                          bg: scheme.searchBg,
                          fg: scheme.soft,
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
                          if (!part.berhasil && !part.isActive) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _busy ? null : _activate,
                                child: Text(S.chooseActiveChallenge),
                              ),
                            ),
                          ],
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
  bool _checkingUpdates = false;

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

  Future<void> _checkForUpdates(BuildContext context) async {
    if (_checkingUpdates) return;
    _checkingUpdates = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(S.checkingUpdates),
          duration: const Duration(seconds: 7),
        ),
      );
    try {
      final result = await GitHubUpdateService.instance.checkForUpdate(
        respectDismissed: false,
      );
      if (!context.mounted) return;
      messenger.clearSnackBars();
      switch (result.status) {
        case UpdateCheckStatus.available:
          await UpdateAvailableSheet.show(context, result.release!);
        case UpdateCheckStatus.upToDate:
          messenger.showSnackBar(
            SnackBar(
              content: Text(S.upToDateMsg(GitHubUpdateService.currentVersion)),
            ),
          );
        case UpdateCheckStatus.failed:
          messenger.showSnackBar(SnackBar(content: Text(S.updateCheckFailed)));
      }
    } finally {
      _checkingUpdates = false;
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
                      label: S.theme,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ThemeSettingsScreen(),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: scheme.border),
                    _menuRow(
                      context,
                      label: S.checkForUpdates(
                        GitHubUpdateService.currentVersion,
                      ),
                      onTap: () => _checkForUpdates(context),
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
                            Text(
                              fmtKm(0),
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
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(S.averagePace, '–', '/km'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatCard(
                                    S.totalTime,
                                    '–',
                                    S.unitMinutes,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatCard(
                                    S.activeCalories,
                                    '–',
                                    S.unitKcal,
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
                                  S.unitMinutes,
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
                        Text(
                          '${S.thisWeek} • ${S.daysOf7(0)}',
                          style: const TextStyle(
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
                        '${S.thisWeek} • ${S.daysOf7(doneThisWeek)}',
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
  Map<String, String> teamNames,
});

class ChallengeListScreen extends StatefulWidget {
  const ChallengeListScreen({super.key});

  @override
  State<ChallengeListScreen> createState() => _ChallengeListScreenState();
}

class _ChallengeListScreenState extends State<ChallengeListScreen> {
  Future<_ChallengeListData>? _future;
  String _filter = 'all';
  bool _busy = false;

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
      final parts = PacerDummyData.getDemoParticipations();
      return (
        challenges: PacerDummyData.demoChallenges
            .where((c) => c.diumumkan)
            .toList(),
        participations: {for (final p in parts) p.challengeId: p},
        teamNames: {for (final t in PacerDummyData.demoTeams) t.id: t.nama},
      );
    }
    try {
      final repo = ChallengeRepository();
      final teamRepo = TeamRepository();
      final challenges = (await repo.listChallenges())
          .where((c) => c.diumumkan)
          .toList();
      final parts = await repo.myParticipations();
      final teamNames = <String, String>{};
      try {
        for (final t in await teamRepo.myTeams()) {
          teamNames[t.id] = t.nama;
        }
        for (final t in await teamRepo.listTeams()) {
          teamNames.putIfAbsent(t.id, () => t.nama);
        }
      } catch (_) {}
      return (
        challenges: challenges,
        participations: {for (final p in parts) p.challengeId: p},
        teamNames: teamNames,
      );
    } catch (_) {
      return (
        challenges: const <Challenge>[],
        participations: const <String, PartisipasiChallenge>{},
        teamNames: const <String, String>{},
      );
    }
  }

  Future<void> _activate(String challengeId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ChallengeRepository().activateChallenge(challengeId);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.challengeActivatedMsg)),
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
    String? teamName,
  ) {
    final scheme = PacerScheme.of(context);
    final active = isChallengeActive(c, DateTime.now());
    final pct = part == null
        ? 0.0
        : progressPercent(part.progressNilai, c.targetNilai);
    final String statusLabel;
    final Color statusBg;
    final Color statusFg;
    if (part?.berhasil == true) {
      statusLabel = S.challengeCompletedLabel;
      statusBg = Colors.green.withValues(alpha: 0.25);
      statusFg = Colors.greenAccent;
    } else if (part != null && part.isActive) {
      statusLabel = S.activeSlotBadge;
      statusBg = scheme.brandAccent.withValues(alpha: 0.28);
      statusFg = scheme.brandAccent;
    } else if (part != null) {
      statusLabel = S.waitingSlotBadge;
      statusBg = Colors.white24;
      statusFg = Colors.white;
    } else if (!active) {
      statusLabel = S.challengeEnded;
      statusBg = Colors.white12;
      statusFg = Colors.white70;
    } else {
      statusLabel = S.challengeActive;
      statusBg = Colors.white12;
      statusFg = Colors.white;
    }

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
          gradient: LinearGradient(
            colors: scheme.heroCardGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [scheme.shadowBox],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ChallengeScopeBadge(
                  c,
                  teamName: teamName,
                  lightOnDark: true,
                ),
                _ChallengeBadge(
                  S.sportName(c.jenis),
                  bg: Colors.white12,
                  fg: Colors.white,
                ),
                _ChallengeBadge(
                  statusLabel,
                  bg: statusBg,
                  fg: statusFg,
                ),
              ],
            ),
            if (c.judul != null && c.judul!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                c.judul!.trim(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
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
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${S.challengeTargetSummary(part.progressNilai, c.targetSatuan)} / '
                      '${S.challengeTargetSummary(c.targetNilai, c.targetSatuan)} • '
                      '${pct.toInt()}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!part.berhasil && !part.isActive)
                    TextButton(
                      onPressed: _busy ? null : () => _activate(c.id),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.brandAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                      child: Text(S.chooseActiveChallenge),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final opt in [
                    ('all', S.filterAll),
                    ('team', S.filterTeam),
                    ('solo', S.filterSolo),
                  ])
                    GestureDetector(
                      onTap: () => setState(() => _filter = opt.$1),
                      child: GoalChip(
                        label: opt.$2,
                        selected: _filter == opt.$1,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                S.activeSlotHint,
                style: TextStyle(fontSize: 12, color: scheme.muted),
              ),
              const SizedBox(height: 12),
              FutureBuilder<_ChallengeListData>(
                future: _future,
                builder: (context, snap) {
                  final data = snap.data;
                  final all = data?.challenges;
                  if (all == null) {
                    return const PacerLoading();
                  }
                  final filtered = all.where((c) {
                    if (_filter == 'team') return c.isTeamChallenge;
                    if (_filter == 'solo') return !c.isTeamChallenge;
                    return true;
                  }).toList();
                  if (filtered.isEmpty) {
                    return PacerEmptyState(
                      S.noChallengesCachedEmpty,
                      icon: Icons.emoji_events_outlined,
                    );
                  }
                  final parts = data!.participations;
                  final teamNames = data.teamNames;
                  return Column(
                    children: [
                      for (final c in filtered)
                        _challengeCard(
                          context,
                          w,
                          c,
                          parts[c.id],
                          c.teamId == null ? null : teamNames[c.teamId!],
                        ),
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
                        decoration: BoxDecoration(
                          color: PacerScheme.of(context).brandAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: PacerScheme.of(context).onBrandAccent,
                        ),
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
                  onPressed: () => Navigator.of(context).pushReplacement<bool, Object?>(
                    MaterialPageRoute(builder: (_) => const CreateClubScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PacerScheme.of(context).brandAccent,
                    foregroundColor: PacerScheme.of(context).onBrandAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    S.agree,
                    style: TextStyle(
                      color: PacerScheme.of(context).onBrandAccent,
                    ),
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
      PacerDummyData.createDemoTeam(nama, isPrivate: _private);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.teamCreated)));
        Navigator.of(context).pop(true);
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await TeamRepository().createTeam(nama: nama, isPrivate: _private);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.teamCreated)));
        Navigator.of(context).pop(true);
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

/// Create Solo Challenge (for any user) or Team Challenge (Coach/Admin/Ketua).
/// Coaches & team leaders can only pick teams they belong to / manage.
/// Sport, unified distance target presets (or custom km), duration window
/// (presets or custom days), and optional title.
class CreateChallengeScreen extends StatefulWidget {
  final String? initialTeamId;

  const CreateChallengeScreen({super.key, this.initialTeamId});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final TextEditingController _judulCtrl = TextEditingController();
  int _jenisIdx = 0; // 'lari'
  int _distIdx = 1; // '5 km'
  int _durasi = 2; // 1 week
  double? _customKm;
  int? _customDays;
  bool _busy = false;
  String? _error;
  bool _isTeamMode = false;
  String? _selectedTeamId;
  List<Team> _manageableTeams = const [];

  static const _distancePresetsKm = [3.0, 5.0, 10.0, 25.0, 30.0, 45.0];
  static const _durasiDays = [1, 3, 7];

  @override
  void initState() {
    super.initState();
    if (widget.initialTeamId != null) {
      _isTeamMode = true;
      _selectedTeamId = widget.initialTeamId;
    }
    _loadCapabilities();
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCapabilities() async {
    try {
      final List<Team> teams = [];
      if (await isDemoAccount()) {
        for (final t in PacerDummyData.demoMyTeams) {
          final isLeader =
              t.dibuatOleh == 'demo-user-me' ||
              PacerDummyData.getTeamRoster(
                t.id,
              ).any((m) => m.userId == 'demo-user-me' && m.peran == 'ketua');
          if (isLeader || t.id == widget.initialTeamId) {
            teams.add(t);
          }
        }
      } else {
        final auth = AuthRepository();
        final repo = TeamRepository();
        final uid = await auth.resolveUserId();
        final profile = await auth.getProfile();
        final isAdmin = profile?.peran == 'admin';
        final isCoach = profile?.peran == 'coach';
        if (isAdmin) {
          final all = await repo.listTeams();
          teams.addAll(all.isNotEmpty ? all : await repo.myTeams());
        } else if (uid != null) {
          // Coaches and team leaders only create challenges for teams they belong to.
          final mine = await repo.myTeams();
          final rosters = isCoach
              ? const <List<TeamRosterMember>>[]
              : await Future.wait([
                  for (final t in mine)
                    repo
                        .teamRoster(t.id)
                        .catchError((_) => const <TeamRosterMember>[]),
                ]);
          for (var i = 0; i < mine.length; i++) {
            final t = mine[i];
            final isLeader =
                isCoach ||
                t.dibuatOleh == uid ||
                rosters[i].any((m) => m.userId == uid && m.peran == 'ketua');
            if (isLeader) {
              teams.add(t);
            }
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _manageableTeams = teams;
        if (widget.initialTeamId != null &&
            teams.any((t) => t.id == widget.initialTeamId)) {
          _selectedTeamId = widget.initialTeamId;
          _isTeamMode = true;
        } else if (teams.isNotEmpty) {
          if (_selectedTeamId == null ||
              !teams.any((t) => t.id == _selectedTeamId)) {
            _selectedTeamId = teams.first.id;
          }
          if (widget.initialTeamId != null) {
            _isTeamMode = false;
          }
        } else {
          _isTeamMode = false;
          _selectedTeamId = null;
        }
      });
    } catch (_) {}
  }

  Future<double?> _askCustomKm() async {
    final initial = _customKm == null
        ? ''
        : (_customKm == _customKm!.truncateToDouble()
              ? '${_customKm!.toInt()}'
              : '$_customKm');
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => _ChallengeNumberPromptDialog(
        title: S.customDistanceTitle,
        initialText: initial,
        suffixText: 'km',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validate: (text) {
          final v = double.tryParse(text.replaceAll(',', '.'));
          return (v == null || v <= 0) ? S.errFillAll : null;
        },
      ),
    );
    if (raw == null) return null;
    final v = double.tryParse(raw.replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  Future<int?> _askCustomDays() async {
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => _ChallengeNumberPromptDialog(
        title: S.customDurationTitle,
        initialText: _customDays == null ? '' : '$_customDays',
        hintText: S.customDurationHint,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validate: (text) {
          final v = int.tryParse(text);
          return (v == null || v < 1 || v > 365)
              ? S.invalidCustomDuration
              : null;
        },
      ),
    );
    if (raw == null) return null;
    final v = int.tryParse(raw);
    return (v == null || v < 1 || v > 365) ? null : v;
  }

  Future<void> _tapCustomDistance() async {
    final v = await _askCustomKm();
    if (v == null || !mounted) return;
    setState(() {
      _customKm = v;
      _distIdx = _distancePresetsKm.length;
    });
  }

  Future<void> _tapCustomDuration() async {
    final days = await _askCustomDays();
    if (days == null || !mounted) return;
    setState(() {
      _customDays = days;
      _durasi = _durasiDays.length;
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final double? targetKm = _distIdx >= 0 && _distIdx < _distancePresetsKm.length
        ? _distancePresetsKm[_distIdx]
        : _customKm;
    final int? windowDays = _durasi >= 0 && _durasi < _durasiDays.length
        ? _durasiDays[_durasi]
        : _customDays;
    if (targetKm == null ||
        targetKm <= 0 ||
        windowDays == null ||
        windowDays <= 0 ||
        (_isTeamMode && _selectedTeamId == null)) {
      setState(() => _error = S.errFillAll);
      return;
    }
    final now = DateTime.now();
    final judul = _judulCtrl.text.trim();
    setState(() => _busy = true);
    try {
      await ChallengeRepository().createChallenge(
        jenis: aktivitasJenis[_jenisIdx],
        targetNilai: targetKm * 1000,
        targetSatuan: 'jarak_m',
        teamId: _isTeamMode ? _selectedTeamId : null,
        judul: judul.isEmpty ? null : judul,
        waktuMulai: now,
        waktuSelesai: now.add(Duration(days: windowDays)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.challengeCreated)),
      );
      Navigator.of(context).pop(true);
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
    ValueChanged<int> onTap, {
    String? helperText,
  }) {
    final scheme = PacerScheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.soft,
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 2),
            Text(
              helperText,
              style: TextStyle(fontSize: 12, color: scheme.muted),
            ),
          ],
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
    final scheme = PacerScheme.of(context);
    final distanceOptions = [
      for (final km in _distancePresetsKm) '${km.toInt()} km',
      _customKm != null && _distIdx == _distancePresetsKm.length
          ? S.customKmLabel(_customKm!)
          : S.custom,
    ];
    final durationOptions = [
      S.todayLabel,
      S.days3,
      S.week1,
      _customDays != null && _durasi == _durasiDays.length
          ? S.customDaysLabel(_customDays!)
          : S.custom,
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
                _isTeamMode ? S.createTeamChallenge : S.createChallenge,
                style: PacerText.pageTitleOf(context).copyWith(fontSize: 26),
              ),
              const SizedBox(height: 14),
              if (_manageableTeams.isNotEmpty) ...[
                _group(
                  S.challengeScopeLabel,
                  [S.challengeScopeSolo, S.challengeScopeTeam],
                  _isTeamMode ? 1 : 0,
                  (i) => setState(() {
                    _isTeamMode = i == 1;
                    if (_isTeamMode && _manageableTeams.isNotEmpty) {
                      _selectedTeamId ??= _manageableTeams.first.id;
                    }
                  }),
                ),
                if (_isTeamMode) ...[
                  Text(
                    S.pickTeam,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.soft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _manageableTeams.any(
                          (t) => t.id == _selectedTeamId,
                        )
                        ? _selectedTeamId
                        : _manageableTeams.first.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: scheme.formField,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: scheme.border),
                      ),
                    ),
                    items: [
                      for (final t in _manageableTeams)
                        DropdownMenuItem<String>(
                          value: t.id,
                          child: Text(t.nama),
                        ),
                    ],
                    onChanged: (v) => setState(() => _selectedTeamId = v),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
              Text(
                S.challengeTitleLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.soft,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _judulCtrl,
                decoration: InputDecoration(
                  hintText: S.challengeTitleHint,
                  filled: true,
                  fillColor: scheme.formField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _group(
                S.challengeSportLabel,
                [for (final j in aktivitasJenis) S.sportName(j)],
                _jenisIdx,
                (i) => setState(() => _jenisIdx = i),
              ),
              _group(
                S.targetDistanceLabel,
                distanceOptions,
                _distIdx,
                (i) {
                  if (i == _distancePresetsKm.length) {
                    _tapCustomDistance();
                  } else {
                    setState(() => _distIdx = i);
                  }
                },
                helperText: S.targetDistanceHint,
              ),
              _group(
                S.durationLabel,
                durationOptions,
                _durasi,
                (i) {
                  if (i == _durasiDays.length) {
                    _tapCustomDuration();
                  } else {
                    setState(() => _durasi = i);
                  }
                },
              ),
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
                _isTeamMode ? S.createTeamChallenge : S.createChallenge,
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

/// Dialog prompting for a positive custom numeric value while tying its
/// [TextEditingController] lifecycle to [State.dispose] so route exit
/// transitions never touch a disposed controller.
class _ChallengeNumberPromptDialog extends StatefulWidget {
  final String title;
  final String initialText;
  final String? hintText;
  final String? suffixText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String text) validate;

  const _ChallengeNumberPromptDialog({
    required this.title,
    required this.initialText,
    this.hintText,
    this.suffixText,
    required this.keyboardType,
    this.inputFormatters,
    required this.validate,
  });

  @override
  State<_ChallengeNumberPromptDialog> createState() =>
      _ChallengeNumberPromptDialogState();
}

class _ChallengeNumberPromptDialogState
    extends State<_ChallengeNumberPromptDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    final err = widget.validate(trimmed);
    if (err != null) {
      setState(() => _errorText = err);
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hintText,
          suffixText: widget.suffixText,
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancelLabel),
        ),
        TextButton(onPressed: _submit, child: Text(S.saveLabel)),
      ],
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
      return Center(child: Text(S.emptyChat));
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
              if (!_demo) ...[
                const SizedBox(height: 8),
                const SyncStatusBanner(),
              ],
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
        (_) => const NotificationsScreen(),
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
                            if (t.$2 == Icons.notifications_active_outlined)
                              ValueListenableBuilder<int>(
                                valueListenable:
                                    NotificationRepository.unreadCountNotifier,
                                builder: (_, count, _) => Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(t.$2, size: 28),
                                    if (count > 0)
                                      Positioned(
                                        right: -8,
                                        top: -6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: PacerColors.lime,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            count > 99 ? '99+' : '$count',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: PacerColors.navy,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            else
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
                sub: S.langDefaultSub,
                selected: current == Lang.id,
                onTap: () => _setLang(Lang.id),
              ),
              const SizedBox(height: 12),
              _langOption(
                context,
                label: 'English',
                sub: S.langAlternativeSub,
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
    final scheme = PacerScheme.of(context);
    return Scaffold(
      backgroundColor: scheme.scaffold,
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          padding: const EdgeInsets.only(top: 16, bottom: 32),
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
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: scheme.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Classic Linux Desktop Themes',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: scheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Iconic Linux desktop environment palettes for both Dark & Light modes.',
                style: TextStyle(fontSize: 13, color: scheme.soft),
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<PacerLinuxTheme>(
                valueListenable: linuxThemeNotifier,
                builder: (context, currentPreset, _) => Column(
                  children: [
                    for (var i = 0; i < PacerLinuxThemeInfo.all.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _linuxThemeOption(
                        context,
                        info: PacerLinuxThemeInfo.all[i],
                        selected: currentPreset == PacerLinuxThemeInfo.all[i].id,
                        onTap: () => setLinuxTheme(PacerLinuxThemeInfo.all[i].id),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linuxThemeOption(
    BuildContext context, {
    required PacerLinuxThemeInfo info,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = PacerScheme.of(context);
    return InkWell(
      key: ValueKey('linux_theme_${info.id.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? info.accent : scheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Live color swatch preview pill
            Container(
              width: 48,
              height: 44,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: info.darkBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: info.accent.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: info.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: info.secondaryAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: info.darkSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      color: scheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info.desktopEnv,
                    style: TextStyle(fontSize: 12, color: scheme.soft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_off,
              color: selected ? info.accent : scheme.soft,
            ),
          ],
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

/// Backward-compatible alias for any callers/tests referencing the old name.
typedef NotificationMockScreen = NotificationsScreen;

/// Push notification center & member inbox backed by [NotificationRepository].
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repo = NotificationRepository();
  List<AppNotification> _items = const [];
  bool _loading = true;
  bool _unreadOnly = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    NotificationRepository.revisionNotifier.addListener(_onRevision);
    _load(forceRefresh: true);
  }

  @override
  void dispose() {
    NotificationRepository.revisionNotifier.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) _load(forceRefresh: false);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    try {
      final list = await _repo.listNotifications(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.markAllRead();
      await _load(forceRefresh: false);
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

  Future<void> _openNotification(AppNotification n) async {
    if (!n.isRead) {
      try {
        await _repo.markAsRead(n.id);
        await _load(forceRefresh: false);
      } catch (_) {}
    }
    if (!mounted) return;
    if (n.challengeId != null && n.challengeId!.isNotEmpty) {
      await ChallengeDetailSheet.show(context, challengeId: n.challengeId);
      if (mounted) await _load(forceRefresh: false);
      return;
    }
    if (n.teamId != null && n.teamId!.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TeamDashboardScreen(teamId: n.teamId!),
        ),
      );
      if (mounted) await _load(forceRefresh: false);
    }
  }

  (IconData, Color) _styleForType(String type, PacerScheme scheme) {
    switch (type) {
      case 'challenge_completed':
        return (Icons.check_circle_outline, scheme.success);
      case 'team_challenge_assigned':
      case 'team_challenge':
        return (Icons.emoji_events, PacerColors.primary);
      case 'team_role_changed':
      case 'role_updated':
      case 'team_role':
        return (Icons.groups_outlined, PacerColors.lime);
      default:
        return (Icons.notifications_active, PacerColors.lime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final unreadCount = _items.where((n) => !n.isRead).length;
    final visible = _unreadOnly
        ? _items.where((n) => !n.isRead).toList()
        : _items;

    return Scaffold(
      backgroundColor: scheme.scaffold,
      body: SafeArea(
        child: ResponsiveScroll(
          maxWidth: 720,
          onRefresh: () => _load(forceRefresh: true),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      S.notificationsTitle,
                      style: PacerText.pageTitleOf(context),
                    ),
                  ),
                  if (unreadCount > 0)
                    TextButton(
                      onPressed: _busy ? null : _markAllRead,
                      child: Text(S.markAllRead),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _unreadOnly = false),
                    child: GoalChip(
                      label: S.notificationsAllFilter,
                      selected: !_unreadOnly,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _unreadOnly = true),
                    child: GoalChip(
                      label: unreadCount > 0
                          ? '${S.notificationsUnreadFilter} ($unreadCount)'
                          : S.notificationsUnreadFilter,
                      selected: _unreadOnly,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading && _items.isEmpty)
                const PacerLoading()
              else if (visible.isEmpty)
                PacerEmptyState(
                  S.noNotificationsEmpty,
                  icon: Icons.notifications_none_outlined,
                )
              else
                for (final n in visible)
                  Builder(
                    builder: (context) {
                      final (icon, color) = _styleForType(n.type, scheme);
                      final timeLabel = n.createdAt == null
                          ? ''
                          : fmtDate(n.createdAt!);
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openNotification(n),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: n.isRead ? scheme.border : PacerColors.lime,
                              width: n.isRead ? 1 : 1.4,
                            ),
                            boxShadow: [scheme.shadowBox],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, size: 22, color: color),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (!n.isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: PacerColors.lime,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
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
                                        if (timeLabel.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            timeLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: scheme.muted,
                                            ),
                                          ),
                                        ],
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

/// Modal bottom sheet displayed when a newer GitHub Release is available.
class UpdateAvailableSheet extends StatelessWidget {
  final GitHubReleaseInfo release;

  const UpdateAvailableSheet({super.key, required this.release});

  static Future<void> show(BuildContext context, GitHubReleaseInfo release) {
    final scheme = PacerScheme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => UpdateAvailableSheet(release: release),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final apkSize = release.formattedApkSize;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildHeader(scheme, apkSize),
            const SizedBox(height: 12),
            Text(
              S.updateAvailableSub(
                GitHubUpdateService.currentVersion,
                release.tagName,
              ),
              style: TextStyle(fontSize: 13.5, color: scheme.bodyGray, height: 1.4),
            ),
            const SizedBox(height: 14),
            Text(
              S.releaseNotesTitle,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: scheme.muted,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.scaffold,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    release.notes.isNotEmpty ? release.notes : S.noReleaseNotes,
                    style: TextStyle(fontSize: 13, color: scheme.chipFg, height: 1.45),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            LimeActionBar(
              S.downloadUpdateCta,
              onPressed: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                final ok = await GitHubUpdateService.instance.openReleaseDownload(
                  release,
                );
                if (!context.mounted) return;
                if (ok) {
                  Navigator.of(context).pop();
                } else {
                  messenger?.showSnackBar(SnackBar(content: Text(S.updateOpenFailed)));
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      await GitHubUpdateService.instance.dismissVersion(
                        release.tagName,
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(
                      S.skipVersionCta,
                      style: TextStyle(
                        color: scheme.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      S.laterCta,
                      style: TextStyle(
                        color: scheme.chipFg,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PacerScheme scheme, String? apkSize) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.accent.withValues(alpha: 0.35)),
          ),
          child: Icon(
            Icons.system_update_alt_rounded,
            color: scheme.accent,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.updateAvailableTitle,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: scheme.chipFg,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _badge(
                    'v${GitHubUpdateService.currentVersion} → ${release.tagName}',
                    bg: scheme.brandAccent,
                    fg: scheme.onBrandAccent,
                  ),
                  if (apkSize != null)
                    _badge(
                      'APK • $apkSize',
                      bg: scheme.scaffold,
                      fg: scheme.muted,
                      borderColor: scheme.border,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(
    String text, {
    required Color bg,
    required Color fg,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
