import 'package:flutter/material.dart';
import 'package:pacer/src/aktivitas/activity_repository.dart';
import 'package:pacer/src/auth/auth_repository.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/challenge/challenge_repository.dart';
import 'package:pacer/src/teams/team_model.dart';
import 'package:pacer/src/teams/team_repository.dart';
import 'package:pacer/supabase.dart';

import 'app_strings.dart';
import 'app_theme.dart';
import 'format.dart';
import 'widgets.dart';

/// Coach class board (PE grading): pick a team and see every member's
/// current-week sessions + distance, streak, and optional challenge progress.
///
/// Coach-gated twice: the screen refuses non-coach roles, and the tables are
/// additionally RLS-gated server-side (coach-read policies + owner policies).
class CoachBoardScreen extends StatefulWidget {
  const CoachBoardScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _gate = _checkCoach();
  }

  bool get _backend {
    try {
      supa;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Null when signed out/offline/non-coach (with a reason string).
  Future<_Gate> _checkCoach() async {
    if (!_backend) return (coach: null, reason: 'offline');
    try {
      if (supa.auth.currentUser == null) {
        return (coach: null, reason: 'signed-out');
      }
      final profile = await AuthRepository().getProfile();
      final peran = profile?.peran ?? 'user';
      if (peran == 'coach' || peran == 'admin') {
        final teams = await TeamRepository().listTeams();
        final challenges = await ChallengeRepository().listChallenges();
        if (mounted) {
          setState(() {
            _teams = teams;
            _challenges = challenges;
            _teamId ??= teams.isEmpty ? null : teams.first.id;
          });
        }
        _refresh();
        return (coach: true, reason: '');
      }
      return (coach: false, reason: '');
    } catch (_) {
      return (coach: null, reason: 'error');
    }
  }

  void _refresh() {
    final teamId = _teamId;
    if (teamId == null) return;
    setState(() {
      _rows = _loadRows(teamId, _challengeId);
    });
  }

  Future<List<_CoachRow>> _loadRows(String teamId, String? challengeId) async {
    final roster = await TeamRepository().teamRoster(teamId);
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final actRepo = ActivityRepository();
    final Map<String, ({double progress, bool berhasil})> prog = {};
    if (challengeId != null) {
      final parts = await ChallengeRepository().participationsForChallenge(
        challengeId,
      );
      for (final p in parts) {
        prog[p.userId] = (progress: p.progressNilai, berhasil: p.berhasil);
      }
    }
    final out = <_CoachRow>[];
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
      } catch (_) {
        // Per-student failures degrade to zeros, never break the table.
      }
      final cp = prog[m.userId];
      out.add(
        _CoachRow(
          nama: m.nama,
          sessions: sessions,
          weekKm: weekM / 1000,
          streak: streak,
          progress: cp?.progress,
          berhasil: cp?.berhasil,
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
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
              Text(S.coachBoard, style: PacerText.pageTitle),
              const SizedBox(height: 16),
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
    return DropdownButtonFormField<String?>(
      initialValue: _challengeId,
      decoration: InputDecoration(
        labelText: S.pickChallenge,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('–')),
        for (final c in _challenges)
          DropdownMenuItem(
            value: c.id,
            child: Text(
              '${c.jenis} • ${c.targetNilai}',
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PacerColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              if (r.berhasil == true)
                const Icon(Icons.verified, color: Colors.green, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${r.sessions} ${S.sessionsCol} • ${fmtKmNum(r.weekKm * 1000)} Km • streak ${r.streak}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: PacerColors.slate700),
          ),
          if (r.progress != null)
            Text(
              'progress ${r.progress!.toStringAsFixed(1)}${r.berhasil == true ? ' • ✓' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: PacerColors.slate500),
            ),
        ],
      ),
    );
  }
}

typedef _Gate = ({bool? coach, String reason});
