import 'package:flutter/foundation.dart';
import 'package:pacer/src/auth/profile_input.dart';
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
  static String get errPasswordLength => _en
      ? 'Password must be at least 6 characters.'
      : 'Kata sandi minimal 6 karakter.';
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
  static String get verifyEmailTitle =>
      _en ? 'Verify your email' : 'Verifikasi email kamu';
  static String verifyEmailSubtitle(String email) => _en
      ? 'We sent a confirmation link to $email. Tap "Confirm email address" in your inbox, then log in.'
      : 'Kami mengirim tautan konfirmasi ke $email. Klik "Confirm email address" di kotak masuk, lalu masuk.';
  static String get iveVerifiedLogin =>
      _en ? "I've Confirmed — Log In" : 'Sudah Verifikasi — Masuk';
  static String get resendVerification =>
      _en ? 'Resend confirmation email' : 'Kirim ulang email verifikasi';
  static String get verificationResent => _en
      ? 'Confirmation email sent. Check your inbox and spam folder.'
      : 'Email verifikasi dikirim. Cek kotak masuk dan folder spam.';
  static String get alreadyHaveAccount =>
      _en ? 'Already have an account? Log In' : 'Sudah punya akun? Masuk';
  static String get forgotPassword =>
      _en ? 'Forgot password?' : 'Lupa kata sandi?';
  static String get resetPasswordTitle =>
      _en ? 'Reset password' : 'Atur ulang kata sandi';
  static String get resetPasswordSubtitle => _en
      ? 'Enter your email and we will send you a password reset link.'
      : 'Masukkan email Anda dan kami akan mengirim tautan atur ulang kata sandi.';
  static String get sendResetLink =>
      _en ? 'Send Reset Link' : 'Kirim Tautan Reset';
  static String resetEmailSent(String email) => _en
      ? 'Reset link sent to $email. Open your email and tap the link to set a new password.'
      : 'Tautan reset dikirim ke $email. Buka email Anda lalu klik tautan untuk mengatur sandi baru.';
  static String get setNewPasswordTitle =>
      _en ? 'Set new password' : 'Atur kata sandi baru';
  static String get newPasswordHint =>
      _en ? 'New password (min 6 chars)' : 'Kata sandi baru (min 6 karakter)';
  static String get updatePasswordButton =>
      _en ? 'Update Password' : 'Simpan Kata Sandi';
  static String get passwordUpdatedNotice => _en
      ? 'Password updated! Welcome back.'
      : 'Kata sandi diperbarui! Selamat datang kembali.';
  static String get doneButton => _en ? 'Done' : 'Selesai';
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
  static String get bgTrackingChannelName =>
      _en ? 'Workout Tracking' : 'Pelacakan Olahraga';
  static String bgTrackingTitle(String jenis) => 'Pacer · ${sportName(jenis)}';
  static String get bgTrackingBody => _en
      ? 'Recording GPS route and activity in the background.'
      : 'Merekam rute GPS dan aktivitas di latar belakang.';
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
  static String get allTime => _en ? 'All Time' : 'Sepanjang Waktu';

  // Notifications (per context diagram)
  static String get notifications => _en ? 'Notifications' : 'Notifikasi';
  static String get reminderTitle =>
      _en ? 'Activity Reminder' : 'Pengingat Aktivitas';
  static String get reminderBody => _en
      ? 'Time for your daily workout! Keep your streak burning 🔥'
      : 'Saatnya olahraga hari ini! Pertahankan streak-mu 🔥';

  // Teams
  static String get findTeamsNearby =>
      _en ? 'Find Teams Near You' : 'Temukan Tim Di Sekitarmu';
  static String get searchClubs => _en
      ? 'Search clubs, cities, or friends...'
      : 'Cari klub, kota, atau teman...';
  static String get createTeam => _en ? 'Create Team' : 'Buat Tim';
  static String get nearestGroupRun =>
      _en ? 'Nearest Group Run' : 'Group Run Terdekat';
  static String get join => _en ? 'Join' : 'Gabung';
  static String get teamChat => _en ? 'Team Chat' : 'Obrolan Tim';
  static String get joinedTeams => _en ? 'Joined Teams' : 'Tim yang Diikuti';
  static String get openPublicTeams =>
      _en ? 'Open for Public' : 'Terbuka untuk Umum';
  static String get filterAll => _en ? 'All' : 'Semua';
  static String get filterJoined => _en ? 'Joined' : 'Diikuti';
  static String get filterPublic => _en ? 'Public' : 'Publik';
  static String get joinedBadge => _en ? 'Joined' : 'Bergabung';
  static String get publicBadge => _en ? 'Public' : 'Publik';
  static String get privateBadge => _en ? 'Private' : 'Privat';
  static String membersCount(int n) =>
      _en ? (n == 1 ? '1 member' : '$n members') : '$n anggota';
  static String get teamDashboard => _en ? 'Team Dashboard' : 'Dasbor Tim';
  static String get teamOverview => _en ? 'Overview' : 'Ringkasan';
  static String get membersSection => _en ? 'Members' : 'Anggota';
  static String get searchMembersHint =>
      _en ? 'Search members...' : 'Cari anggota...';
  static String get activeThisWeek =>
      _en ? 'Active (7d)' : 'Aktif (7h)';
  static String get weeklyDistance => _en ? 'Weekly km' : 'Km minggu ini';
  static String get weeklySessions => _en ? 'Sessions' : 'Sesi';
  static String get totalDistanceAll =>
      _en ? 'Total team km' : 'Total km tim';
  static String get targetGoal => _en ? 'Team Target' : 'Target Tim';
  static String get inviteCodeSection =>
      _en ? 'Invite Code' : 'Kode Undangan';
  static String get inviteCodeHint => _en
      ? 'Only team members can view this private invite code. Share it carefully.'
      : 'Hanya anggota tim yang dapat melihat kode undangan privat ini.';
  static String get copyCode => _en ? 'Copy' : 'Salin';
  static String get codeCopied =>
      _en ? 'Invite code copied.' : 'Kode undangan disalin.';
  static String get captainRole => _en ? 'Captain' : 'Ketua';
  static String get memberRole => _en ? 'Member' : 'Anggota';
  static String joinedOn(String date) =>
      _en ? 'Joined $date' : 'Bergabung $date';
  static String get leaveTeamAction => _en ? 'Leave team' : 'Keluar tim';
  static String get leaveTeamConfirmTitle =>
      _en ? 'Leave team?' : 'Keluar dari tim?';
  static String leaveTeamConfirmBody(String team) => _en
      ? 'You will leave $team and lose access to its team chat.'
      : 'Kamu akan keluar dari $team dan tidak lagi mengakses obrolan tim.';
  static String get noJoinedTeamsHint => _en
      ? 'You have not joined any teams yet. Pick a public team below or enter an invite code.'
      : 'Belum bergabung di tim mana pun. Pilih tim publik di bawah atau masukkan kode undangan.';
  static String get noPublicTeamsHint => _en
      ? 'No open public teams match your search.'
      : 'Tidak ada tim publik yang sesuai pencarian.';
  static String get noMembersMatch =>
      _en ? 'No members match your search.' : 'Tidak ada anggota yang cocok.';
  static String get teamPrivacyLabel =>
      _en ? 'Private Team (Invite Only)' : 'Tim Privat (Pakai Kode)';
  static String get showCode => _en ? 'Show code' : 'Lihat kode';
  static String get hideCode => _en ? 'Hide code' : 'Sembunyikan kode';

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
      _en ? 'Create Challenge' : 'Buat Challenge';
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
      targetSatuan == 'jarak_m' ? 'KM' : (_en ? 'MIN' : 'MNT');

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
  static String get teamName => _en ? 'Team Name' : 'Nama Tim';
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
  static String get custom => _en ? 'Custom' : 'Kustom';

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

  // Team Challenges, Ketua Role, Active Slot & Opt-In Progress
  static String get teamChallengeTag => _en ? 'Team Challenge' : 'Challenge Tim';
  static String get soloChallengeTag => _en ? 'Solo' : 'Mandiri';
  static String get challengeTitleLabel =>
      _en ? 'Challenge title (optional)' : 'Judul challenge (opsional)';
  static String get challengeTitleHint =>
      _en ? 'e.g. Weekly Squad 5K' : 'Mis. Lari Mingguan Skuad 5K';
  static String get challengeScopeLabel =>
      _en ? 'Challenge type' : 'Jenis challenge';
  static String get challengeScopeTeam => _en ? 'Team (Coach)' : 'Tim (Coach)';
  static String get challengeScopeSolo => _en ? 'Solo' : 'Mandiri';
  static String get createTeamChallenge =>
      _en ? 'Create Team Challenge' : 'Buat Challenge Tim';
  static String get teamChallengesHeading =>
      _en ? 'Team Challenges' : 'Challenge Tim';
  static String get noTeamChallengesYet => _en
      ? 'No team challenges yet. Coach or Team Leader can create one.'
      : 'Belum ada challenge tim. Coach atau Ketua tim dapat membuatnya.';
  static String get activeSlotBadge => _en ? 'Active' : 'Aktif';
  static String get waitingSlotBadge => _en ? 'Waiting' : 'Menunggu';
  static String get chooseActiveChallenge =>
      _en ? 'Set Active' : 'Jadikan Aktif';
  static String get challengeActivatedMsg => _en
      ? 'Active challenge updated for upcoming activities.'
      : 'Challenge aktif diperbarui untuk aktivitas berikutnya.';
  static String get activeSlotHint => _en
      ? 'You can progress up to 1 active Team Challenge and 1 active Solo Challenge at a time.'
      : 'Kamu dapat menjalankan maks. 1 Challenge Tim dan 1 Challenge Mandiri secara bersamaan.';
  static String get filterTeam => _en ? 'Team Coach' : 'Tim Coach';
  static String get filterSolo => _en ? 'Solo' : 'Mandiri';

  // Ketua role promotion
  static String get roleKetua => _en ? 'Leader' : 'Ketua';
  static String get roleAnggota => _en ? 'Member' : 'Anggota';
  static String get promoteToKetua =>
      _en ? 'Promote to Leader' : 'Jadikan Ketua';
  static String get demoteToAnggota =>
      _en ? 'Set as Member' : 'Turunkan ke Anggota';
  static String roleUpdatedMsg(String name, String roleLabel) => _en
      ? '$name is now $roleLabel.'
      : '$name sekarang menjadi $roleLabel.';

  // Independent activity challenge selection
  static String get activeChallengesForSport =>
      _en ? 'Challenge Progress' : 'Progres Challenge';
  static String get activeChallengesAutoNote => _en
      ? 'Auto-selected for this sport. Turn off any challenge you want to skip.'
      : 'Dipilih otomatis untuk olahraga ini. Matikan jika tidak ingin dihitung.';
  static String get finishOptInTitle =>
      _en ? 'Save & Count Challenge Progress?' : 'Hitung Progres Challenge?';
  static String get finishOptInSubtitle => _en
      ? 'Choose which active challenges should receive progress from this session.'
      : 'Pilih challenge aktif yang mendapat progres dari aktivitas ini.';
  static String get finishSaveAndContinue =>
      _en ? 'Save Activity' : 'Simpan Aktivitas';
  static String get challengeProgressUpdated =>
      _en ? 'Challenge progress updated' : 'Progres challenge diperbarui';

  // Notifications
  static String get notificationsTitle => _en ? 'Notifications' : 'Notifikasi';
  static String get notificationsUnreadFilter =>
      _en ? 'Unread' : 'Belum dibaca';
  static String get notificationsAllFilter => _en ? 'All' : 'Semua';
  static String get markAllRead =>
      _en ? 'Mark all read' : 'Tandai semua terbaca';
  static String get noNotificationsEmpty =>
      _en ? 'No notifications yet.' : 'Belum ada notifikasi.';
  static String get viewChallenge =>
      _en ? 'View Challenge' : 'Lihat Challenge';

  // Challenge form (unified distance target + custom duration)
  static String get targetDistanceLabel =>
      _en ? 'DISTANCE TARGET' : 'TARGET JARAK';
  static String get targetDistanceHint => _en
      ? 'Total accumulated distance to reach within the challenge duration.'
      : 'Total akumulasi jarak yang harus dicapai selama durasi challenge.';
  static String get customDistanceTitle =>
      _en ? 'Custom distance (km)' : 'Jarak kustom (km)';
  static String get customDurationTitle =>
      _en ? 'Custom duration (days)' : 'Durasi kustom (hari)';
  static String get customDurationHint =>
      _en ? 'Number of days (e.g. 14)' : 'Jumlah hari (mis. 14)';
  static String get invalidCustomDuration =>
      _en ? 'Enter 1 to 365 days.' : 'Masukkan 1 sampai 365 hari.';
  static String customKmLabel(double km) {
    final v = km == km.truncateToDouble()
        ? '${km.toInt()}'
        : km.toStringAsFixed(1);
    return '$custom ($v km)';
  }

  static String customDaysLabel(int days) => _en
      ? (days == 1 ? '$custom (1 Day)' : '$custom ($days Days)')
      : '$custom ($days Hari)';

  static String get challengeCreated =>
      _en ? 'Challenge created.' : 'Challenge dibuat.';

  // Consistency fixes across Teams, Coach Board, Stats, Chat & Language
  static String get invalidTeamCode =>
      _en ? 'Invalid code. Try again.' : 'Kode salah. Coba lagi.';
  static String get enterTeamCodeFirst =>
      _en ? 'Enter the team code first.' : 'Masukkan kode tim dulu.';
  static String get teamTargetMeters =>
      _en ? 'Team Target (m)' : 'Target Tim (m)';
  static String get coachBoardTitle =>
      _en ? 'Coach Board' : 'Papan Coach';
  static String get kilometersUnit => _en ? 'Kilometers' : 'Kilometer';
  static String runsCount(int n) =>
      _en ? (n == 1 ? '1 Run' : '$n Runs') : '$n Lari';
  static String get unitMinutes => _en ? 'min' : 'menit';
  static String get langDefaultSub => _en ? 'Default' : 'Bawaan';
  static String get langAlternativeSub => _en ? 'Alternative' : 'Alternatif';
  static String get mapPlaceholderLabel => _en
      ? 'Route map — placeholder'
      : 'Peta rute — placeholder bebas hak cipta';
  static String coachEvaluationLine(String pct, bool passed) => _en
      ? 'Evaluation: $pct% • ${passed ? 'Passed' : 'In Progress'}'
      : 'Evaluasi: $pct% • ${passed ? 'Lulus Evaluasi' : 'Dalam Proses'}';

  // Enriched Home Dashboard
  static String get quickStartTitle => _en ? 'Quick Start' : 'Mulai Cepat';
  static String get weeklyOverviewTitle =>
      _en ? 'This Week' : 'Ringkasan Minggu Ini';
  static String get viewStats => _en ? 'View Stats' : 'Lihat Statistik';
  static String get avgPaceShort => _en ? 'Avg Pace' : 'Pace Rata-rata';
  static String get workoutsShort => _en ? 'Workouts' : 'Sesi';
  static String get activeChallengesTitle =>
      _en ? 'Active Challenges' : 'Challenge Aktif';
  static String get openChallengesTitle =>
      _en ? 'Available Challenges' : 'Challenge Tersedia';
  static String get browseChallengesCta =>
      _en ? 'Browse Challenges' : 'Jelajahi Challenge';
  static String get noChallengesHomeHint => _en
      ? 'Join a team or solo challenge to track targets alongside your workouts.'
      : 'Ikuti challenge tim atau solo untuk memantau target di setiap latihan.';
  static String get leaderboardSnapshotTitle =>
      _en ? 'Your Standing' : 'Peringkatmu';
  static String get openLeaderboardCta =>
      _en ? 'Open Leaderboard' : 'Buka Peringkat';
  static String get noRankingYet => _en
      ? 'Log a workout or pull to refresh your team & global ranking.'
      : 'Catat latihan atau tarik untuk memuat peringkat tim & globalmu.';
  static String get findClubsCta => _en ? 'Find Clubs' : 'Cari Klub';
  static List<String> get dayLetters => _en
      ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
      : const ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  // GitHub Release Updater
  static String checkForUpdates(String currentVer) => _en
      ? 'Check for Updates (v$currentVer)'
      : 'Periksa Pembaruan (v$currentVer)';
  static String get checkingUpdates => _en
      ? 'Checking GitHub Releases...'
      : 'Memeriksa rilis GitHub terbaru...';
  static String upToDateMsg(String currentVer) => _en
      ? 'Pacer is up to date (v$currentVer).'
      : 'Pacer sudah versi terbaru (v$currentVer).';
  static String get updateAvailableTitle =>
      _en ? 'Update Available' : 'Pembaruan Tersedia';
  static String updateAvailableSub(String currentVer, String latestTag) => _en
      ? 'A new GitHub release ($latestTag) is ready. You are on v$currentVer.'
      : 'Rilis GitHub baru ($latestTag) tersedia. Versi saat ini v$currentVer.';
  static String get releaseNotesTitle =>
      _en ? 'Release Notes' : 'Catatan Rilis';
  static String get noReleaseNotes => _en
      ? 'Download the latest release package from GitHub Releases.'
      : 'Unduh paket rilis terbaru dari GitHub Releases.';
  static String get downloadUpdateCta =>
      _en ? 'Download Update' : 'Unduh Pembaruan';
  static String get updateCheckFailed => _en
      ? 'Could not check for updates. Try again later.'
      : 'Gagal memeriksa pembaruan. Coba lagi nanti.';
  static String get updateOpenFailed =>
      _en ? 'Could not open download link.' : 'Gagal membuka tautan unduhan.';
  static String get skipVersionCta =>
      _en ? 'Skip This Version' : 'Lewati Versi Ini';
  static String get laterCta => _en ? 'Later' : 'Nanti';

  static String mismatchTitle(String suggestedJenis) => _en
      ? 'Looks like ${sportName(suggestedJenis)}?'
      : 'Terdeteksi ${sportName(suggestedJenis)}?';
  static String mismatchSubtitle(String currentJenis, String suggestedJenis) =>
      _en
      ? 'Motion matches ${sportName(suggestedJenis)} better than ${sportName(currentJenis)}.'
      : 'Pergerakan lebih cocok ${sportName(suggestedJenis)} daripada ${sportName(currentJenis)}.';
  static String switchToSportCta(String suggestedJenis) => _en
      ? 'Switch to ${sportName(suggestedJenis)}'
      : 'Ubah ke ${sportName(suggestedJenis)}';
  static String keepSportCta(String currentJenis) => _en
      ? 'Keep ${sportName(currentJenis)}'
      : 'Tetap ${sportName(currentJenis)}';
  static String sportSwitchedNotice(String newJenis) => _en
      ? 'Switched activity to ${sportName(newJenis)}'
      : 'Aktivitas diubah ke ${sportName(newJenis)}';

  static String get vehicleDetectedTitle => _en
      ? 'Vehicle Speed Detected'
      : 'Kecepatan Kendaraan Terdeteksi';
  static String get vehicleDetectedSubtitle => _en
      ? 'Speed exceeds athletic pace. Pause tracking while in a vehicle.'
      : 'Kecepatan melebihi batas olahraga. Jeda saat berkendara.';
  static String get pauseTrackingCta => _en ? 'Pause' : 'Jeda';
  static String get dismissPromptCta => _en ? 'Ignore' : 'Abaikan';

  static String validationBadgeLabel(
    String? status, {
    String? suggestedSport,
  }) => switch (status) {
    'flagged_vehicle' => _en ? 'Vehicle Flagged' : 'Kendaraan',
    'flagged_ride' || 'flagged_mismatch' =>
      suggestedSport != null
          ? (_en
              ? 'Check: ${sportName(suggestedSport)}'
              : 'Cek: ${sportName(suggestedSport)}')
          : (_en ? 'Mismatch' : 'Tidak Sesuai'),
    'reclassified' => _en ? 'Reclassified' : 'Diubah Jenis',
    _ => '',
  };

  static String finishMismatchTitle(String? suggestedJenis) =>
      suggestedJenis != null
      ? (_en
            ? 'Looks like ${sportName(suggestedJenis)}'
            : 'Terlihat seperti ${sportName(suggestedJenis)}')
      : (_en ? 'Activity check flagged' : 'Aktivitas perlu ditinjau');

  static String finishMismatchBody(
    String currentJenis,
    String? suggestedJenis,
  ) => suggestedJenis != null
      ? (_en
            ? 'Motion matched ${sportName(suggestedJenis)} instead of ${sportName(currentJenis)}. Reclassify so stats and challenges stay accurate.'
            : 'Sinyal gerak lebih cocok ${sportName(suggestedJenis)} daripada ${sportName(currentJenis)}. Ubah jenis agar statistik & tantangan akurat.')
      : (_en
            ? 'Speed or cadence diverged from ${sportName(currentJenis)}.'
            : 'Kecepatan atau kadensi tidak sesuai dengan ${sportName(currentJenis)}.');

  static String get finishVehicleTitle => _en
      ? 'Excluded: Vehicle Detected'
      : 'Dikecualikan: Terdeteksi Kendaraan';
  static String get finishVehicleBody => _en
      ? 'Motorized vehicle speed was detected, so this session is excluded from challenge progress and streaks.'
      : 'Terdeteksi kecepatan kendaraan bermotor sehingga sesi ini dikecualikan dari progres tantangan dan streak.';
  static String get deleteFlaggedActivityCta =>
      _en ? 'Delete Activity' : 'Hapus Aktivitas';
  static String get deleteFlaggedConfirmTitle => _en
      ? 'Delete this flagged activity?'
      : 'Hapus aktivitas yang ditandai ini?';
  static String get deleteFlaggedConfirmBody => _en
      ? 'This removes the activity from history and syncs deletion.'
      : 'Aktivitas akan dihapus dari riwayat dan sinkronisasi.';
  static String get flaggedActivityDeletedNotice =>
      _en ? 'Activity deleted' : 'Aktivitas dihapus';

  static String get streakRuleSummary => _en
      ? 'Daily minimum: 5 min & 0.50 km (1.00 km cycling)'
      : 'Syarat harian: min. 5 mnt & 0,50 km (1,00 km bersepeda)';

  static String streakTodayProgress(int durasiS, double quotaRatio) {
    final pct = (quotaRatio.clamp(0.0, 1.0) * 100).round();
    final mins = durasiS ~/ 60;
    final secs = durasiS % 60;
    return _en
        ? 'Today: ${mins}m ${secs}s / 5m • Distance quota $pct%'
        : 'Hari ini: ${mins}m ${secs}d / 5m • Kuota jarak $pct%';
  }

  static String get streakRequirementsTitle =>
      _en ? 'Streak Requirements' : 'Syarat Streak';
  static String get streakReqDuration => _en
      ? 'Complete at least 5 minutes of active workout per day'
      : 'Minimal 5 menit olahraga aktif per hari';
  static String get streakReqDistance => _en
      ? 'Cover at least 0.50 km (Walk / Jog / Run) or 1.00 km (Cycling)'
      : 'Minimal 0,50 km (Jalan / Joging / Lari) atau 1,00 km (Bersepeda)';
  static String get streakReqIntegrity => _en
      ? 'Valid sessions only (vehicle & unresolved mismatch activities excluded)'
      : 'Hanya aktivitas valid (kendaraan & ketidaksesuaian dikecualikan)';
  static String get streakTodayCompleted => _en
      ? 'Today\'s streak requirement completed'
      : 'Syarat streak hari ini terpenuhi';

  static String get streakShortConfirmTitle =>
      _en ? 'Too short for today\'s streak' : 'Belum memenuhi syarat streak';
  static String streakShortConfirmBody(
    String jenis,
    int elapsedS,
    double distM,
  ) {
    final minKm = (jenis == 'bersepeda' ? 1.00 : 0.50).toStringAsFixed(2);
    final kmDone = (distM / 1000).toStringAsFixed(2);
    final minsDone = elapsedS ~/ 60;
    final secsDone = elapsedS % 60;
    return _en
        ? 'Current: ${minsDone}m ${secsDone}s & $kmDone km. Streak requires at least 5m & $minKm km (${sportName(jenis)}). Keep going to count today, or save anyway without extending your streak.'
        : 'Saat ini: ${minsDone}m ${secsDone}d & $kmDone km. Streak butuh min. 5m & $minKm km (${sportName(jenis)}). Lanjutkan agar dihitung hari ini, atau tetap simpan tanpa menambah streak.';
  }

  static String get keepGoingCta => _en ? 'Keep Going' : 'Lanjutkan';
  static String get finishAnywayCta => _en ? 'Finish Anyway' : 'Tetap Selesai';

  static String get finishStreakNotExtendedTitle =>
      _en ? 'Streak Not Extended' : 'Streak Belum Bertambah';
  static String finishStreakNotExtendedBody(
    String jenis,
    int durasiS,
    double jarakM,
  ) {
    final minKm = (jenis == 'bersepeda' ? 1.00 : 0.50).toStringAsFixed(2);
    final kmDone = (jarakM / 1000).toStringAsFixed(2);
    final minsDone = durasiS ~/ 60;
    final secsDone = durasiS % 60;
    return _en
        ? 'Recorded ${minsDone}m ${secsDone}s & $kmDone km. A valid session (or combined daily total) needs at least 5m & $minKm km (${sportName(jenis)}) to extend today\'s streak.'
        : 'Tercatat ${minsDone}m ${secsDone}d & $kmDone km. Minimal butuh 5m & $minKm km (${sportName(jenis)}) untuk menambah streak hari ini.';
  }

  // Super Admin & Coach Invite
  static String get adminConsole =>
      _en ? 'Super Admin Console' : 'Konsol Super Admin';
  static String get redeemCoachCode =>
      _en ? 'Redeem Coach Code' : 'Klaim Kode Coach';
  static String get redeemCoachCodeHint =>
      _en ? 'Enter invite code (e.g. COACH-...)' : 'Masukkan kode undangan';
  static String get redeemCoachSuccess => _en
      ? 'Your account is now upgraded to Coach.'
      : 'Akun Anda kini ditingkatkan menjadi Coach.';
  static String get redeemCoachSubmit => _en ? 'Activate' : 'Aktifkan';
  static String get adminOverviewTab => _en ? 'Overview' : 'Ringkasan';
  static String get adminUsersTab => _en ? 'Users' : 'Pengguna';
  static String get adminFlaggedTab => _en ? 'Flagged' : 'Ditandai';
  static String get adminAuditTab => _en ? 'Audit' : 'Audit';
  static String get adminSearchUsersHint =>
      _en ? 'Search name, region, or ID…' : 'Cari nama, wilayah, atau ID…';
  static String get adminCoachInvitesTitle =>
      _en ? 'Coach Invite Codes' : 'Kode Undangan Coach';
  static String get adminGenerateCodeCta =>
      _en ? 'Generate Code' : 'Buat Kode';
  static String get adminCodeCopied =>
      _en ? 'Invite code copied' : 'Kode undangan disalin';
  static String get adminChangeRoleTitle =>
      _en ? 'Change Account Role' : 'Ubah Peran Akun';
  static String get adminRoleUpdatedNotice =>
      _en ? 'Role updated' : 'Peran diperbarui';
  static String get adminNoFlaggedRuns => _en
      ? 'No flagged activities awaiting review.'
      : 'Tidak ada aktivitas ditandai saat ini.';
  static String get adminNoAuditEntries =>
      _en ? 'No admin actions recorded yet.' : 'Belum ada catatan audit.';
  static String get adminVerifyCta => _en ? 'Verify' : 'Verifikasi';
  static String get adminReclassifyCta => _en ? 'Reclassify' : 'Ubah Jenis';
  static String get adminExcludeCta => _en ? 'Exclude' : 'Kecualikan';
  static String get adminSaveRoleCta => _en ? 'Save Role' : 'Simpan Peran';
  static String get adminRetryCta => _en ? 'Retry' : 'Coba Lagi';

  // Demo & Session Reset
  static String get tryDemoAccount =>
      _en ? 'Try Demo Account' : 'Coba Akun Demo';
  static String get demoAccountTitle =>
      _en ? 'Demo Account' : 'Akun Demo';
  static String get demoModeSubtitle => _en
      ? 'demo@pacer.local · Wipes on logout'
      : 'demo@pacer.local · Dihapus saat keluar';
  static String get errUsernameRequired =>
      _en ? 'Username is required.' : 'Nama pengguna wajib diisi.';
  static String get errUsernameNoSpaces => _en
      ? 'Username cannot contain spaces.'
      : 'Nama pengguna tidak boleh memakai spasi.';
  static String get errUsernameTooShort => _en
      ? 'Username must be at least 3 characters.'
      : 'Nama pengguna minimal 3 karakter.';

  static String usernameError(UsernameError err) => switch (err) {
    UsernameError.required => errUsernameRequired,
    UsernameError.hasWhitespace => errUsernameNoSpaces,
    UsernameError.tooShort => errUsernameTooShort,
  };

  // User Deletion Controls
  static String get deleteAction => _en ? 'Delete' : 'Hapus';
  static String get deleteActivityTitle =>
      _en ? 'Delete activity?' : 'Hapus aktivitas?';
  static String get deleteActivityBody => _en
      ? 'This removes the workout, route, and challenge progress associated with it.'
      : 'Ini akan menghapus sesi latihan, rute, serta progres tantangan terkait.';
  static String get activityDeletedNotice =>
      _en ? 'Activity deleted' : 'Aktivitas dihapus';
  static String get deleteMessageAction =>
      _en ? 'Delete message' : 'Hapus pesan';
  static String get deleteMessageTitle =>
      _en ? 'Delete message?' : 'Hapus pesan?';
  static String get deleteMessageBody => _en
      ? 'Remove this message from the team chat?'
      : 'Hapus pesan ini dari obrolan tim?';
  static String get youLabel => _en ? 'You' : 'Kamu';
  static String get clearAllNotifications =>
      _en ? 'Clear all' : 'Hapus semua';
  static String get clearNotificationsTitle =>
      _en ? 'Clear all notifications?' : 'Hapus semua notifikasi?';
  static String get clearNotificationsBody => _en
      ? 'Remove every notification from your inbox?'
      : 'Hapus seluruh notifikasi dari kotak masuk?';
  static String get notificationsClearedNotice =>
      _en ? 'Notifications cleared' : 'Semua notifikasi dihapus';
  static String get deleteAccountAction =>
      _en ? 'Delete Account' : 'Hapus Akun';
  static String get deleteAccountTitle =>
      _en ? 'Delete your account?' : 'Hapus akun permanen?';
  static String get deleteAccountBody => _en
      ? 'This permanently deletes your profile, run history, routes, and team data. Type DELETE to confirm.'
      : 'Ini menghapus permanen profil, riwayat lari, rute, dan data tim Anda. Ketik DELETE untuk konfirmasi.';
  static String get deleteAccountConfirmWord => 'DELETE';
  static String get accountDeletedNotice =>
      _en ? 'Account deleted' : 'Akun berhasil dihapus';
}
