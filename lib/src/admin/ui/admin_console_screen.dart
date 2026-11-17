import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/format.dart';
import 'package:pacer/src/ui/widgets.dart';

import '../admin_models.dart';
import '../admin_repository.dart';

/// Role-gated Super Admin workspace for role management, Coach Invite Codes,
/// summary-only anti-cheat review (no raw GPS tracks), and audit logs.
class AdminConsoleScreen extends StatefulWidget {
  final AdminRepository? repository;
  final String? currentUserId;
  final int initialTab;

  const AdminConsoleScreen({
    super.key,
    this.repository,
    this.currentUserId,
    this.initialTab = 0,
  });

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  late final AdminRepository _repo = widget.repository ?? AdminRepository();
  late int _tabIndex = widget.initialTab.clamp(0, 3);
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _mutating = false;
  String? _error;
  String? _roleFilter;

  AdminOverviewStats _stats = const AdminOverviewStats();
  List<AdminUserEntry> _users = const [];
  List<CoachInvite> _invites = const [];
  List<AdminFlaggedActivity> _flagged = const [];
  List<AdminAuditEntry> _auditLogs = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getOverviewStats(),
        _repo.listUsers(query: _searchCtrl.text, role: _roleFilter),
        _repo.listCoachInvites(),
        _repo.listFlaggedActivities(),
        _repo.listAuditLogs(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as AdminOverviewStats;
        _users = results[1] as List<AdminUserEntry>;
        _invites = results[2] as List<CoachInvite>;
        _flagged = results[3] as List<AdminFlaggedActivity>;
        _auditLogs = results[4] as List<AdminAuditEntry>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _reloadUsers() async {
    try {
      final users = await _repo.listUsers(
        query: _searchCtrl.text,
        role: _roleFilter,
      );
      if (mounted) setState(() => _users = users);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future<void> _changeRole(AdminUserEntry user) async {
    String selected = user.peran;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${S.adminChangeRoleTitle} · ${user.nama}'),
          content: RadioGroup<String>(
            groupValue: selected,
            onChanged: (val) {
              if (val != null) setDialogState(() => selected = val);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final role in AdminRepository.allowedRoles)
                  RadioListTile<String>(
                    value: role,
                    title: Text(role.toUpperCase()),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(selected),
              child: Text(S.adminSaveRoleCta),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || chosen == user.peran || _mutating) return;
    setState(() => _mutating = true);
    try {
      await _repo.setUserRole(targetUserId: user.id, newRole: chosen);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(S.adminRoleUpdatedNotice)));
      await _loadAll();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _generateCoachInvite() async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      final created = await _repo.createCoachInvite();
      await _loadAll();
      unawaited(
        Clipboard.setData(ClipboardData(text: created.code)).catchError((_) {}),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${S.adminCodeCopied}: ${created.code}')),
        );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _reviewActivity(
    AdminFlaggedActivity act,
    String action, {
    String? newJenis,
  }) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await _repo.reviewActivity(
        aktivitasId: act.id,
        action: action,
        newJenis: newJenis,
      );
      await _loadAll();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Widget _buildOverviewTab(BuildContext context, PacerScheme scheme) {
    final tiles = [
      (S.adminUsersTab, '${_stats.totalUsers}', Icons.people_outline),
      ('Coach', '${_stats.coachCount}', Icons.school_outlined),
      ('Admin', '${_stats.adminCount}', Icons.admin_panel_settings_outlined),
      (
        S.adminFlaggedTab,
        '${_stats.flaggedActivities}',
        Icons.flag_outlined,
      ),
      (S.teams, '${_stats.totalTeams}', Icons.groups_outlined),
      ('Km', fmtKmNum(_stats.totalKm * 1000), Icons.directions_run_rounded),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in tiles)
              SizedBox(
                width: 162,
                child: PacerSurface(
                  radius: PacerRadii.lg,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(t.$3, size: 20, color: scheme.accent),
                      const SizedBox(height: 8),
                      Text(
                        t.$2,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: scheme.ink,
                        ),
                      ),
                      Text(
                        t.$1,
                        style: TextStyle(fontSize: 12, color: scheme.soft),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildUsersTab(BuildContext context, PacerScheme scheme) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PacerSurface(
            radius: PacerRadii.lg,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.adminCoachInvitesTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.ink,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _mutating ? null : _generateCoachInvite,
                      icon: const Icon(Icons.vpn_key_outlined, size: 16),
                      label: Text(S.adminGenerateCodeCta),
                    ),
                  ],
                ),
                if (_invites.isNotEmpty) const SizedBox(height: 10),
                for (final inv in _invites.take(5))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${inv.code}  (${inv.usesCount}/${inv.maxUses})',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: inv.isUsable ? scheme.ink : scheme.muted,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy',
                          icon: const Icon(Icons.copy_rounded, size: 17),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: inv.code),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(content: Text(S.adminCodeCopied)),
                                );
                            }
                          },
                        ),
                        if (inv.isUsable)
                          IconButton(
                            tooltip: 'Revoke',
                            icon: Icon(
                              Icons.block_rounded,
                              size: 17,
                              color: PacerColors.errorRed,
                            ),
                            onPressed: _mutating
                                ? null
                                : () async {
                                    await _repo.revokeCoachInvite(inv.id);
                                    await _loadAll();
                                  },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchCtrl,
            onSubmitted: (_) => _reloadUsers(),
            decoration: InputDecoration(
              hintText: S.adminSearchUsersHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _reloadUsers,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final role in <String?>[null, 'user', 'coach', 'admin'])
                ChoiceChip(
                  label: Text(role?.toUpperCase() ?? 'ALL'),
                  selected: _roleFilter == role,
                  onSelected: (_) {
                    setState(() => _roleFilter = role);
                    _reloadUsers();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final u in _users)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PacerSurface(
                radius: PacerRadii.md,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.nama,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: scheme.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${u.totalRuns} runs • ${fmtKmNum(u.totalKm * 1000)} km',
                            style: TextStyle(fontSize: 12, color: scheme.soft),
                          ),
                        ],
                      ),
                    ),
                    ActionChip(
                      label: Text(u.peran.toUpperCase()),
                      onPressed: _mutating ? null : () => _changeRole(u),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlaggedTab(BuildContext context, PacerScheme scheme) {
    if (_flagged.isEmpty) {
      return Center(
        child: Text(
          S.adminNoFlaggedRuns,
          style: TextStyle(color: scheme.soft),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _flagged.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final act = _flagged[i];
        return PacerSurface(
          radius: PacerRadii.lg,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${act.userNama} · ${S.sportName(act.jenis)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: scheme.ink,
                      ),
                    ),
                  ),
                  Text(
                    act.validationStatus,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PacerColors.streakAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${fmtKm(act.jarakM)} • ${fmtDurasi(act.durasiS)}'
                '${act.cadenceSpm != null ? ' • ${act.cadenceSpm} spm' : ''}',
                style: TextStyle(fontSize: 12.5, color: scheme.soft),
              ),
              if (act.validationReasons.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  act.validationReasons.join(', '),
                  style: TextStyle(fontSize: 11, color: scheme.muted),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _mutating
                        ? null
                        : () => _reviewActivity(act, 'verify'),
                    child: Text(S.adminVerifyCta),
                  ),
                  if (act.suggestedSport != null)
                    FilledButton(
                      onPressed: _mutating
                          ? null
                          : () => _reviewActivity(
                              act,
                              'reclassify',
                              newJenis: act.suggestedSport,
                            ),
                      child: Text(
                        '${S.adminReclassifyCta}: ${S.sportName(act.suggestedSport!)}',
                      ),
                    ),
                  TextButton(
                    onPressed: _mutating
                        ? null
                        : () => _reviewActivity(act, 'exclude'),
                    child: Text(
                      S.adminExcludeCta,
                      style: const TextStyle(color: PacerColors.errorRed),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditTab(BuildContext context, PacerScheme scheme) {
    if (_auditLogs.isEmpty) {
      return Center(
        child: Text(
          S.adminNoAuditEntries,
          style: TextStyle(color: scheme.soft),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final log = _auditLogs[i];
        return PacerSurface(
          radius: PacerRadii.md,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${log.action} · ${log.actorNama}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: scheme.ink,
                ),
              ),
              Text(
                '${log.targetType}: ${log.targetId ?? '–'} · ${fmtDate(log.createdAt)}',
                style: TextStyle(fontSize: 11.5, color: scheme.soft),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = PacerScheme.of(context);
    final navItems = [
      (S.adminOverviewTab, Icons.dashboard_outlined),
      (S.adminUsersTab, Icons.manage_accounts_outlined),
      (S.adminFlaggedTab, Icons.verified_user_outlined),
      (S.adminAuditTab, Icons.receipt_long_outlined),
    ];

    Widget bodyContent() {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _loadAll, child: Text(S.adminRetryCta)),
              ],
            ),
          ),
        );
      }
      return switch (_tabIndex) {
        0 => _buildOverviewTab(context, scheme),
        1 => _buildUsersTab(context, scheme),
        2 => _buildFlaggedTab(context, scheme),
        _ => _buildAuditTab(context, scheme),
      };
    }

    return Scaffold(
      backgroundColor: scheme.scaffold,
      appBar: AppBar(
        title: Text(S.adminConsole),
        backgroundColor: scheme.scaffold,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadAll,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 840) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _tabIndex,
                  onDestinationSelected: (i) => setState(() => _tabIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final item in navItems)
                      NavigationRailDestination(
                        icon: Icon(item.$2),
                        label: Text(item.$1),
                      ),
                  ],
                ),
                Expanded(child: bodyContent()),
              ],
            );
          }
          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < navItems.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(navItems[i].$2, size: 16),
                          label: Text(navItems[i].$1),
                          selected: _tabIndex == i,
                          onSelected: (_) => setState(() => _tabIndex = i),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: bodyContent()),
            ],
          );
        },
      ),
    );
  }
}
