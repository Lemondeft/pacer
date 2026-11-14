import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language. Default Indonesian (per Figma's mixed copy, unified to ID).
enum Lang { id, en }

/// Local persistence key for language choice.
const String _kPrefLang = 'pacer_user_language';

/// Global language state. UI reads [S] getters; toggling [langNotifier]
/// rebuilds the whole tree (PacerApp listens). Persisted to Supabase
/// `users.language` when signed in, local otherwise.
final ValueNotifier<Lang> langNotifier = ValueNotifier(Lang.id);

/// Set the moment the user explicitly picks a language. A backend read must
/// never silently override an explicit in-session choice (e.g. when the
/// profile row still holds the old default because a write failed).
bool langUserLocked = false;

/// Loads local language preference on app startup before UI renders.
Future<void> initLanguagePreference() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefLang);
    if (saved != null) {
      langNotifier.value = saved == 'en' ? Lang.en : Lang.id;
      langUserLocked = true;
    }
  } catch (_) {}
}

/// Persists user's explicit language preference to local storage.
Future<void> persistLanguagePreference(Lang lang) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefLang, lang == Lang.en ? 'en' : 'id');
  } catch (_) {}
}

/// All user-visible strings. Indonesian first, English alternate.
class S {
  static bool get _en => langNotifier.value == Lang.en;

  // Auth / GetStarted
  static String get appTagline =>
      _en ? 'Pacer, ready to help!' : 'Pacer, siap membantu!';
  static String get signUp => _en ? 'Sign Up' : 'Daftar';
  static String get signIn => _en ? 'Sign Up' : 'Daftar';
  static String get logIn => _en ? 'Log In' : 'Masuk';
  static String get welcomeRunners =>
      _en ? 'Welcome runners !' : 'Selamat datang, pelari !';
  static String get createAccount => _en ? 'Create an account' : 'Buat akun';
  static String get username => _en ? 'Username' : 'Nama pengguna';
  static String get email => _en ? 'Email' : 'Email';
  static String get password => _en ? 'Password' : 'Kata sandi';
  static String get confirmPassword =>
      _en ? 'Confirm Password' : 'Konfirmasi Kata Sandi';
  static String get orSignUpWith =>
      _en ? 'or sign up with' : 'atau daftar dengan';
  static String get errFillAll =>
      _en ? 'Fill in all fields.' : 'Lengkapi semua kolom.';
  static String get errEmail => _en ? 'Invalid email.' : 'Email tidak valid.';
  static String get errPasswordMatch =>
      _en ? 'Passwords do not match.' : 'Kata sandi tidak cocok.';
  static String get errSignupFailed =>
      _en ? 'Sign-up failed. Try again.' : 'Pendaftaran gagal. Coba lagi.';
  static String get errLoginFailed => _en
      ? 'Login failed. Check your details.'
      : 'Masuk gagal. Periksa data Anda.';
  static String get errSaveFailed =>
      _en ? 'Save failed. Try again.' : 'Gagal menyimpan. Coba lagi.';
  static String get confirmEmail => _en
      ? 'Account created — check your email to verify, then log in.'
      : 'Akun dibuat — cek email untuk verifikasi, lalu masuk.';
  static String get discardTitle =>
      _en ? 'Discard recording?' : 'Buang rekaman?';
  static String get discardBody => _en
      ? 'The unfinished activity will be deleted.'
      : 'Aktivitas yang belum selesai akan dihapus.';
  static String get discardYes => _en ? 'Discard' : 'Buang';

  // Home
  static String get history => _en ? 'History' : 'Riwayat';

  static String get home => _en ? 'Home' : 'Beranda';

  static String get teams => _en ? 'Teams' : 'Tim';

  static String get leaderboard => _en ? 'Leaderboard' : 'Peringkat';
  static String get pacerTeams => _en ? 'Pacer Teams' : 'Tim Pacer';
  static String get seeAll => _en ? 'See all' : 'Lihat semua';
  static String get activeStreak => _en ? 'ACTIVE STREAK' : 'STREAK AKTIF';
  static String get daysStreak => _en ? 'DAYS STREAK' : 'HARI BERUNTUN';
  static String get streakAtRisk => _en ? 'STREAK AT RISK' : 'STREAK TERANCAM';
  static String get noStreak => _en ? 'NO ACTIVE STREAK' : 'BELUM ADA STREAK';
  static String get streakActiveMsg => _en
      ? 'You ran today. Keep it going!'
      : 'Kamu sudah lari hari ini. Pertahankan!';
  static String streakAtRiskMsg(int n) => _en
      ? 'Run today to keep your $n-day streak'
      : 'Lari hari ini agar streak $n hari tetap jalan';
  static String get streakInactiveMsg => _en
      ? 'Start a run today to begin a new streak'
      : 'Mulai lari hari ini untuk memulai streak baru';
  static String daysOf7(int n) => _en ? '$n of 7 Days' : '$n dari 7 Hari';
  static String get personalRecord => _en
      ? 'Personal Record • Best since Nov 2024'
      : 'Rekor Pribadi • Terbaik sejak Nov 2024';
  static String get time => _en ? 'Time' : 'Waktu';
  static String get pace => _en ? 'Pace' : 'Pace';

  // Tracker
  static String get gps => 'GPS';
  static String get gpsOff => _en
      ? 'Turn on location services to record.'
      : 'Nyalakan layanan lokasi untuk merekam.';
  static String get gpsDenied =>
      _en ? 'Location permission denied.' : 'Izin lokasi ditolak.';
  static String get distanceKm => _en ? 'Distance (Km)' : 'Jarak (Km)';
  static String get avgPace => _en ? 'Avg Pace' : 'Pace Rata-rata';
  static String get duration => _en ? 'Duration' : 'Durasi';
  static String get calories => _en ? 'Calories' : 'Kalori';
  static String get pause => _en ? 'PAUSE' : 'JEDA';
  static String get startLabel => _en ? 'START' : 'MULAI';
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
  static String get outdoorRun => _en ? 'Outdoor Run' : 'Lari';
  static String get jogging => _en ? 'Jogging' : 'Joging';
  static String get cycling => _en ? 'Cycling' : 'Bersepeda';
  static String get walking => _en ? 'Walking' : 'Berjalan';
  static String get runSubtitle =>
      _en ? 'GPS, distance & tempo' : 'GPS, jarak & tempo';
  static String get jogSubtitle =>
      _en ? 'Light endurance pace' : 'Tempo sedang & daya tahan';
  static String get cyclingSubtitle =>
      _en ? 'Speed, elevation & route' : 'Kecepatan, elevasi & rute';
  static String get walkingSubtitle =>
      _en ? 'Step rhythm & distance' : 'Irama langkah & jarak tempuh';
  static String get gpsDistanceTempo =>
      _en ? 'GPS, distance & tempo' : 'GPS, jarak & tempo';
  static String get sessionGoal => _en ? 'SESSION GOAL' : 'SASARAN SESI';
  static String get free => _en ? 'Free' : 'Bebas';
  static String get startRun => _en ? 'Start Activity' : 'Mulai Olahraga';

  // Leaderboard filters (per manual DFD 2.4 & PDM)
  static String get filterMetric => _en ? 'Metric' : 'Kriteria';
  static String get metricDistance => _en ? 'Distance' : 'Jarak';
  static String get metricCalories => _en ? 'Calories' : 'Kalori';
  static String get metricDuration => _en ? 'Duration' : 'Durasi';
  static String get filterPeriod => _en ? 'Period' : 'Periode';
  static String get periodDaily => _en ? 'Daily' : 'Harian';
  static String get periodWeekly => _en ? 'Weekly' : 'Mingguan';
  static String get periodMonthly => _en ? 'Monthly' : 'Bulanan';
  static String get allTime => _en ? 'All Time' : 'Semua';

  // Notifications (per context diagram)
  static String get notifications => _en ? 'Notifications' : 'Notifikasi';
  static String get reminderTitle =>
      _en ? 'Activity Reminder' : 'Pengingat Aktivitas';
  static String get reminderBody => _en
      ? 'Time for your daily workout! Keep your streak burning 🔥'
      : 'Saatnya olahraga hari ini! Pertahankan streak-mu 🔥';

  // Teams
  static String get findTeamsNearby =>
      _en ? 'Find Teams Near You' : 'Temukan Team Di Sekitarmu';
  static String get searchClubs => _en
      ? 'Search clubs, cities, or friends...'
      : 'Cari klub, kota, atau teman...';
  static String get createTeam => _en ? 'Create Team' : 'Buat Tim';
  static String get nearestGroupRun =>
      _en ? 'Nearest Group Run' : 'Group Run Terdekat';
  static String get join => _en ? 'Join' : 'Gabung';
  static String get teamChat => _en ? 'Team Chat' : 'Obrolan Tim';

  // Leaderboard
  static String get teamsLeaderboard =>
      _en ? 'Teams Leaderboard' : 'Peringkat Tim';
  static String get you => _en ? 'You' : 'Anda';

  // Challenge
  static String get challenge => _en ? 'Challenge' : 'Tantangan';
  static String get challengeDetail =>
      _en ? 'Challenge Detail' : 'Detail Tantangan';
  static String get distance => _en ? 'Distance' : 'Jarak';
  static String get date => _en ? 'Date' : 'Tanggal';
  static String get startChallenge =>
      _en ? 'Start Challenge' : 'Mulai Tantangan';
  static String get leaveChallenge => _en ? 'Leave' : 'Keluar';
  static String get coachOnly =>
      _en ? 'Only coaches can do that.' : 'Hanya coach yang bisa.';
  static String get teamCreated => _en ? 'Team created.' : 'Tim dibuat.';
  static String get createChallenge =>
      _en ? 'Create challenge' : 'Buat challenge';
  static String get challengeActive => _en ? 'Active' : 'Aktif';
  static String get challengeEnded => _en ? 'Ended' : 'Berakhir';
  static String get challengeCompletedLabel =>
      _en ? 'Target Achieved' : 'Target Tercapai';
  static String get challengeOpenEnded =>
      _en ? 'Ongoing' : 'Berjalan terus';
  static String get challengeSportLabel => _en ? 'Sport' : 'Olahraga';
  static String get challengeProgressLabel => _en ? 'Progress' : 'Progres';
  static String get targetTime => _en ? 'Time Target' : 'Target Waktu';
  static String get challengeEndedJoinBlocked => _en
      ? 'This challenge has already ended.'
      : 'Challenge ini sudah berakhir.';
  static String get joinedChallenge => _en ? 'Joined' : 'Diikuti';

  static String challengeTargetValue(double targetNilai, String targetSatuan) {
    final v = targetSatuan == 'jarak_m' ? targetNilai / 1000 : targetNilai / 60;
    return v == v.truncateToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
  }

  static String challengeTargetUnit(String targetSatuan) =>
      targetSatuan == 'jarak_m' ? 'KM' : 'MNT';

  static String challengeTargetSummary(
    double targetNilai,
    String targetSatuan,
  ) =>
      '${challengeTargetValue(targetNilai, targetSatuan)} ${challengeTargetUnit(targetSatuan)}';

  // Account
  static String get account => _en ? 'ACCOUNT' : 'AKUN';
  static String get aboutMe => _en ? 'About Me' : 'Tentang Saya';
  static String get features => _en ? 'Features' : 'Fitur';
  static String get out => _en ? 'Log Out' : 'Keluar';
  static String get logOut => _en ? 'Log Out' : 'Keluar';
  static String get language => _en ? 'Language' : 'Bahasa';
  static String get fullName => _en ? 'Full Name' : 'Nama Lengkap';
  static String get birth => _en ? 'Birth' : 'Lahir';
  static String get gender => _en ? 'Gender' : 'Jenis Kelamin';
  static String get genderMale => _en ? 'Male' : 'Laki-laki';
  static String get genderFemale => _en ? 'Female' : 'Perempuan';
  static String get height => _en ? 'Height' : 'Tinggi';
  static String get weight => _en ? 'Weight' : 'Berat';
  static String get editPersonalDetails =>
      _en ? 'Edit Personal Details' : 'Edit Detail Pribadi';
  static String get saveLabel => _en ? 'Save' : 'Simpan';
  static String get cancelLabel => _en ? 'Cancel' : 'Batal';
  static String get editNameTitle => _en ? 'Edit name' : 'Ubah nama';
  static String get nameSaved => _en ? 'Name saved.' : 'Nama tersimpan.';

  // Fitur tiles
  static String get streaks => _en ? 'Streaks' : 'Streak';
  static String get riwayat => _en ? 'History' : 'Riwayat';
  static String get profile => _en ? 'Profile' : 'Profil';

  // Theme
  static String get theme => _en ? 'Theme' : 'Tema';
  static String get themeSystem => _en ? 'System' : 'Sistem';
  static String get themeSystemSub =>
      _en ? 'Follow device theme' : 'Ikuti tema perangkat';
  static String get themeLight => _en ? 'Light' : 'Terang';
  static String get themeLightSub =>
      _en ? 'Light appearance' : 'Tampilan terang';
  static String get themeDark => _en ? 'Dark' : 'Gelap';
  static String get themeDarkSub =>
      _en ? 'Dark appearance' : 'Tampilan gelap';

  // Team mod dialogs
  static String get kickMemberTitle =>
      _en ? 'Remove member?' : 'Keluarkan anggota?';
  static String kickMemberBody(String name) => _en
      ? '$name will be removed from this team.'
      : '$name akan dikeluarkan dari tim ini.';
  static String get kickMemberConfirm => _en ? 'Remove' : 'Keluarkan';
  static String get deleteTeamTitle =>
      _en ? 'Delete team?' : 'Hapus tim?';
  static String deleteTeamBody(String team) => _en
      ? '$team and all its members will be deleted.'
      : '$team dan semua anggotanya akan dihapus.';
  static String get deleteConfirm => _en ? 'Delete' : 'Hapus';
  static String get editTeamTitle => _en ? 'Edit team' : 'Ubah tim';
  static String get editLabel => _en ? 'Edit' : 'Ubah';
  static String get deleteLabel => _en ? 'Delete' : 'Hapus';

  // Empty states
  static String get emptyLeaderboard =>
      _en ? 'No rankings yet.' : 'Belum ada peringkat.';
  static String get emptyTeams =>
      _en ? 'Not joined any team yet.' : 'Belum gabung tim mana pun.';
  static String get emptyHistory =>
      _en ? 'No routes saved yet.' : 'Belum ada rute tersimpan.';
  static String get emptyChat =>
      _en ? 'No messages yet. Start chatting!' : 'Belum ada pesan. Mulai duluan!';

  // Sport name mapper
  static String sportName(String jenis) {
    switch (jenis.toLowerCase()) {
      case 'lari':
        return _en ? 'Running' : 'Lari';
      case 'joging':
        return _en ? 'Jogging' : 'Joging';
      case 'bersepeda':
        return _en ? 'Cycling' : 'Bersepeda';
      case 'berjalan':
        return _en ? 'Walking' : 'Berjalan';
      default:
        return jenis.isEmpty
            ? jenis
            : '${jenis[0].toUpperCase()}${jenis.substring(1)}';
    }
  }

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
  static String get publicTeamHint => _en
      ? 'Listed in Find Teams. Anyone can join without a code.'
      : 'Tampil di Temukan Tim. Siapa saja bisa gabung tanpa kode.';
  static String get privateTeamHint => _en
      ? 'Hidden from the directory. Join only with the secret code from the coach.'
      : 'Tidak tampil di direktori. Gabung hanya dengan kode rahasia dari coach.';
  static String get region => _en ? 'Region' : 'Wilayah';
  static String get regionNotSet =>
      _en ? 'Your region is not set' : 'Wilayahmu belum diatur';
  static String get regionPrompt => _en
      ? 'Set your region to see how you rank against runners nearby.'
      : 'Atur wilayahmu untuk melihat peringkat pelari di daerahmu.';
  static String get setRegion => _en ? 'Set region' : 'Atur wilayah';
  static String get notSet => _en ? 'Not set' : 'Belum diatur';
  static String get pickDate => _en ? 'Pick date' : 'Pilih tanggal';
  static String get invalidHeight =>
      _en ? 'Height must be between 1 and 299 cm' : 'Tinggi harus 1–299 cm';
  static String get invalidWeight =>
      _en ? 'Weight must be between 1 and 999 kg' : 'Berat harus 1–999 kg';
  static String get scopeMyTeam => _en ? 'My Team' : 'Tim Saya';
  static String get scopeRegion => _en ? 'Region' : 'Wilayah';
  static String get scopeGlobal => _en ? 'Global' : 'Global';
  static String get joinByCode => _en ? 'Join with code' : 'Gabung lewat kode';
  static String get teamCodeLabel => _en ? 'Team code' : 'Kode tim';
  static String get regenerateCode => _en ? 'New code' : 'Kode baru';
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
  static String get agree => _en ? 'Agree' : 'Setuju';

  // Coach board (PE grading)
  static String get coachBoard => _en ? 'Class' : 'Kelas';
  static String get pickTeam => _en ? 'Pick a team' : 'Pilih tim';
  static String get pickChallenge =>
      _en ? 'Challenge (optional)' : 'Tantangan (opsional)';
  static String get noMembers => _en ? 'No members yet.' : 'Belum ada anggota.';
  static String get sessionsCol => _en ? 'Sessions' : 'Sesi';

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

  // Offline & Sync UI
  static String get offlineBannerTitle =>
      _en ? 'Offline mode' : 'Mode offline';
  static String get offlineBannerBody => _en
      ? 'Runs & edits save on this device and sync automatically when online.'
      : 'Lari & perubahan tersimpan di perangkat ini dan sinkron otomatis saat online.';
  static String get syncingNow => _en ? 'Syncing...' : 'Menyinkronkan...';
  static String syncPendingCount(int n) =>
      _en ? '$n pending sync' : '$n menunggu sinkron';
  static String syncFailedCount(int n) =>
      _en ? '$n sync failed' : '$n gagal sinkron';
  static String get syncRetry => _en ? 'Retry' : 'Coba lagi';
  static String get syncSignInAgain =>
      _en ? 'Sign in again to sync' : 'Masuk ulang untuk sinkron';
  static String get syncChipLocal => _en ? 'Local' : 'Lokal';
  static String get syncChipSynced => _en ? 'Synced' : 'Sinkron';
  static String get syncChipFailed => _en ? 'Failed' : 'Gagal';
  static String get draftRecoveryTitle =>
      _en ? 'Unfinished run found' : 'Ada lari yang belum selesai';
  static String draftRecoveryBody(String sport, String km, String dur) => _en
      ? 'Resume your $sport session ($km · $dur) or save it now?'
      : 'Lanjutkan sesi $sport ($km · $dur) atau simpan sekarang?';
  static String get draftResume => _en ? 'Resume' : 'Lanjutkan';
  static String get draftSaveNow => _en ? 'Save now' : 'Simpan sekarang';
  static String get draftDiscard => _en ? 'Discard' : 'Buang';
  static String get unsyncedSignOutTitle =>
      _en ? 'Unsynced data on device' : 'Data belum tersinkron';
  static String unsyncedSignOutBody(int n) => _en
      ? '$n item(s) have not synced to the cloud yet. Signing out will clear local data.'
      : '$n item belum tersinkron ke server. Keluar akan menghapus data lokal.';
  static String get signOutAnyway => _en ? 'Sign out anyway' : 'Tetap keluar';
  static String get offlineActionNeedsNet => _en
      ? 'Connect to the internet to complete this action.'
      : 'Hubungkan internet untuk menyelesaikan tindakan ini.';
  static String get queuedOfflineSaved => _en
      ? 'Saved on device — will sync automatically when online.'
      : 'Tersimpan di perangkat — otomatis sinkron saat online.';
  static String get pendingSyncSection =>
      _en ? 'Device Sync' : 'Sinkronisasi Perangkat';
  static String get pendingSyncAllClear => _en
      ? 'All runs and changes are synced'
      : 'Semua lari dan perubahan tersinkron';
  static String get chatOfflineComposerHint => _en
      ? 'Offline — messages send when back online'
      : 'Offline — pesan terkirim saat kembali online';
  static String get noRunsOfflineEmpty => _en
      ? 'No runs yet. Start a run offline anytime!'
      : 'Belum ada lari. Mulai lari offline kapan saja!';
  static String get noTeamsCachedEmpty =>
      _en ? 'No clubs yet on this device.' : 'Belum ada klub di perangkat ini.';
  static String get noChallengesCachedEmpty => _en
      ? 'No challenges saved locally.'
      : 'Belum ada challenge tersimpan lokal.';
  static String get noLeaderboardCachedEmpty => _en
      ? 'Leaderboard data not cached yet.'
      : 'Data papan peringkat belum tersimpan.';

  // OSM route & navigation micro-interactions
  static String get noGpsPoints => _en
      ? 'No GPS route points recorded'
      : 'Belum ada titik rute GPS';
  static String get loadingRoute =>
      _en ? 'Loading route...' : 'Memuat rute...';
  static String get recenterRoute => _en ? 'Fit route' : 'Paskan rute';
  static String get toggleMapStyle =>
      _en ? 'Switch map view' : 'Ganti tampilan peta';
  static String get pressBackAgainToExit => _en
      ? 'Press back again to exit'
      : 'Tekan kembali lagi untuk keluar';
  static String get unitKcal => _en ? 'kcal' : 'kkal';
}
