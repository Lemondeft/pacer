import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/chat/chat_model.dart';
import 'package:pacer/src/leaderboard/leaderboard_model.dart';
import 'package:pacer/src/teams/team_model.dart';

/// Comprehensive in-app dummy data for demo, offline, and preview modes.
class PacerDummyData {
  PacerDummyData._();

  static final DateTime _now = DateTime.now();

  /// 12 realistic past activities covering all 4 sport types:
  /// 'lari', 'joging', 'bersepeda', 'berjalan'
  static final List<Activity> activities = [
    Activity(
      id: 'demo-act-001',
      userId: 'demo-user-me',
      jenis: 'lari',
      mulaiAt: _now.subtract(const Duration(hours: 4)),
      selesaiAt: _now.subtract(const Duration(hours: 3, minutes: 31)),
      durasiS: 1740, // 29m 00s
      jarakM: 5200, // 5.2 km
    ),
    Activity(
      id: 'demo-act-002',
      userId: 'demo-user-me',
      jenis: 'joging',
      mulaiAt: _now.subtract(const Duration(days: 1, hours: 2)),
      selesaiAt: _now.subtract(const Duration(days: 1, hours: 1, minutes: 35)),
      durasiS: 1500, // 25m 00s
      jarakM: 3800, // 3.8 km
    ),
    Activity(
      id: 'demo-act-003',
      userId: 'demo-user-me',
      jenis: 'bersepeda',
      mulaiAt: _now.subtract(const Duration(days: 2, hours: 5)),
      selesaiAt: _now.subtract(const Duration(days: 2, hours: 4, minutes: 10)),
      durasiS: 3000, // 50m 00s
      jarakM: 21500, // 21.5 km
    ),
    Activity(
      id: 'demo-act-004',
      userId: 'demo-user-me',
      jenis: 'berjalan',
      mulaiAt: _now.subtract(const Duration(days: 3, hours: 1)),
      selesaiAt: _now.subtract(const Duration(days: 3, minutes: 25)),
      durasiS: 2100, // 35m 00s
      jarakM: 3200, // 3.2 km
    ),
    Activity(
      id: 'demo-act-005',
      userId: 'demo-user-me',
      jenis: 'lari',
      mulaiAt: _now.subtract(const Duration(days: 4, hours: 3)),
      selesaiAt: _now.subtract(const Duration(days: 4, hours: 2, minutes: 5)),
      durasiS: 3300, // 55m 00s
      jarakM: 10050, // 10.05 km
    ),
    Activity(
      id: 'demo-act-006',
      userId: 'demo-user-me',
      jenis: 'joging',
      mulaiAt: _now.subtract(const Duration(days: 5, hours: 4)),
      selesaiAt: _now.subtract(const Duration(days: 5, hours: 3, minutes: 30)),
      durasiS: 1800, // 30m 00s
      jarakM: 4500, // 4.5 km
    ),
    Activity(
      id: 'demo-act-007',
      userId: 'demo-user-me',
      jenis: 'bersepeda',
      mulaiAt: _now.subtract(const Duration(days: 6, hours: 6)),
      selesaiAt: _now.subtract(const Duration(days: 6, hours: 4, minutes: 40)),
      durasiS: 4800, // 1h 20m
      jarakM: 35000, // 35 km
    ),
    Activity(
      id: 'demo-act-008',
      userId: 'demo-user-me',
      jenis: 'berjalan',
      mulaiAt: _now.subtract(const Duration(days: 7, hours: 2)),
      selesaiAt: _now.subtract(const Duration(days: 7, hours: 1, minutes: 15)),
      durasiS: 2700, // 45m 00s
      jarakM: 4100, // 4.1 km
    ),
    Activity(
      id: 'demo-act-009',
      userId: 'demo-user-me',
      jenis: 'lari',
      mulaiAt: _now.subtract(const Duration(days: 8, hours: 5)),
      selesaiAt: _now.subtract(const Duration(days: 8, hours: 4, minutes: 38)),
      durasiS: 1320, // 22m 00s
      jarakM: 4200, // 4.2 km
    ),
    Activity(
      id: 'demo-act-010',
      userId: 'demo-user-me',
      jenis: 'joging',
      mulaiAt: _now.subtract(const Duration(days: 9, hours: 3)),
      selesaiAt: _now.subtract(const Duration(days: 9, hours: 2, minutes: 35)),
      durasiS: 1500, // 25m 00s
      jarakM: 3600, // 3.6 km
    ),
  ];

  /// 6 active clubs with invite codes & targets
  static final List<Team> teams = [
    Team(
      id: '11111111-1111-1111-1111-111111111111',
      nama: 'GBK Runners Elite',
      targetNilai: 120000,
      isPrivate: false,
      inviteCode: 'GBKELITE',
      createdAt: _now.subtract(const Duration(days: 30)),
    ),
    Team(
      id: '22222222-2222-2222-2222-222222222222',
      nama: 'XI IPA 1 - SMAN 1',
      targetNilai: 100000,
      isPrivate: true,
      inviteCode: 'IPA1RUNS',
      createdAt: _now.subtract(const Duration(days: 25)),
    ),
    Team(
      id: '33333333-3333-3333-3333-333333333333',
      nama: 'JakBar Pacer Community',
      targetNilai: 75000,
      isPrivate: true,
      inviteCode: 'JAKBAR01',
      createdAt: _now.subtract(const Duration(days: 20)),
    ),
    Team(
      id: '44444444-4444-4444-4444-444444444444',
      nama: 'Monas Morning Joggers',
      targetNilai: 60000,
      isPrivate: false,
      inviteCode: 'MONASRUN',
      createdAt: _now.subtract(const Duration(days: 15)),
    ),
    Team(
      id: '55555555-5555-5555-5555-555555555555',
      nama: 'Sudirman Night Cyclists',
      targetNilai: 200000,
      isPrivate: false,
      inviteCode: 'SUDIRCYC',
      createdAt: _now.subtract(const Duration(days: 10)),
    ),
    Team(
      id: '66666666-6666-6666-6666-666666666666',
      nama: 'Jakarta Strollers 10K',
      targetNilai: 50000,
      isPrivate: false,
      inviteCode: 'JKTWALKS',
      createdAt: _now.subtract(const Duration(days: 5)),
    ),
  ];

  /// 6 challenges covering all sports and units
  static final List<Challenge> challenges = [
    Challenge(
      id: 'chal-001',
      jenis: 'lari',
      targetNilai: 5000,
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 3)),
      waktuSelesai: _now.add(const Duration(days: 4)),
    ),
    Challenge(
      id: 'chal-002',
      jenis: 'lari',
      targetNilai: 10000,
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 1)),
      waktuSelesai: _now.add(const Duration(days: 6)),
    ),
    Challenge(
      id: 'chal-003',
      jenis: 'bersepeda',
      targetNilai: 50000,
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 2)),
      waktuSelesai: _now.add(const Duration(days: 5)),
    ),
    Challenge(
      id: 'chal-004',
      jenis: 'berjalan',
      targetNilai: 7000,
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 4)),
      waktuSelesai: _now.add(const Duration(days: 3)),
    ),
    Challenge(
      id: 'chal-005',
      jenis: 'joging',
      targetNilai: 1800, // 30 mins
      targetSatuan: 'waktu_s',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 5)),
      waktuSelesai: _now.add(const Duration(days: 2)),
    ),
    Challenge(
      id: 'chal-006',
      jenis: 'lari',
      targetNilai: 21097, // Half marathon
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 7)),
      waktuSelesai: _now.add(const Duration(days: 14)),
    ),
  ];

  /// Realistic leaderboard rankings across metrics and periods
  static ({
    String boardNama,
    List<({Peringkat entry, String nama})> rows,
    String? uid,
  })
  getLeaderboardData({
    String metric = 'semua',
    String period = 'semua',
    String scope = 'global',
    String? uid,
  }) {
    final effectiveUid = uid ?? 'demo-user-me';

    final names = [
      'Budi Santoso',
      'Siti Rahma',
      'Andi Wijaya',
      'Dewi Lestari',
      'Rizky Pratama',
      'Farhan Ramadhan',
      'Maya Putri',
      'Eko Prasetyo',
      'Nia Kurnia',
      'Coach Hendra',
    ];

    List<double> rawValues;
    String boardTitle;

    if (metric == 'kalori') {
      boardTitle = period == 'bulanan'
          ? 'Kalori Terbakar (Bulanan)'
          : 'Kalori Terbakar (Mingguan)';
      rawValues = [3450, 3120, 2890, 2540, 2210, 1980, 1750, 1520, 1310, 1150];
    } else if (metric == 'durasi') {
      boardTitle = period == 'bulanan'
          ? 'Total Durasi (Bulanan - Menit)'
          : 'Total Durasi (Mingguan - Menit)';
      rawValues = [420, 385, 350, 310, 280, 245, 210, 185, 160, 130];
    } else {
      // 'jarak' or 'semua'
      boardTitle = period == 'bulanan'
          ? 'Peringkat Jarak (Bulanan - Km)'
          : 'Peringkat Jarak (Mingguan - Km)';
      rawValues = [54.2, 48.6, 45.1, 39.8, 36.4, 32.1, 28.5, 24.2, 21.0, 18.5];
    }

    // Demo scopes: my team = first 5, region = first 7, global = all 10.
    final count = switch (scope) {
      'team' => 5,
      'region' => 7,
      _ => 10,
    };
    final rows = <({Peringkat entry, String nama})>[];
    for (var i = 0; i < count; i++) {
      final isMine = i == 2; // Andi Wijaya or current demo user
      final userId = isMine ? effectiveUid : 'demo-user-$i';
      rows.add((
        entry: Peringkat(
          id: 'rank-$i',
          leaderboardId: 'demo-board-id',
          userId: userId,
          nilai: rawValues[i],
          posisi: i + 1,
        ),
        nama: isMine ? '${names[i]} (Kamu)' : names[i],
      ));
    }

    return (boardNama: boardTitle, rows: rows, uid: effectiveUid);
  }

  /// Active team chat messages
  static final List<ChatMessage> chatMessages = [
    ChatMessage(
      id: 'msg-001',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'user-001',
      userNama: 'Coach Hendra',
      body: 'Halo semuanya! Besok pagi kumpul lari bareng di GBK Gate 5 jam 06:00 WIB ya! 🏃‍♂️',
      createdAt: _now.subtract(const Duration(hours: 3)),
    ),
    ChatMessage(
      id: 'msg-002',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'user-002',
      userNama: 'Siti Rahma',
      body: 'Siap coach! Seragam jersey pacer warna lime kan?',
      createdAt: _now.subtract(const Duration(hours: 2, minutes: 45)),
    ),
    ChatMessage(
      id: 'msg-003',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'user-003',
      userNama: 'Budi Santoso',
      body: 'Betul, jangan lupa bawa tumbler air sendiri teman-teman!',
      createdAt: _now.subtract(const Duration(hours: 2, minutes: 30)),
    ),
    ChatMessage(
      id: 'msg-004',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'user-004',
      userNama: 'Dewi Lestari',
      body: 'Aku target ikut rute 5K santai yaa 👟',
      createdAt: _now.subtract(const Duration(hours: 1, minutes: 50)),
    ),
    ChatMessage(
      id: 'msg-005',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'user-005',
      userNama: 'Farhan Ramadhan',
      body: 'Keren! Tim kita sekarang ada di posisi 2 leaderboard mingguan!',
      createdAt: _now.subtract(const Duration(hours: 1, minutes: 15)),
    ),
    ChatMessage(
      id: 'msg-006',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'demo-user-me',
      userNama: 'Kamu',
      body: 'Mantap, besok aku pasti datang on time! Semangat semuanya 🔥',
      createdAt: _now.subtract(const Duration(minutes: 20)),
    ),
  ];

  /// Stats summary for statistic screen
  static const ({double km, int seconds}) statistics = (
    km: 45.2,
    seconds: 14760, // 4j 06m
  );

  /// Dummy coach student PE evaluation rows
  static const List<
    ({
      String nama,
      int sessions,
      double weekKm,
      int streak,
      double? progress,
      bool? berhasil,
    })
  >
  coachDummyRows = [
    (
      nama: 'Budi Santoso',
      sessions: 4,
      weekKm: 20.6,
      streak: 5,
      progress: 100.0,
      berhasil: true,
    ),
    (
      nama: 'Siti Rahma',
      sessions: 3,
      weekKm: 12.7,
      streak: 3,
      progress: 100.0,
      berhasil: true,
    ),
    (
      nama: 'Andi Wijaya',
      sessions: 2,
      weekKm: 7.6,
      streak: 7,
      progress: 76.0,
      berhasil: false,
    ),
    (
      nama: 'Dewi Lestari',
      sessions: 2,
      weekKm: 8.4,
      streak: 2,
      progress: 84.0,
      berhasil: false,
    ),
    (
      nama: 'Rizky Pratama',
      sessions: 5,
      weekKm: 62.5,
      streak: 12,
      progress: 100.0,
      berhasil: true,
    ),
    (
      nama: 'Farhan Ramadhan',
      sessions: 1,
      weekKm: 4.5,
      streak: 4,
      progress: 45.0,
      berhasil: false,
    ),
  ];
}
