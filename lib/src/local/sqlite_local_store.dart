import 'dart:convert';

import 'package:sqflite/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/chat/chat_model.dart';
import 'package:pacer/src/leaderboard/leaderboard_model.dart';
import 'package:pacer/src/local/local_helpers.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/teams/team_model.dart';

/// Relational SQLite implementation of [LocalStore] for Android, Linux,
/// macOS, Windows, and headless unit/widget tests.
class SqliteLocalStore implements LocalStore {
  final Database _db;

  SqliteLocalStore._(this._db);

  static const int schemaVersion = 1;

  /// Opens or creates the offline SQLite database at [path] (or
  /// `inMemoryDatabasePath` in tests) using the supplied [factory].
  static Future<SqliteLocalStore> open({
    required DatabaseFactory factory,
    required String path,
  }) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          if (path != inMemoryDatabasePath) {
            await db.rawQuery('PRAGMA journal_mode = WAL');
          }
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async => _createSchema(db),
      ),
    );
    return SqliteLocalStore._(db);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        nama TEXT,
        peran TEXT NOT NULL DEFAULT 'user',
        lahir TEXT,
        jenis_kelamin TEXT,
        tinggi_cm REAL,
        berat_kg REAL,
        region TEXT,
        language TEXT,
        email TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        jenis TEXT NOT NULL,
        mulai_at TEXT NOT NULL,
        selesai_at TEXT,
        durasi_s INTEGER,
        jarak_m REAL,
        status TEXT NOT NULL,
        sync_state TEXT NOT NULL,
        statistik_applied INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_activities_user ON activities (user_id, status, mulai_at DESC)',
    );
    await db.execute('''
      CREATE TABLE route_points (
        aktivitas_id TEXT NOT NULL,
        urutan INTEGER NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        elevasi_m REAL,
        kecepatan_ms REAL,
        direkam_at TEXT,
        PRIMARY KEY (aktivitas_id, urutan),
        FOREIGN KEY (aktivitas_id) REFERENCES activities (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE statistik (
        user_id TEXT NOT NULL,
        periode TEXT NOT NULL,
        total_jarak_m REAL NOT NULL DEFAULT 0,
        total_waktu_s INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, periode)
      )
    ''');
    await db.execute('''
      CREATE TABLE streaks (
        user_id TEXT PRIMARY KEY,
        streak_berjalan INTEGER NOT NULL DEFAULT 0,
        terakhir_olahraga_tgl TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE teams (
        user_id TEXT NOT NULL,
        id TEXT NOT NULL,
        nama TEXT NOT NULL,
        target_nilai REAL,
        dibuat_oleh TEXT,
        is_private INTEGER NOT NULL DEFAULT 1,
        invite_code TEXT,
        created_at TEXT,
        is_mine INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, id)
      )
    ''');
    await db.execute('''
      CREATE TABLE team_rosters (
        owner_user_id TEXT NOT NULL,
        team_id TEXT NOT NULL,
        member_user_id TEXT NOT NULL,
        pos INTEGER NOT NULL,
        nama TEXT NOT NULL,
        peran TEXT NOT NULL,
        app_peran TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (owner_user_id, team_id, member_user_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE challenges (
        user_id TEXT NOT NULL,
        id TEXT NOT NULL,
        dibuat_oleh TEXT,
        jenis TEXT NOT NULL,
        target_nilai REAL NOT NULL,
        target_satuan TEXT NOT NULL,
        waktu_mulai TEXT,
        waktu_selesai TEXT,
        diumumkan INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, id)
      )
    ''');
    await db.execute('''
      CREATE TABLE challenge_participations (
        user_id TEXT NOT NULL,
        challenge_id TEXT NOT NULL,
        id TEXT NOT NULL,
        progress_nilai REAL NOT NULL DEFAULT 0,
        berhasil INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        sync_state TEXT NOT NULL DEFAULT 'synced',
        PRIMARY KEY (user_id, challenge_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE leaderboards (
        user_id TEXT NOT NULL,
        id TEXT NOT NULL,
        nama TEXT NOT NULL,
        periode TEXT NOT NULL,
        kriteria TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, id)
      )
    ''');
    await db.execute('''
      CREATE TABLE leaderboard_entries (
        owner_user_id TEXT NOT NULL,
        leaderboard_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        nama TEXT NOT NULL,
        nilai REAL NOT NULL,
        posisi INTEGER,
        updated_at TEXT,
        PRIMARY KEY (owner_user_id, leaderboard_id, user_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE leaderboard_scopes (
        user_id TEXT NOT NULL,
        scope TEXT NOT NULL,
        member_ids_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, scope)
      )
    ''');
    await db.execute('''
      CREATE TABLE chat_messages (
        owner_user_id TEXT NOT NULL,
        id TEXT NOT NULL,
        team_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        user_nama TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_state TEXT NOT NULL DEFAULT 'synced',
        PRIMARY KEY (owner_user_id, id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_chat_team ON chat_messages (owner_user_id, team_id, created_at ASC)',
    );
    await db.execute('''
      CREATE TABLE coach_rows_cache (
        user_id TEXT NOT NULL,
        team_id TEXT NOT NULL,
        challenge_id TEXT NOT NULL,
        rows_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, team_id, challenge_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_meta (
        cache_key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        op_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        next_retry_at TEXT,
        last_error TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_outbox_pending ON sync_outbox (user_id, status, next_retry_at, id)',
    );
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  @override
  Future<void> close() => _db.close();

  @override
  Future<String?> getLastUserId() async {
    final rows = await _db.query(
      'sync_meta',
      where: 'cache_key = ?',
      whereArgs: ['last_user_id'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final val = rows.first['value'] as String?;
    return (val == null || val.isEmpty) ? null : val;
  }

  @override
  Future<void> setLastUserId(String? userId) async {
    if (userId == null) {
      await _db.delete(
        'sync_meta',
        where: 'cache_key = ?',
        whereArgs: ['last_user_id'],
      );
      return;
    }
    await _db.insert('sync_meta', {
      'cache_key': 'last_user_id',
      'value': userId,
      'updated_at': _nowIso(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> setSyncTimestamp(String key, DateTime at) async {
    await _db.insert('sync_meta', {
      'cache_key': 'ts_$key',
      'value': at.toUtc().toIso8601String(),
      'updated_at': _nowIso(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<DateTime?> getSyncTimestamp(String key) async {
    final rows = await _db.query(
      'sync_meta',
      where: 'cache_key = ?',
      whereArgs: ['ts_$key'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['value'] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  @override
  Future<UserProfile?> getProfile(String userId) async {
    final rows = await _db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<String?> getLanguage(String userId) async {
    final rows = await _db.query(
      'profiles',
      columns: ['language'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['language'] as String?;
  }

  @override
  Future<String?> getEmail(String userId) async {
    final rows = await _db.query(
      'profiles',
      columns: ['email'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['email'] as String?;
  }

  @override
  Future<void> upsertProfile(
    UserProfile profile, {
    String? language,
    String? email,
  }) async {
    final existing = await _db.query(
      'profiles',
      columns: ['language', 'email'],
      where: 'id = ?',
      whereArgs: [profile.id],
      limit: 1,
    );
    final resolvedLang =
        language ?? (existing.isNotEmpty ? existing.first['language'] as String? : null);
    final resolvedEmail =
        email ?? (existing.isNotEmpty ? existing.first['email'] as String? : null);
    await _db.insert('profiles', {
      ...profile.toJson(),
      'language': resolvedLang,
      'email': resolvedEmail,
      'updated_at': _nowIso(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> queueProfileUpdate(
    String userId,
    Map<String, dynamic> patch,
  ) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'profiles',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      final existing = rows.isEmpty
          ? null
          : UserProfile.fromJson(Map<String, dynamic>.from(rows.first));
      final updated = applyProfilePatch(existing, userId, patch);
      final existingLang = rows.isEmpty
          ? null
          : rows.first['language'] as String?;
      final existingEmail = rows.isEmpty ? null : rows.first['email'] as String?;

      await txn.insert('profiles', {
        ...updated.toJson(),
        'language': existingLang,
        'email': existingEmail,
        'updated_at': _nowIso(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final outboxRows = await txn.query(
        'sync_outbox',
        where: 'user_id = ? AND op_type = ? AND status = ?',
        whereArgs: [userId, OutboxOp.updateProfile, 'pending'],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (outboxRows.isNotEmpty) {
        final prev = outboxRows.first;
        final prevMap = Map<String, dynamic>.from(
          jsonDecode(prev['payload_json'] as String) as Map,
        );
        await txn.update(
          'sync_outbox',
          {
            'payload_json': jsonEncode({...prevMap, ...patch}),
            'attempts': 0,
            'next_retry_at': null,
            'last_error': null,
          },
          where: 'id = ?',
          whereArgs: [prev['id']],
        );
      } else {
        await txn.insert('sync_outbox', {
          'user_id': userId,
          'op_type': OutboxOp.updateProfile,
          'entity_id': userId,
          'payload_json': jsonEncode(patch),
          'status': 'pending',
          'attempts': 0,
          'created_at': _nowIso(),
        });
      }
    });
  }

  @override
  Future<void> queueLanguageUpdate(String userId, String langCode) async {
    await _db.transaction((txn) async {
      final existing = await txn.query(
        'profiles',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('profiles', {
          ...UserProfile(id: userId).toJson(),
          'language': langCode,
          'updated_at': _nowIso(),
        });
      } else {
        await txn.update(
          'profiles',
          {'language': langCode, 'updated_at': _nowIso()},
          where: 'id = ?',
          whereArgs: [userId],
        );
      }
      await txn.delete(
        'sync_outbox',
        where: 'user_id = ? AND op_type = ? AND status = ?',
        whereArgs: [userId, OutboxOp.updateLanguage, 'pending'],
      );
      await txn.insert('sync_outbox', {
        'user_id': userId,
        'op_type': OutboxOp.updateLanguage,
        'entity_id': userId,
        'payload_json': jsonEncode({'language': langCode}),
        'status': 'pending',
        'attempts': 0,
        'created_at': _nowIso(),
      });
    });
  }

  @override
  Future<void> saveDraftStart({
    required String id,
    required String userId,
    required String jenis,
    required DateTime mulaiAt,
  }) async {
    await _db.insert('activities', {
      'id': id,
      'user_id': userId,
      'jenis': jenis,
      'mulai_at': mulaiAt.toUtc().toIso8601String(),
      'selesai_at': null,
      'durasi_s': 0,
      'jarak_m': 0.0,
      'status': 'draft',
      'sync_state': 'pending',
      'statistik_applied': 0,
      'updated_at': _nowIso(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> checkpointDraft({
    required String id,
    required int elapsedS,
    required double distanceM,
    required List<RutePoint> newPoints,
  }) async {
    await _db.transaction((txn) async {
      final count = await txn.update(
        'activities',
        {
          'durasi_s': elapsedS,
          'jarak_m': distanceM,
          'updated_at': _nowIso(),
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, 'draft'],
      );
      if (count == 0 || newPoints.isEmpty) return;
      final batch = txn.batch();
      for (final point in newPoints) {
        batch.insert('route_points', {
          ...point.toJson(),
          'aktivitas_id': id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<ActiveDraftRun?> loadActiveDraft(String userId) async {
    final rows = await _db.query(
      'activities',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'draft'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final id = row['id'] as String;
    final pts = await getRoutePoints(id);
    return ActiveDraftRun(
      id: id,
      userId: userId,
      jenis: row['jenis'] as String,
      mulaiAt: DateTime.parse(row['mulai_at'] as String),
      elapsedS: (row['durasi_s'] as num?)?.toInt() ?? 0,
      distanceM: jsonToDouble(row['jarak_m']) ?? 0,
      points: pts,
    );
  }

  @override
  Future<void> discardDraft(String id) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'sync_outbox',
        where: 'op_type = ? AND entity_id = ?',
        whereArgs: [OutboxOp.syncActivity, id],
      );
      await txn.delete('route_points', where: 'aktivitas_id = ?', whereArgs: [id]);
      await txn.delete('activities', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<Activity> finalizeRunAtomic({
    required String id,
    required String userId,
    required String jenis,
    required DateTime mulaiAt,
    required DateTime selesaiAt,
    required int durasiS,
    required double jarakM,
    required List<RutePoint> allPoints,
  }) async {
    final activity = Activity(
      id: id,
      userId: userId,
      jenis: jenis,
      mulaiAt: mulaiAt.toUtc(),
      selesaiAt: selesaiAt.toUtc(),
      durasiS: durasiS,
      jarakM: jarakM,
    );
    await _db.transaction((txn) async {
      await txn.insert('activities', {
        ...activity.toJson(),
        'status': 'finished',
        'sync_state': 'pending',
        'statistik_applied': 0,
        'updated_at': _nowIso(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.delete('route_points', where: 'aktivitas_id = ?', whereArgs: [id]);
      if (allPoints.isNotEmpty) {
        final batch = txn.batch();
        for (final point in allPoints) {
          batch.insert('route_points', {
            ...point.toJson(),
            'aktivitas_id': id,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }

      await txn.delete(
        'sync_outbox',
        where: 'op_type = ? AND entity_id = ?',
        whereArgs: [OutboxOp.syncActivity, id],
      );
      await txn.insert('sync_outbox', {
        'user_id': userId,
        'op_type': OutboxOp.syncActivity,
        'entity_id': id,
        'payload_json': jsonEncode(activity.toJson()),
        'status': 'pending',
        'attempts': 0,
        'created_at': _nowIso(),
      });
    });
    return activity;
  }

  @override
  Future<List<LocalActivity>> listActivities(
    String userId, {
    int limit = 50,
  }) async {
    final rows = await _db.query(
      'activities',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'finished'],
      orderBy: 'mulai_at DESC',
      limit: limit,
    );
    return rows.map(_localActivityFromRow).toList();
  }

  @override
  Future<void> mergeRemoteActivities(
    String userId,
    List<Activity> remote,
  ) async {
    if (remote.isEmpty) return;
    await _db.transaction((txn) async {
      final existingRows = await txn.query(
        'activities',
        columns: ['id', 'sync_state', 'status'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final protectedIds = <String>{
        for (final r in existingRows)
          if (r['sync_state'] != 'synced' || r['status'] == 'draft')
            r['id'] as String,
      };
      final batch = txn.batch();
      final now = _nowIso();
      for (final a in remote) {
        if (protectedIds.contains(a.id)) continue;
        batch.insert('activities', {
          ...a.toJson(),
          'status': 'finished',
          'sync_state': 'synced',
          'statistik_applied': 1,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> deleteActivityLocal(String id) => discardDraft(id);

  @override
  Future<List<RutePoint>> getRoutePoints(String aktivitasId) async {
    final rows = await _db.query(
      'route_points',
      where: 'aktivitas_id = ?',
      whereArgs: [aktivitasId],
      orderBy: 'urutan ASC',
    );
    return [
      for (final row in rows) RutePoint.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  @override
  Future<void> saveRoutePoints(
    String aktivitasId,
    List<RutePoint> points,
  ) async {
    await _db.transaction((txn) async {
      final exists = await txn.query(
        'activities',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [aktivitasId],
        limit: 1,
      );
      if (exists.isEmpty) return;
      await txn.delete(
        'route_points',
        where: 'aktivitas_id = ?',
        whereArgs: [aktivitasId],
      );
      if (points.isEmpty) return;
      final batch = txn.batch();
      for (final p in points) {
        batch.insert('route_points', {
          ...p.toJson(),
          'aktivitas_id': aktivitasId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> saveStatistikBaseline(
    String userId,
    String periode,
    double jarakM,
    int waktuS,
  ) async {
    await _db.insert('statistik', {
      'user_id': userId,
      'periode': periode,
      'total_jarak_m': jarakM,
      'total_waktu_s': waktuS,
      'updated_at': _nowIso(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<({double jarakM, int waktuS})?> getStatistikEffective(
    String userId,
    String periode,
  ) async {
    final statRows = await _db.query(
      'statistik',
      where: 'user_id = ? AND periode = ?',
      whereArgs: [userId, periode],
      limit: 1,
    );
    final baseline = statRows.isEmpty
        ? null
        : (
            jarakM: jsonToDouble(statRows.first['total_jarak_m']) ?? 0,
            waktuS: (statRows.first['total_waktu_s'] as num?)?.toInt() ?? 0,
          );
    final actRows = await _db.query(
      'activities',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'finished'],
    );
    return computeEffectiveStatistik(
      baseline: baseline,
      activities: actRows.map(_localActivityFromRow).toList(),
      periode: periode,
    );
  }

  @override
  Future<void> saveStreakBaseline(
    String userId,
    int berjalan,
    DateTime? terakhir,
  ) async {
    await _db.insert('streaks', {
      'user_id': userId,
      'streak_berjalan': berjalan,
      'terakhir_olahraga_tgl': terakhir == null ? null : _isoDate(terakhir),
      'updated_at': _nowIso(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<({int berjalan, DateTime? terakhir})?> getStreakEffective(
    String userId,
  ) async {
    final streakRows = await _db.query(
      'streaks',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    final baseline = streakRows.isEmpty
        ? null
        : (
            berjalan:
                (streakRows.first['streak_berjalan'] as num?)?.toInt() ?? 0,
            terakhir: streakRows.first['terakhir_olahraga_tgl'] == null
                ? null
                : DateTime.parse(
                    streakRows.first['terakhir_olahraga_tgl'] as String,
                  ),
          );
    final actRows = await _db.query(
      'activities',
      where: 'user_id = ? AND status = ? AND sync_state != ?',
      whereArgs: [userId, 'finished', 'synced'],
    );
    return computeEffectiveStreak(
      baseline: baseline,
      activities: actRows.map(_localActivityFromRow).toList(),
    );
  }

  @override
  Future<void> saveTeams(
    String userId,
    List<Team> teams, {
    required bool isMine,
  }) async {
    await _db.transaction((txn) async {
      final now = _nowIso();
      if (isMine) {
        await txn.update(
          'teams',
          {'is_mine': 0},
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }
      final existing = await txn.query(
        'teams',
        columns: ['id', 'is_mine'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final prevMine = {
        for (final r in existing)
          r['id'] as String: (r['is_mine'] as int? ?? 0) == 1,
      };
      final batch = txn.batch();
      for (final t in teams) {
        batch.insert('teams', {
          'user_id': userId,
          'id': t.id,
          'nama': t.nama,
          'target_nilai': t.targetNilai,
          'dibuat_oleh': t.dibuatOleh,
          'is_private': t.isPrivate ? 1 : 0,
          'invite_code': t.inviteCode,
          'created_at': t.createdAt?.toUtc().toIso8601String(),
          'is_mine': (isMine || (prevMine[t.id] ?? false)) ? 1 : 0,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<Team>> getTeams(String userId, {bool mineOnly = false}) async {
    final rows = await _db.query(
      'teams',
      where: mineOnly ? 'user_id = ? AND is_mine = 1' : 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return [for (final r in rows) _teamFromRow(r)];
  }

  @override
  Future<Team?> getTeam(String userId, String teamId) async {
    final rows = await _db.query(
      'teams',
      where: 'user_id = ? AND id = ?',
      whereArgs: [userId, teamId],
      limit: 1,
    );
    return rows.isEmpty ? null : _teamFromRow(rows.first);
  }

  @override
  Future<void> saveTeamRoster(
    String userId,
    String teamId,
    List<({String userId, String nama, String peran, String appPeran})> roster,
  ) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'team_rosters',
        where: 'owner_user_id = ? AND team_id = ?',
        whereArgs: [userId, teamId],
      );
      if (roster.isEmpty) return;
      final now = _nowIso();
      final batch = txn.batch();
      for (var i = 0; i < roster.length; i++) {
        final r = roster[i];
        batch.insert('team_rosters', {
          'owner_user_id': userId,
          'team_id': teamId,
          'member_user_id': r.userId,
          'pos': i,
          'nama': r.nama,
          'peran': r.peran,
          'app_peran': r.appPeran,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<({String userId, String nama, String peran, String appPeran})>>
  getTeamRoster(String userId, String teamId) async {
    final rows = await _db.query(
      'team_rosters',
      where: 'owner_user_id = ? AND team_id = ?',
      whereArgs: [userId, teamId],
      orderBy: 'pos ASC',
    );
    return [
      for (final r in rows)
        (
          userId: r['member_user_id'] as String,
          nama: r['nama'] as String,
          peran: r['peran'] as String,
          appPeran: r['app_peran'] as String,
        ),
    ];
  }

  @override
  Future<void> saveCoachRows(
    String userId,
    String teamId,
    String? challengeId,
    List<LocalCoachRow> rows,
  ) async {
    await _db.insert('coach_rows_cache', {
      'user_id': userId,
      'team_id': teamId,
      'challenge_id': challengeId ?? '',
      'rows_json': jsonEncode([for (final r in rows) r.toJson()]),
      'updated_at': _nowIso(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<LocalCoachRow>?> getCoachRows(
    String userId,
    String teamId,
    String? challengeId,
  ) async {
    final rows = await _db.query(
      'coach_rows_cache',
      where: 'user_id = ? AND team_id = ? AND challenge_id = ?',
      whereArgs: [userId, teamId, challengeId ?? ''],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final list = jsonDecode(rows.first['rows_json'] as String) as List;
    return [
      for (final item in list)
        LocalCoachRow.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  @override
  Future<void> saveChallenges(String userId, List<Challenge> challenges) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'challenges',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      if (challenges.isEmpty) return;
      final now = _nowIso();
      final batch = txn.batch();
      for (final c in challenges) {
        batch.insert('challenges', {
          'user_id': userId,
          'id': c.id,
          'dibuat_oleh': c.dibuatOleh,
          'jenis': c.jenis,
          'target_nilai': c.targetNilai,
          'target_satuan': c.targetSatuan,
          'waktu_mulai': c.waktuMulai?.toUtc().toIso8601String(),
          'waktu_selesai': c.waktuSelesai?.toUtc().toIso8601String(),
          'diumumkan': c.diumumkan ? 1 : 0,
          'created_at': c.createdAt?.toUtc().toIso8601String(),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<Challenge>> getChallenges(String userId) async {
    final rows = await _db.query(
      'challenges',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return [
      for (final r in rows)
        Challenge.fromJson({
          ...r,
          'diumumkan': (r['diumumkan'] as int? ?? 0) == 1,
        }),
    ];
  }

  @override
  Future<void> saveParticipations(
    String userId,
    List<PartisipasiChallenge> list,
  ) async {
    await _db.transaction((txn) async {
      final pendingRows = await txn.query(
        'sync_outbox',
        where: 'user_id = ? AND op_type IN (?, ?) AND status != ?',
        whereArgs: [
          userId,
          OutboxOp.joinChallenge,
          OutboxOp.leaveChallenge,
          'synced',
        ],
      );
      final pendingLeaveIds = <String>{
        for (final p in pendingRows)
          if (p['op_type'] == OutboxOp.leaveChallenge)
            p['entity_id'] as String,
      };
      final pendingJoinRows = {
        for (final p in pendingRows)
          if (p['op_type'] == OutboxOp.joinChallenge)
            p['entity_id'] as String: p,
      };

      await txn.delete(
        'challenge_participations',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      final batch = txn.batch();
      final inserted = <String>{};
      for (final item in list) {
        if (pendingLeaveIds.contains(item.challengeId)) continue;
        inserted.add(item.challengeId);
        batch.insert('challenge_participations', {
          'user_id': userId,
          'challenge_id': item.challengeId,
          'id': item.id,
          'progress_nilai': item.progressNilai,
          'berhasil': item.berhasil ? 1 : 0,
          'created_at': item.createdAt?.toUtc().toIso8601String(),
          'sync_state': 'synced',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final entry in pendingJoinRows.entries) {
        if (inserted.contains(entry.key)) continue;
        final payload = jsonDecode(entry.value['payload_json'] as String) as Map;
        batch.insert('challenge_participations', {
          'user_id': userId,
          'challenge_id': entry.key,
          'id': payload['id'] as String? ?? entry.key,
          'progress_nilai': 0.0,
          'berhasil': 0,
          'created_at': entry.value['created_at'] as String?,
          'sync_state': 'pending',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<PartisipasiChallenge>> getParticipations(String userId) async {
    final rows = await _db.query(
      'challenge_participations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return [
      for (final r in rows)
        PartisipasiChallenge.fromJson({
          ...r,
          'berhasil': (r['berhasil'] as int? ?? 0) == 1,
        }),
    ];
  }

  @override
  Future<PartisipasiChallenge> queueJoinChallenge(
    String userId,
    String challengeId,
  ) async {
    final p = PartisipasiChallenge(
      id: const Uuid().v4(),
      challengeId: challengeId,
      userId: userId,
      createdAt: DateTime.now().toUtc(),
    );
    await _db.transaction((txn) async {
      await txn.insert('challenge_participations', {
        'user_id': userId,
        'challenge_id': challengeId,
        'id': p.id,
        'progress_nilai': 0.0,
        'berhasil': 0,
        'created_at': p.createdAt!.toIso8601String(),
        'sync_state': 'pending',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.delete(
        'sync_outbox',
        where: 'user_id = ? AND entity_id = ? AND op_type IN (?, ?) AND status = ?',
        whereArgs: [
          userId,
          challengeId,
          OutboxOp.joinChallenge,
          OutboxOp.leaveChallenge,
          'pending',
        ],
      );
      await txn.insert('sync_outbox', {
        'user_id': userId,
        'op_type': OutboxOp.joinChallenge,
        'entity_id': challengeId,
        'payload_json': jsonEncode({'id': p.id, 'challenge_id': challengeId}),
        'status': 'pending',
        'attempts': 0,
        'created_at': _nowIso(),
      });
    });
    return p;
  }

  @override
  Future<void> queueLeaveChallenge(String userId, String challengeId) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'challenge_participations',
        where: 'user_id = ? AND challenge_id = ?',
        whereArgs: [userId, challengeId],
      );
      final pendingJoins = await txn.query(
        'sync_outbox',
        columns: ['id'],
        where: 'user_id = ? AND entity_id = ? AND op_type = ? AND status = ?',
        whereArgs: [userId, challengeId, OutboxOp.joinChallenge, 'pending'],
      );
      await txn.delete(
        'sync_outbox',
        where: 'user_id = ? AND entity_id = ? AND op_type IN (?, ?) AND status = ?',
        whereArgs: [
          userId,
          challengeId,
          OutboxOp.joinChallenge,
          OutboxOp.leaveChallenge,
          'pending',
        ],
      );
      if (pendingJoins.isEmpty) {
        await txn.insert('sync_outbox', {
          'user_id': userId,
          'op_type': OutboxOp.leaveChallenge,
          'entity_id': challengeId,
          'payload_json': jsonEncode({'challenge_id': challengeId}),
          'status': 'pending',
          'attempts': 0,
          'created_at': _nowIso(),
        });
      }
    });
  }

  @override
  Future<void> saveLeaderboards(
    String userId,
    List<Leaderboard> boards,
  ) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'leaderboards',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      if (boards.isEmpty) return;
      final now = _nowIso();
      final batch = txn.batch();
      for (final b in boards) {
        batch.insert('leaderboards', {
          'user_id': userId,
          'id': b.id,
          'nama': b.nama,
          'periode': b.periode,
          'kriteria': b.kriteria,
          'created_at': b.createdAt?.toUtc().toIso8601String(),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<Leaderboard>> getLeaderboards(String userId) async {
    final rows = await _db.query(
      'leaderboards',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return [
      for (final r in rows) Leaderboard.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  @override
  Future<void> saveLeaderboardEntries(
    String userId,
    String leaderboardId,
    List<({Peringkat entry, String nama})> entries,
  ) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'leaderboard_entries',
        where: 'owner_user_id = ? AND leaderboard_id = ?',
        whereArgs: [userId, leaderboardId],
      );
      if (entries.isEmpty) return;
      final batch = txn.batch();
      for (final item in entries) {
        batch.insert('leaderboard_entries', {
          'owner_user_id': userId,
          'leaderboard_id': leaderboardId,
          'user_id': item.entry.userId,
          'nama': item.nama,
          'nilai': item.entry.nilai,
          'posisi': item.entry.posisi,
          'updated_at': item.entry.updatedAt?.toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<({Peringkat entry, String nama})>> getLeaderboardEntries(
    String userId,
    String leaderboardId,
  ) async {
    final rows = await _db.query(
      'leaderboard_entries',
      where: 'owner_user_id = ? AND leaderboard_id = ?',
      whereArgs: [userId, leaderboardId],
      orderBy: 'nilai DESC',
    );
    return [
      for (final r in rows)
        (
          entry: Peringkat(
            id: '${r['leaderboard_id']}_${r['user_id']}',
            leaderboardId: r['leaderboard_id'] as String,
            userId: r['user_id'] as String,
            nilai: jsonToDouble(r['nilai']) ?? 0,
            posisi: (r['posisi'] as num?)?.toInt(),
            updatedAt: r['updated_at'] == null
                ? null
                : DateTime.parse(r['updated_at'] as String),
          ),
          nama: r['nama'] as String,
        ),
    ];
  }

  @override
  Future<void> saveLeaderboardScope(
    String userId,
    String scope,
    Set<String> userIds,
  ) async {
    await _db.insert('leaderboard_scopes', {
      'user_id': userId,
      'scope': scope,
      'member_ids_json': jsonEncode(userIds.toList()),
      'updated_at': _nowIso(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Set<String>?> getLeaderboardScope(String userId, String scope) async {
    final rows = await _db.query(
      'leaderboard_scopes',
      where: 'user_id = ? AND scope = ?',
      whereArgs: [userId, scope],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final list = jsonDecode(rows.first['member_ids_json'] as String) as List;
    return {for (final x in list) '$x'};
  }

  @override
  Future<void> mergeChatMessages(
    String userId,
    String teamId,
    List<ChatMessage> remote,
  ) async {
    if (remote.isEmpty) return;
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final m in remote) {
        batch.insert('chat_messages', {
          'owner_user_id': userId,
          'id': m.id,
          'team_id': m.teamId,
          'user_id': m.userId,
          'user_nama': m.userNama,
          'body': m.body,
          'created_at': (m.createdAt ?? DateTime.now()).toUtc().toIso8601String(),
          'sync_state': 'synced',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<LocalChatMessage>> getChatMessages(
    String userId,
    String teamId, {
    int limit = 100,
  }) async {
    final rows = await _db.query(
      'chat_messages',
      where: 'owner_user_id = ? AND team_id = ?',
      whereArgs: [userId, teamId],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return [
      for (final r in rows)
        LocalChatMessage(
          message: ChatMessage(
            id: r['id'] as String,
            teamId: r['team_id'] as String,
            userId: r['user_id'] as String,
            userNama: r['user_nama'] as String? ?? '',
            body: r['body'] as String,
            createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
          ),
          syncState: parseSyncState(r['sync_state'] as String?),
        ),
    ];
  }

  @override
  Future<LocalChatMessage> queueChatMessage({
    required String id,
    required String teamId,
    required String userId,
    required String userNama,
    required String body,
    DateTime? createdAt,
  }) async {
    final ts = (createdAt ?? DateTime.now()).toUtc();
    final trimmed = body.trim();
    await _db.transaction((txn) async {
      await txn.insert('chat_messages', {
        'owner_user_id': userId,
        'id': id,
        'team_id': teamId,
        'user_id': userId,
        'user_nama': userNama,
        'body': trimmed,
        'created_at': ts.toIso8601String(),
        'sync_state': 'pending',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('sync_outbox', {
        'user_id': userId,
        'op_type': OutboxOp.sendChat,
        'entity_id': id,
        'payload_json': jsonEncode({'id': id, 'team_id': teamId, 'body': trimmed}),
        'status': 'pending',
        'attempts': 0,
        'created_at': _nowIso(),
      });
    });
    return LocalChatMessage(
      message: ChatMessage(
        id: id,
        teamId: teamId,
        userId: userId,
        userNama: userNama,
        body: trimmed,
        createdAt: ts,
      ),
      syncState: SyncState.pending,
    );
  }

  @override
  Future<void> markChatMessageSynced(
    String userId,
    String tempId,
    ChatMessage serverMsg,
  ) async {
    await _db.transaction((txn) async {
      final oldRows = await txn.query(
        'chat_messages',
        columns: ['user_nama'],
        where: 'owner_user_id = ? AND id = ?',
        whereArgs: [userId, tempId],
        limit: 1,
      );
      final oldNama = oldRows.isEmpty
          ? ''
          : (oldRows.first['user_nama'] as String? ?? '');
      await txn.delete(
        'chat_messages',
        where: 'owner_user_id = ? AND id = ?',
        whereArgs: [userId, tempId],
      );
      await txn.insert('chat_messages', {
        'owner_user_id': userId,
        'id': serverMsg.id,
        'team_id': serverMsg.teamId,
        'user_id': serverMsg.userId,
        'user_nama':
            serverMsg.userNama.isNotEmpty ? serverMsg.userNama : oldNama,
        'body': serverMsg.body,
        'created_at':
            (serverMsg.createdAt ?? DateTime.now()).toUtc().toIso8601String(),
        'sync_state': 'synced',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<List<OutboxItem>> getDueOutboxItems(
    String userId,
    DateTime now,
  ) async {
    final nowIso = now.toUtc().toIso8601String();
    final rows = await _db.query(
      'sync_outbox',
      where:
          'user_id = ? AND status = ? AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [userId, 'pending', nowIso],
      orderBy: 'id ASC',
    );
    return rows.map(_outboxFromRow).toList();
  }

  @override
  Future<List<OutboxItem>> getAllOutboxItems(String userId) async {
    final rows = await _db.query(
      'sync_outbox',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id ASC',
    );
    return rows.map(_outboxFromRow).toList();
  }

  @override
  Future<int> getPendingOutboxCount(String userId) async {
    final res = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM sync_outbox WHERE user_id = ? AND status != ?',
      [userId, 'synced'],
    );
    return (res.first['cnt'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> markOutboxSynced(
    int outboxId, {
    String? syncedActivityId,
    String? periode,
    double? baselineJarakM,
    int? baselineWaktuS,
    int? baselineStreak,
    DateTime? baselineStreakLast,
    bool markStatistikAppliedOnly = false,
    double? deltaJarakM,
    int? deltaWaktuS,
  }) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'sync_outbox',
        columns: ['user_id'],
        where: 'id = ?',
        whereArgs: [outboxId],
        limit: 1,
      );
      final userId = rows.isEmpty ? null : rows.first['user_id'] as String?;

      if (syncedActivityId != null) {
        if (markStatistikAppliedOnly) {
          await txn.update(
            'activities',
            {'statistik_applied': 1, 'updated_at': _nowIso()},
            where: 'id = ?',
            whereArgs: [syncedActivityId],
          );
          if (periode != null && userId != null) {
            final curRows = await txn.query(
              'statistik',
              where: 'user_id = ? AND periode = ?',
              whereArgs: [userId, periode],
              limit: 1,
            );
            final curJ = curRows.isEmpty
                ? 0.0
                : (jsonToDouble(curRows.first['total_jarak_m']) ?? 0);
            final curW = curRows.isEmpty
                ? 0
                : ((curRows.first['total_waktu_s'] as num?)?.toInt() ?? 0);
            await txn.insert('statistik', {
              'user_id': userId,
              'periode': periode,
              'total_jarak_m': curJ + (deltaJarakM ?? 0),
              'total_waktu_s': curW + (deltaWaktuS ?? 0),
              'updated_at': _nowIso(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          return;
        }
        await txn.update(
          'activities',
          {
            'sync_state': 'synced',
            'statistik_applied': 1,
            'updated_at': _nowIso(),
          },
          where: 'id = ?',
          whereArgs: [syncedActivityId],
        );
        if (userId != null &&
            periode != null &&
            baselineJarakM != null &&
            baselineWaktuS != null) {
          await txn.insert('statistik', {
            'user_id': userId,
            'periode': periode,
            'total_jarak_m': baselineJarakM,
            'total_waktu_s': baselineWaktuS,
            'updated_at': _nowIso(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (userId != null && baselineStreak != null) {
          await txn.insert('streaks', {
            'user_id': userId,
            'streak_berjalan': baselineStreak,
            'terakhir_olahraga_tgl':
                baselineStreakLast == null ? null : _isoDate(baselineStreakLast),
            'updated_at': _nowIso(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      await txn.delete('sync_outbox', where: 'id = ?', whereArgs: [outboxId]);
    });
  }

  @override
  Future<void> markOutboxRetry(
    int outboxId, {
    required int attempts,
    required DateTime nextRetryAt,
    required String error,
  }) async {
    await _db.update(
      'sync_outbox',
      {
        'status': 'pending',
        'attempts': attempts,
        'next_retry_at': nextRetryAt.toUtc().toIso8601String(),
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [outboxId],
    );
  }

  @override
  Future<void> markOutboxFailed(
    int outboxId, {
    required String error,
    String? entityActivityId,
    String? entityUserId,
    String? entityChatId,
  }) async {
    await _db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE sync_outbox SET status = ?, attempts = attempts + 1, next_retry_at = NULL, last_error = ? WHERE id = ?',
        ['failed', error, outboxId],
      );
      if (entityActivityId != null) {
        await txn.update(
          'activities',
          {'sync_state': 'failed', 'updated_at': _nowIso()},
          where: 'id = ?',
          whereArgs: [entityActivityId],
        );
      }
      if (entityChatId != null && entityUserId != null) {
        await txn.update(
          'chat_messages',
          {'sync_state': 'failed'},
          where: 'owner_user_id = ? AND id = ?',
          whereArgs: [entityUserId, entityChatId],
        );
      }
    });
  }

  @override
  Future<void> retryFailedOutboxItems(String userId) async {
    await _db.transaction((txn) async {
      final failedActs = await txn.query(
        'sync_outbox',
        columns: ['entity_id'],
        where: 'user_id = ? AND status = ? AND op_type = ?',
        whereArgs: [userId, 'failed', OutboxOp.syncActivity],
      );
      for (final row in failedActs) {
        await txn.update(
          'activities',
          {'sync_state': 'pending', 'updated_at': _nowIso()},
          where: 'id = ?',
          whereArgs: [row['entity_id']],
        );
      }
      await txn.update(
        'sync_outbox',
        {'status': 'pending', 'attempts': 0, 'next_retry_at': null, 'last_error': null},
        where: 'user_id = ? AND status = ?',
        whereArgs: [userId, 'failed'],
      );
    });
  }

  LocalActivity _localActivityFromRow(Map<String, Object?> row) {
    final map = Map<String, dynamic>.from(row);
    return LocalActivity(
      activity: Activity.fromJson(map),
      status: parseRunStatus(row['status'] as String?),
      syncState: parseSyncState(row['sync_state'] as String?),
      statistikApplied: (row['statistik_applied'] as int? ?? 0) == 1,
      updatedAt:
          DateTime.tryParse(row['updated_at'] as String? ?? '') ?? DateTime.now().toUtc(),
    );
  }

  Team _teamFromRow(Map<String, Object?> row) {
    return Team.fromJson({
      ...row,
      'is_private': (row['is_private'] as int? ?? 1) == 1,
    });
  }

  OutboxItem _outboxFromRow(Map<String, Object?> row) {
    final decoded = jsonDecode(row['payload_json'] as String) as Map;
    return OutboxItem(
      id: (row['id'] as num).toInt(),
      userId: row['user_id'] as String,
      opType: row['op_type'] as String,
      entityId: row['entity_id'] as String,
      payload: Map<String, dynamic>.from(decoded),
      status: parseSyncState(row['status'] as String?),
      attempts: (row['attempts'] as num?)?.toInt() ?? 0,
      nextRetryAt: row['next_retry_at'] == null
          ? null
          : DateTime.tryParse(row['next_retry_at'] as String),
      lastError: row['last_error'] as String?,
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now().toUtc(),
    );
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
