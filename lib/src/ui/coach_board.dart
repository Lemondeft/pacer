import 'package:flutter/material.dart';
import 'package:pacer/src/aktivitas/activity_repository.dart';
import 'package:pacer/src/auth/auth_repository.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/challenge/challenge_repository.dart';
import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/teams/team_model.dart';
import 'package:pacer/src/teams/team_repository.dart';

import 'app_strings.dart';
import 'app_theme.dart';
import 'format.dart';
import 'pacer_glass.dart' show PacerSquircleBorder;
import 'widgets.dart';

/// Coach class board (PE grading): pick a coached team and see every member's
/// current-week sessions + distance, streak, and optional challenge progress.
///
/// Scoped to teams where the signed-in user holds `team_members.peran = 'coach'`
/// (or all active teams for platform `'admin'`), reinforced server-side by RLS.
class CoachBoardScreen extends StatefulWidget {
  final String? initialTeamId;

  const CoachBoardScreen({super.key, this.initialTeamId});

  @override
  State<CoachBoardScreen> createState() => _CoachBoardScreenState();
}

class _CoachRow {
  final String nama;
  final int sessions;
  final double weekKm;
  final int streak;
  final double? progress;
  final bool? berhasil;
  const _CoachRow({
    required this.nama,
    required this.sessions,
    required this.weekKm,
    required this.streak,
    this.progress,
    this.berhasil,
  });
}

class _CoachBoardScreenState extends State<CoachBoardScreen> {
  Future<_Gate>? _gate;
  List<Team> _teams = [];
  List<Challenge> _challenges = [];
  String? _teamId;
  String? _challengeId;
  Future<List<_CoachRow>>? _rows;
  bool _isDemo = true;

  @override
  void initState() {
    super.initState();
    _teamId = widget.initialTeamId;
    _gate = _checkCoach();
  }

  /// Grants access when the user coaches at least one active team (or is admin).
  Future<_Gate> _checkCoach() async {
    if (await isDemoAccount()) {
      _isDemo = true;
      final demoTeams = PacerDummyData.demoTeams;
      final initialId =
          widget.initialTeamId != null &&
              demoTeams.any((t) => t.id == widget.initialTeamId)
          ? widget.initialTeamId
          : (demoTeams.isEmpty ? null : demoTeams.first.id);
      if (mounted) {
        setState(() {
          _teams = demoTeams;
          _challenges = PacerDummyData.demoChallenges;
          _teamId = initialId;
        });
      }
      _refresh();
      return (coach: true, reason: '');
    }
    _isDemo = false;
    try {
      final profile = await AuthRepository().getProfile();
      final isAdmin = profile?.peran == 'admin';
      final teams = isAdmin
          ? await TeamRepository().listTeams()
          : await TeamRepository().myCoachedTeams();
      if (isAdmin || teams.isNotEmpty) {
        final challenges = await ChallengeRepository().listChallenges();
        final resolvedTeamId =
            _teamId != null && teams.any((t) => t.id == _teamId)
            ? _teamId
            : (teams.isEmpty ? null : teams.first.id);
        if (mounted) {
          setState(() {
            _teams = teams;
            _challenges = challenges;
            _teamId = resolvedTeamId;
          });
        }
        _refresh();
        return (coach: true, reason: '');
      }
      return (coach: false, reason: 'no-coached-teams');
    } catch (_) {
      return (coach: false, reason: '');
    }
  }

  List<_CoachRow> _dummyRows() {
    return PacerDummyData.coachDummyRows
        .map(
          (r) => _CoachRow(
            nama: r.nama,
            sessions: r.sessions,
            weekKm: r.weekKm,
            streak: r.streak,
            progress: r.progress,
            berhasil: r.berhasil,
          ),
        )
        .toList();
  }

  List<_CoachRow> _mapLocalRows(List<LocalCoachRow> rows) => [
    for (final r in rows)
      _CoachRow(
        nama: r.nama,
        sessions: r.sessions,
        weekKm: r.weekKm,
        streak: r.streak,
        progress: r.progress,
        berhasil: r.berhasil,
      ),
  ];

  void _refresh() {
    final teamId = _teamId;
    if (teamId == null) return;
    setState(() {
      _rows = _loadRows(teamId, _challengeId);
    });
  }

  Future<List<_CoachRow>> _loadRows(String teamId, String? challengeId) async {
    if (await isDemoAccount()) return _dummyRows();
    final uid = await AuthRepository().resolveUserId() ?? '';
    final cached = await LocalStore.instance.getCoachRows(
      uid,
      teamId,
      challengeId,
    );
    if (!ConnectivityService.instance.value &&
        cached != null &&
        cached.isNotEmpty) {
      return _mapLocalRows(cached);
    }
    try {
      final roster = await TeamRepository().teamRoster(teamId);
      if (roster.isEmpty) {
        return cached != null ? _mapLocalRows(cached) : const [];
      }
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final actRepo = ActivityRepository();
      final Map<String, ({double progress, bool berhasil})> prog = {};
      if (challengeId != null) {
        Challenge? selected;
        for (final c in _challenges) {
          if (c.id == challengeId) {
            selected = c;
            break;
          }
        }
        selected ??= await ChallengeRepository().getChallengeById(challengeId);
        final parts = await ChallengeRepository().participationsForChallenge(
          challengeId,
        );
        for (final p in parts) {
          final pct = selected != null
              ? progressPercent(p.progressNilai, selected.targetNilai)
              : (p.berhasil ? 100.0 : 0.0);
          prog[p.userId] = (progress: pct, berhasil: p.berhasil);
        }
      }
      final localRows = <LocalCoachRow>[];
      var remoteSucceeded = 0;
      for (final m in roster) {
        int sessions = 0;
        double weekM = 0;
        int streak = 0;
        try {
          final acts = await actRepo.listActivitiesFor(m.userId);
          for (final a in acts) {
            // Finished sessions started Monday onward (durasi set at finish).
            final t = a.mulaiAt;
            if (t != null && !t.isBefore(monday) && (a.durasiS ?? 0) > 0) {
              sessions++;
              weekM += a.jarakM ?? 0;
            }
          }
          streak = (await actRepo.getStreakFor(m.userId))?.berjalan ?? 0;
          remoteSucceeded++;
        } catch (_) {
          // Per-student failures degrade to zeros unless entire fetch was offline.
        }
        final cp = prog[m.userId];
        localRows.add(
          LocalCoachRow(
            userId: m.userId,
            nama: m.nama,
            sessions: sessions,
            weekKm: weekM / 1000,
            streak: streak,
            progress: cp?.progress,
            berhasil: cp?.berhasil,
          ),
        );
      }
      if (remoteSucceeded == 0 && cached != null && cached.isNotEmpty) {
        return _mapLocalRows(cached);
      }
      if (uid.isNotEmpty && remoteSucceeded > 0) {
        await LocalStore.instance.saveCoachRows(
          uid,
          teamId,
          challengeId,
          localRows,
        );
      }
      return _mapLocalRows(localRows);
    } catch (_) {
      return cached != null ? _mapLocalRows(cached) : const [];
    }
  }

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
              Text(S.coachBoard, style: PacerText.pageTitleOf(context)),
              const SizedBox(height: 12),
              if (!_isDemo) const SyncStatusBanner(),
              const SizedBox(height: 4),
              FutureBuilder<_Gate>(
                future: _gate,
                builder: (context, snap) {
                  final g = snap.data;
                  if (g == null) {
                    return const PacerLoading();
                  }
                  if (g.coach != true) return _denied(g.reason);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _teamPicker(),
                      const SizedBox(height: 12),
                      _challengePicker(),
                      const SizedBox(height: 16),
                      FutureBuilder<List<_CoachRow>>(
                        future: _rows,
                        builder: (context, rsnap) {
                          if (rsnap.connectionState ==
                              ConnectionState.waiting) {
                            return const PacerLoading();
                          }
                          final rows = rsnap.data ?? const <_CoachRow>[];
                          if (rows.isEmpty) {
                            return PacerEmptyState(
                              S.noMembers,
                              icon: Icons.groups_outlined,
                            );
                          }
                          return Column(
                            children: [for (final r in rows) _rowCard(r)],
                          );
                        },
                      ),
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

  Widget _denied(String reason) {
    final msg = switch (reason) {
      'signed-out' => S.errLoginFailed,
      'offline' => S.errSaveFailed,
      'no-coached-teams' => S.coachBoardNoTeamsHint,
      _ => S.coachOnly,
    };
    return PacerEmptyState(msg, icon: Icons.lock_outline);
  }

  Widget _teamPicker() {
    if (_teams.isEmpty) {
      return PacerEmptyState(S.noMembers, icon: Icons.groups_outlined);
    }
    return DropdownButtonFormField<String>(
      initialValue: _teamId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: S.pickTeam,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final t in _teams)
          DropdownMenuItem(
            value: t.id,
            child: Text(t.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        setState(() => _teamId = v);
        _refresh();
      },
    );
  }

  Widget _challengePicker() {
    final teamId = _teamId;
    final visible = [
      for (final c in _challenges)
        if (c.teamId == null || c.teamId == teamId) c,
    ];
    final currentValue = visible.any((c) => c.id == _challengeId)
        ? _challengeId
        : null;
    return DropdownButtonFormField<String?>(
      initialValue: currentValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: S.pickChallenge,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('–')),
        for (final c in visible)
          DropdownMenuItem(
            value: c.id,
            child: Text(
              '${c.isTeamChallenge ? '[${S.teamChallengeTag}] ' : ''}'
              '${c.judul?.isNotEmpty == true ? '${c.judul!} · ' : ''}'
              '${S.sportName(c.jenis)} • ${S.challengeTargetSummary(c.targetNilai, c.targetSatuan)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) {
        setState(() => _challengeId = v);
        _refresh();
      },
    );
  }

  Widget _rowCard(_CoachRow r) {
    final scheme = PacerScheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final okColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
    final completed = r.berhasil == true;
    return PacerSurface(
      radius: PacerRadii.md,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PacerText.cardTitleOf(context),
                ),
              ),
              if (completed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: ShapeDecoration(
                    color: okColor.withValues(alpha: 0.14),
                    shape: PacerSquircleBorder(
                      PacerRadii.sm,
                      side: BorderSide(color: okColor.withValues(alpha: 0.55)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: okColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        S.challengeCompletedLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: okColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${r.sessions} ${S.sessionsCol} • ${fmtKmNum(r.weekKm * 1000)} Km • streak ${r.streak}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: scheme.muted).tabularFigures(),
          ),
          if (r.progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (r.progress! / 100).clamp(0.0, 1.0),
                backgroundColor: scheme.groupedDivider,
                valueColor: AlwaysStoppedAnimation<Color>(
                  completed ? okColor : scheme.brandAccent,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              S.coachEvaluationLine(
                r.progress!.toStringAsFixed(1),
                completed,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.soft).tabularFigures(),
            ),
          ],
        ],
      ),
    );
  }
}

typedef _Gate = ({bool? coach, String reason});
