import 'package:flutter/foundation.dart';

/// App language. Default Indonesian (per Figma's mixed copy, unified to ID).
enum Lang { id, en }

/// Global language state. UI reads [S] getters; toggling [langNotifier]
/// rebuilds the whole tree (PacerApp listens). Persisted to Supabase
/// `users.language` when signed in, local otherwise.
final ValueNotifier<Lang> langNotifier = ValueNotifier(Lang.id);

/// Set the moment the user explicitly picks a language. A backend read must
/// never silently override an explicit in-session choice (e.g. when the
/// profile row still holds the old default because a write failed).
bool langUserLocked = false;

/// All user-visible strings. Indonesian first, English alternate.
class S {
  static bool get _en => langNotifier.value == Lang.en;

  // Auth / GetStarted
  static String get appTagline =>
      _en ? 'Pacer, ready to help!' : 'Pacer, siap membantu!';
  static String get signIn => _en ? 'Sign In' : 'Daftar';
  static String get logIn => _en ? 'Log In' : 'Masuk';
  static String get welcomeRunners =>
      _en ? 'Welcome runners !' : 'Selamat datang, pelari !';
  static String get createAccount => _en ? 'Create an account' : 'Buat akun';
  static String get username => _en ? 'Username' : 'Nama pengguna';
  static String get email => _en ? 'Email' : 'Email';
  static String get password => _en ? 'Password' : 'Kata sandi';
  static String get confirmPassword =>
      _en ? 'Konfirmasi Password' : 'Konfirmasi Kata Sandi';
  static String get orSignUpWith =>
      _en ? 'or sign up with' : 'atau daftar dengan';

  // Home
  static String get history => _en ? 'History' : 'Riwayat';

  static String get home => _en ? 'Home' : 'Beranda';

  static String get teams => _en ? 'Teams' : 'Tim';

  static String get leaderboard => _en ? 'Leaderboard' : 'Peringkat';
  static String get pacerTeams => _en ? 'Pacer Teams' : 'Tim Pacer';
  static String get seeAll => _en ? 'See all' : 'Lihat semua';
  static String get activeStreak => _en ? 'ACTIVE STREAK' : 'STREAK AKTIF';
  static String get daysStreak => _en ? 'DAYS STREAK' : 'HARI BERUNTUN';
  static String get personalRecord => _en
      ? 'Personal Record • Best since Nov 2024'
      : 'Rekor Pribadi • Terbaik sejak Nov 2024';
  static String get time => _en ? 'Time' : 'Waktu';
  static String get pace => _en ? 'Pace' : 'Pace';

  // Tracker
  static String get gps => 'GPS';
  static String get distanceKm => _en ? 'Distance (Km)' : 'Jarak (Km)';
  static String get avgPace => _en ? 'Avg Pace' : 'Pace Rata-rata';
  static String get duration => _en ? 'Duration' : 'Durasi';
  static String get calories => _en ? 'Calories' : 'Kalori';
  static String get pause => _en ? 'PAUSE' : 'JEDA';
  static String get continueLabel => _en ? 'CONTINUE' : 'LANJUT';
  static String get finish => _en ? 'FINISH' : 'SELESAI';
  static String get running => _en ? 'Running' : 'Lari';

  // Finish metrics
  static String get stepLength => _en ? 'Step Length' : 'Panjang Langkah';
  static String get distanceBetweenSteps =>
      _en ? 'Distance between steps' : 'Jarak antar langkah';
  static String get elevationGain =>
      _en ? 'Elevation Gain' : 'Kenaikan Elevasi';
  static String get totalHeightClimb =>
      _en ? 'Total height that you climb' : 'Total ketinggian pendakian';
  static String get cadence => _en ? 'Cadence' : 'Kadensi';
  static String get stepsPerMinute =>
      _en ? 'Steps per minute' : 'Langkah per menit';
  static String get caloriesLabel => _en ? 'Calories' : 'Kalori';
  static String get totalEnergyBurned =>
      _en ? 'Total energy burned' : 'Total energi terbakar';
  static String get done => _en ? 'done' : 'selesai';

  // Setup
  static String get chooseSport => _en ? 'Choose Sport' : 'Pilih Olahraga';
  static String get setupSubtitle => _en
      ? 'Choose an activity to record your session metrics.'
      : 'Pilih aktivitas untuk mencatat metrik sesi Anda.';
  static String get outdoorRun => _en ? 'Outdoor Run' : 'Lari Luar';
  static String get gpsDistanceTempo =>
      _en ? 'GPS, distance & tempo' : 'GPS, jarak & tempo';
  static String get sessionGoal => _en ? 'SESSION GOAL' : 'SASARAN SESI';
  static String get free => _en ? 'Free' : 'Bebas';
  static String get startRun => _en ? 'Start Run' : 'Mulai Lari';

  // Teams
  static String get findTeamsNearby =>
      _en ? 'Find Teams Near You' : 'Temukan Team Di Sekitarmu';
  static String get searchClubs => _en
      ? 'Search clubs, cities, or friends...'
      : 'Cari klub, kota, atau teman...';
  static String get createTeam => _en ? 'create team' : 'buat teams';
  static String get nearestGroupRun =>
      _en ? 'Nearest Group Run' : 'Group Run Terdekat';
  static String get join => _en ? 'Join' : 'Gabung';
  static String get teamChat => _en ? 'Team Chat' : 'Obrolan Tim';

  // Leaderboard
  static String get teamsLeaderboard =>
      _en ? 'Teams Leaderboard' : 'Peringkat Tim';
  static String get you => _en ? 'You' : 'Anda';

  // Challenge
  static String get challenge => _en ? 'challenge' : 'tantangan';
  static String get challengeDetail =>
      _en ? 'challenge detail' : 'detail tantangan';
  static String get distance => _en ? 'Distance' : 'Jarak';
  static String get date => _en ? 'Date' : 'Tanggal';
  static String get startChallenge =>
      _en ? 'start challenge' : 'mulai tantangan';
  static String get createChallenge =>
      _en ? 'Create challenge' : 'Buat challenge';

  // Account
  static String get account => _en ? 'ACCOUNT' : 'AKUN';
  static String get aboutMe => _en ? 'About Me' : 'Tentang Saya';
  static String get features => _en ? 'Features' : 'Fitur';
  static String get out => _en ? 'Out' : 'Keluar';
  static String get language => _en ? 'Language' : 'Bahasa';
  static String get fullName => _en ? 'Full Name' : 'Nama Lengkap';
  static String get birth => _en ? 'Birth' : 'Lahir';
  static String get gender => _en ? 'Gender' : 'Jenis Kelamin';
  static String get height => _en ? 'Height' : 'Tinggi';
  static String get weight => _en ? 'Weight' : 'Berat';
  static String get editPersonalDetails =>
      _en ? 'Edit Personal Details' : 'Edit Detail Pribadi';

  // Fitur tiles
  static String get streaks => _en ? 'streaks' : 'streak';
  static String get riwayat => _en ? 'history' : 'riwayat';
  static String get profile => _en ? 'profile' : 'profil';

  // Statistic
  static String get statistic => _en ? 'Statistic' : 'Statistik';
  static String get totalRunDistance =>
      _en ? 'TOTAL RUNNING DISTANCE' : 'TOTAL JARAK LARI';
  static String get targetAchieved =>
      _en ? 'Target achieved' : 'Target tercapai';
  static String get averagePace => _en ? 'Average Pace' : 'Rata-rata Pace';
  static String get totalTime => _en ? 'Total Time' : 'Total Waktu';
  static String get activeCalories => _en ? 'Active Calories' : 'Kalori Aktif';

  // Streaks screen
  static String get thisWeek => _en ? 'THIS WEEK' : 'MINGGU INI';
  static String get of7Days => _en ? '5 of 7 Days' : '5 dari 7 Hari';

  // Chat
  static String get today => _en ? 'Today' : 'Hari ini';
  static String get writeMessage => _en ? 'Write a message…' : 'Tulis pesan…';

  // Create club / challenge forms
  static String get teamName => _en ? 'Team Name' : 'Nama Teams';
  static String get clubFocus => _en ? 'Club Focus' : 'Fokus Klub';
  static String get cityHQ => _en ? 'City / HQ' : 'Kota / Markas';
  static String get communityPrivacy =>
      _en ? 'Community Privacy' : 'Privasi Komunitas';
  static String get publicLabel => _en ? 'Public' : 'Publik';
  static String get privateLabel => _en ? 'Private' : 'Privat';
  static String get addLogo => _en ? 'Add Logo' : 'Tambah Logo';
  static String get back => _en ? 'Back' : 'Kembali';
  static String get durationLabel => _en ? 'DURATION' : 'DURASI';
  static String get target => _en ? 'TARGET' : 'TARGET';
  static String get other => _en ? 'Other' : 'Lainnya';
  static String get todayLabel => _en ? 'Today' : 'Hari Ini';
  static String get days3 => _en ? '3 Days' : '3 Hari';
  static String get week1 => _en ? '1 Week' : '1 Minggu';
  static String get custom => _en ? 'Custom' : 'Custom';

  // Persyaratan
  static String get clubRequirements => _en
      ? '3 main things before publishing a club...'
      : '3 hal utama sebelum menerbitkan klub...';
  static String get activeCaptain => _en ? 'Active Captain' : 'Kapten Aktif';
  static String get activeCaptainDesc =>
      _en ? 'Club needs an active captain' : 'Klub butuh kapten yang aktif';
  static String get min3Members => _en ? 'Min. 3 Members' : 'Min. 3 Anggota';
  static String get min3MembersDesc =>
      _en ? 'Invite at least 3 runners' : 'Ajak minimal 3 pelari';
  static String get routineGroupRun =>
      _en ? 'Routine Group Run' : 'Group Run Rutin';
  static String get routineGroupRunDesc =>
      _en ? 'Schedule regular runs together' : 'Jadwalkan lari bersama rutin';
  static String get agree => _en ? 'agree' : 'setuju';

  // Demo messages
  static String get demoJoinSent =>
      _en ? 'Demo: join request sent' : 'Demo: permintaan gabung terkirim';
  static String get demoChallengeStarted =>
      _en ? 'Demo: challenge started' : 'Demo: challenge dimulai';
  static String get demoMessageSent =>
      _en ? 'Demo: message sent' : 'Demo: pesan terkirim';
  static String get demoEmail =>
      _en ? 'Demo: sitirahma@pacer.id' : 'Demo: sitirahma@pacer.id';
  static String get langSaveFailed => _en
      ? "Couldn't save language online — using it on this device only."
      : 'Bahasa gagal disimpan online — hanya berlaku di perangkat ini.';
}
