/* Pacer static download page controller:
 * - Bilingual UI (Indonesian default, English alternate) with persisted switcher
 * - Live GitHub Releases fetcher for Lemondeft/pacer with 10-minute cache
 * - Safe DOM-only markdown changelog renderer (createElement and textContent only)
 * - Interactive QR switcher (Evergreen Download Page vs Direct Latest APK)
 * - Theme toggle, mobile menu drawer, and keyboard-accessible screenshot tabs
 */
(function () {
  'use strict';

  var REPO = 'Lemondeft/pacer';
  var RELEASES_API = 'https://api.github.com/repos/' + REPO + '/releases?per_page=8';
  var RELEASES_WEB = 'https://github.com/' + REPO + '/releases';
  var DOWNLOAD_PAGE_URL = 'https://lemondeft.github.io/pacer/';
  var CACHE_KEY = 'pacer.release_cache_v1';
  var LANG_KEY = 'pacer.lang';
  var CACHE_TTL_MS = 10 * 60 * 1000;

  var TRANSLATIONS = {
    id: {
      pageTitle: 'Unduh Pacer untuk Android | Pelacak Olahraga Offline-First',
      metaDescription: 'Unduh APK Android Pacer terbaru langsung dari GitHub Releases. Pelacak GPS offline-first untuk lari, joging, bersepeda, dan berjalan.',
      skipLink: 'Lompat ke konten unduhan',
      homeAria: 'Beranda Unduh Pacer',
      navPrimaryAria: 'Navigasi utama',
      navMobileAria: 'Navigasi seluler',
      navDownload: 'Unduh',
      navQr: 'QR & Checksum',
      navReleases: 'Rilis',
      navGithub: 'GitHub',
      navGithubRepo: 'Repositori GitHub',
      menuBtn: 'Menu',
      themeDark: 'Gelap',
      themeLight: 'Terang',
      themeToLightAria: 'Beralih ke tema terang',
      themeToDarkAria: 'Beralih ke tema gelap',
      langToggleAria: 'Bahasa Indonesia aktif, beralih ke English',
      heroTitle: 'Unduh Pacer untuk Android',
      heroSubtitle: 'Pelacak GPS offline-first untuk lari, joging, bersepeda, dan berjalan. Mencatat rute langsung ke SQLite lokal, sinkron ke Supabase saat online, dan dirilis resmi melalui GitHub Releases.',
      loadingMsg: 'Memeriksa rilis GitHub terbaru untuk Lemondeft/pacer...',
      emptyTitle: 'Belum ada file APK Android pada rilis terbaru ini.',
      emptyDesc: 'Buka GitHub Releases untuk melihat rilis sebelumnya atau arsip kode sumber.',
      errorTitle: 'Gagal mengambil metadata rilis terbaru dari GitHub saat ini.',
      errorDefaultDetail: 'Kamu tetap bisa membuka halaman rilis GitHub terbaru langsung lewat tombol di bawah.',
      errorRateLimit: 'Batas permintaan GitHub API tercapai pada jaringan ini. Gunakan tombol di bawah untuk membuka GitHub Releases langsung.',
      errorHttpPrefix: 'GitHub mengembalikan status HTTP ',
      errorHttpSuffix: '. Gunakan tombol di bawah untuk membuka GitHub Releases langsung.',
      errorTimeout: 'Koneksi ke GitHub melewati batas waktu. Periksa internet kamu atau buka GitHub Releases langsung.',
      retryBtn: 'Coba cek GitHub lagi',
      downloadBtnDefault: 'Unduh APK Android',
      downloadBtnFallback: 'Buka GitHub Releases',
      allReleasesBtn: 'Semua Rilis GitHub',
      installSummary: 'Cara memasang APK di Android',
      installStep1a: 'Ketuk ',
      installStep1Strong: 'Unduh APK Android',
      installStep1b: ' di atas (atau pindai kode QR di bawah memakai kamera ponsel kamu).',
      installStep2a: 'Buka file ',
      installStep2b: ' dari daftar unduhan peramban lalu izinkan ',
      installStep2Strong: 'Instal aplikasi tidak dikenal',
      installStep2c: ' saat Android meminta konfirmasi.',
      installStep3a: 'Buka Pacer. Kamu bisa masuk, mendaftar akun baru, atau memilih ',
      installStep3Strong: 'Coba Akun Demo',
      installStep3b: ' untuk mencoba sandbox SQLite offline tanpa perlu mendaftar.',
      demoNoteA: 'Ingin mencoba dulu sebelum membuat akun? Buka Pacer dan ketuk ',
      demoNoteStrong: 'Coba Akun Demo',
      demoNoteB: ' di layar selamat datang untuk sandbox SQLite lokal berisi data contoh yang otomatis bersih saat keluar.',
      screenTablistAria: 'Tangkapan layar aplikasi Pacer',
      tabDashboard: 'Beranda',
      tabTracking: 'Pelacakan',
      tabThemes: 'Tema',
      qrTitle: 'Pindai dari ponsel',
      qrSubtitle: 'Arahkan kamera Android ke kode QR ini untuk membuka halaman unduhan (selalu versi terbaru) atau ganti ke tautan langsung APK rilis saat ini.',
      qrGroupAria: 'Tujuan kode QR',
      qrModePage: 'Halaman Unduh',
      qrModeApk: 'APK Langsung',
      qrCopyLink: 'Salin tautan',
      qrSaveSvg: 'Simpan SVG',
      qrPrintPng: 'Cetak PNG',
      qrAriaPagePrefix: 'Kode QR untuk halaman unduh Pacer ',
      qrAriaApkPrefix: 'Kode QR untuk unduhan langsung APK Pacer (',
      copiedLink: 'Tautan berhasil disalin.',
      savedPrefix: 'Tersimpan: ',
      clipboardBlocked: 'Akses clipboard diblokir. Pilih dan salin teks di atas secara manual.',
      verifyTitle: 'Verifikasi paket & kemampuan',
      verifySubtitle: 'Setiap rilis APK dipublikasikan dari repositori publik lengkap dengan digest SHA-256 pada metadata GitHub Releases.',
      shaHeading: 'Digest SHA-256 APK',
      copyShaBtn: 'Salin SHA-256',
      copiedSha: 'Digest SHA-256 berhasil disalin.',
      shaLoading: 'Memuat digest dari GitHub Releases...',
      shaUnavailable: 'Tidak tersedia saat offline atau terkena batas permintaan.',
      shaNoneRelease: 'Belum ada rilis terpublikasi.',
      shaNoneApk: 'Tidak ada digest APK pada rilis ini.',
      shaMissing: 'Digest SHA-256 tidak dipublikasikan untuk rilis ini.',
      specSportsTitle: 'Olahraga didukung',
      specSportsDesc: 'Lari, Joging, Bersepeda, dan Berjalan dengan klasifikasi anti-cheat 5 lapis serta pelacakan latar belakang saat layar mati.',
      specOfflineTitle: 'Arsitektur offline',
      specOfflineDesc: 'Menyimpan aktivitas dan draf GPS langsung ke SQLite lokal lalu mengantrekan sinkronisasi ke Supabase begitu koneksi kembali.',
      specMapsTitle: 'Peta & klub',
      specMapsDesc: 'Peta vektor OpenFreeMap (gaya Terang dan Gelap), tim privat berkode undangan, chat tim realtime, tantangan individu dan tim, serta papan nilai pelatih.',
      specThemesTitle: 'Tema & bahasa',
      specThemesDesc: 'Tampilan Gelap, Terang, dan Sistem, 6 palet terinspirasi desktop (Argon, KDE Breeze, Mint-Y Cinnamon, GNOME Adwaita, Ubuntu Yaru, Arch Nord), Bahasa Indonesia dan Inggris.',
      specLicenseTitle: 'Lisensi & sumber',
      specLicenseDesc: 'GNU General Public License v3.0. Seluruh kode aplikasi Flutter dan migrasi SQL Supabase terbuka untuk publik.',
      readLicenseLink: 'Baca Lisensi GPL-3.0',
      browseSourceLink: 'Lihat Kode di GitHub',
      drawioLink: 'Diagram Draw.io',
      figmaLink: 'Desain Figma',
      changelogTitle: 'Pembaruan pada rilis terbaru',
      changelogSubtitleDefault: 'Diambil langsung dari GitHub Releases.',
      changelogPublishedWord: ' diterbitkan ',
      changelogOnGithub: ' di GitHub Releases.',
      viewFullRelease: 'Lihat rilis lengkap di GitHub',
      changelogLoading: 'Memuat catatan rilis...',
      changelogEmpty: 'Tidak ada catatan rilis yang dipublikasikan untuk tag ini.',
      changelogError: 'Catatan rilis belum bisa dimuat saat ini. Buka GitHub Releases untuk membaca daftar perubahan.',
      recentTitle: 'Rilis terbaru',
      recentSubtitle: 'Tautan langsung ke APK Android dan build desktop Linux terbaru.',
      recentLoading: 'Memuat arsip rilis...',
      recentEmpty: 'Belum ada rilis yang dipublikasikan.',
      recentError: 'Arsip belum tersedia saat ini. Lihat semua versi langsung di GitHub.',
      sourceReleaseGithub: 'Rilis kode sumber di GitHub',
      footerLicense: '(Lemondeft/pacer), didistribusikan di bawah lisensi GPL-3.0.',
      footerRepo: 'Repositori',
      footerReleases: 'Rilis',
      footerIssues: 'Laporkan Masalah',
      latestWord: 'terbaru',
      releaseFallbackLabel: 'Rilis',
    },
    en: {
      pageTitle: 'Download Pacer for Android | Offline-First Sports Tracker',
      metaDescription: 'Download the latest Pacer Android APK directly from GitHub Releases. Offline-first GPS tracking for running, jogging, cycling, and walking.',
      skipLink: 'Skip to download content',
      homeAria: 'Pacer Download Home',
      navPrimaryAria: 'Primary navigation',
      navMobileAria: 'Mobile navigation',
      navDownload: 'Download',
      navQr: 'QR & Checksum',
      navReleases: 'Releases',
      navGithub: 'GitHub',
      navGithubRepo: 'GitHub Repository',
      menuBtn: 'Menu',
      themeDark: 'Dark',
      themeLight: 'Light',
      themeToLightAria: 'Switch to light theme',
      themeToDarkAria: 'Switch to dark theme',
      langToggleAria: 'English active, switch to Bahasa Indonesia',
      heroTitle: 'Download Pacer for Android',
      heroSubtitle: 'Offline-first GPS tracker for running, jogging, cycling, and walking. Records routes locally to SQLite, syncs with Supabase when online, and ships straight from GitHub Releases.',
      loadingMsg: 'Checking the latest published GitHub release for Lemondeft/pacer...',
      emptyTitle: 'No Android APK is attached to the latest release yet.',
      emptyDesc: 'Open GitHub Releases to browse previous builds or source archives.',
      errorTitle: 'Could not fetch live release metadata from GitHub right now.',
      errorDefaultDetail: 'You can still open the latest GitHub release directly using the button below.',
      errorRateLimit: 'GitHub API rate limit reached for this network. Use the direct button below to open GitHub Releases.',
      errorHttpPrefix: 'GitHub returned HTTP ',
      errorHttpSuffix: '. Use the button below to open GitHub Releases directly.',
      errorTimeout: 'The request to GitHub timed out. Check your connection or open GitHub Releases directly.',
      retryBtn: 'Retry GitHub check',
      downloadBtnDefault: 'Download Android APK',
      downloadBtnFallback: 'Open GitHub Releases',
      allReleasesBtn: 'All GitHub Releases',
      installSummary: 'How to install the APK on Android',
      installStep1a: 'Tap ',
      installStep1Strong: 'Download Android APK',
      installStep1b: ' above (or scan the QR code below from your phone camera).',
      installStep2a: 'Open the downloaded ',
      installStep2b: ' file from your browser downloads and allow ',
      installStep2Strong: 'Install unknown apps',
      installStep2c: ' for your browser when Android prompts.',
      installStep3a: 'Launch Pacer. You can sign in, register a new account, or select ',
      installStep3Strong: 'Try Demo Account',
      installStep3b: ' to test a pre-populated offline SQLite sandbox without signing up.',
      demoNoteA: 'Want to test before creating an account? Launch Pacer and tap ',
      demoNoteStrong: 'Try Demo Account',
      demoNoteB: ' on the welcome screen for a pre-populated local SQLite sandbox that resets cleanly on logout.',
      screenTablistAria: 'Pacer app screenshots',
      tabDashboard: 'Dashboard',
      tabTracking: 'Live GPS',
      tabThemes: 'Themes',
      qrTitle: 'Scan on your phone',
      qrSubtitle: 'Point your Android camera at the code to open this download page (always up to date) or switch to the direct APK link for the current release.',
      qrGroupAria: 'QR code target',
      qrModePage: 'Download Page',
      qrModeApk: 'Direct APK',
      qrCopyLink: 'Copy link',
      qrSaveSvg: 'Save SVG',
      qrPrintPng: 'Print PNG',
      qrAriaPagePrefix: 'QR code for Pacer download page ',
      qrAriaApkPrefix: 'QR code for direct Pacer APK download (',
      copiedLink: 'Copied link to clipboard.',
      savedPrefix: 'Saved ',
      clipboardBlocked: 'Clipboard access blocked. Select and copy the text above.',
      verifyTitle: 'Verify package & capabilities',
      verifySubtitle: 'Every release APK is published from the public repository with its SHA-256 digest attached in GitHub Releases metadata.',
      shaHeading: 'APK SHA-256 Digest',
      copyShaBtn: 'Copy SHA-256',
      copiedSha: 'Copied SHA-256 digest.',
      shaLoading: 'Loading digest from GitHub Releases...',
      shaUnavailable: 'Unavailable while offline or rate-limited.',
      shaNoneRelease: 'No published release available yet.',
      shaNoneApk: 'No APK digest attached to this release.',
      shaMissing: 'SHA-256 digest was not published for this release.',
      specSportsTitle: 'Supported sports',
      specSportsDesc: 'Outdoor Running, Jogging, Cycling, and Walking with 5-layer anti-cheat classification and screen-off foreground tracking.',
      specOfflineTitle: 'Offline architecture',
      specOfflineDesc: 'Writes workouts and GPS drafts straight to local SQLite and drains queued mutations to Supabase once connectivity returns.',
      specMapsTitle: 'Maps & clubs',
      specMapsDesc: 'OpenFreeMap vector tiles (Light and Dark styles), invite-code teams, realtime team chat, solo and team challenges, and coach grading boards.',
      specThemesTitle: 'Themes & languages',
      specThemesDesc: 'Dark, Light, and System appearance, 6 desktop-inspired palettes (Argon, KDE Breeze, Mint-Y Cinnamon, GNOME Adwaita, Ubuntu Yaru, Arch Nord), Indonesian and English.',
      specLicenseTitle: 'License & source',
      specLicenseDesc: 'GNU General Public License v3.0. Full Flutter client and Supabase SQL migrations are public.',
      readLicenseLink: 'Read GPL-3.0 License',
      browseSourceLink: 'Browse GitHub Source',
      drawioLink: 'Draw.io Diagrams',
      figmaLink: 'Figma Design',
      changelogTitle: 'What changed in the latest build',
      changelogSubtitleDefault: 'Pulled live from GitHub Releases.',
      changelogPublishedWord: ' published ',
      changelogOnGithub: ' on GitHub Releases.',
      viewFullRelease: 'View full release on GitHub',
      changelogLoading: 'Loading release notes...',
      changelogEmpty: 'No release notes were published for this tag.',
      changelogError: 'Release notes could not be loaded right now. Open GitHub Releases to view the changelog.',
      recentTitle: 'Recent releases',
      recentSubtitle: 'Direct links to recent Android APKs and Linux desktop builds.',
      recentLoading: 'Loading release archive...',
      recentEmpty: 'No published releases found yet.',
      recentError: 'Archive unavailable right now. Browse all versions directly on GitHub.',
      sourceReleaseGithub: 'Source release on GitHub',
      footerLicense: '(Lemondeft/pacer), distributed under GPL-3.0.',
      footerRepo: 'Repository',
      footerReleases: 'Releases',
      footerIssues: 'Report an Issue',
      latestWord: 'latest',
      releaseFallbackLabel: 'Release',
    },
  };

  var SCREENSHOTS = {
    dashboard: {
      src: 'screenshots/dashboard.png',
      alt: {
        id: 'Tampilan beranda Pacer di Android menampilkan streak aktif 5 hari, tombol cepat Lari, Joging, Bersepeda, dan Berjalan, grafik jarak mingguan, serta bilah navigasi bawah.',
        en: 'Pacer Android dashboard showing active 5-day streak, quick-start sport buttons for Running, Jogging, Cycling, and Walking, weekly distance bar chart, and floating bottom navigation pill.',
      },
      caption: {
        id: 'Layar beranda: kartu streak 5 hari, 4 pintasan olahraga, dan grafik jarak mingguan.',
        en: 'Home dashboard: 5-day streak card, 4 sport quick-starts, and weekly volume chart.',
      },
    },
    tracking: {
      src: 'screenshots/tracking.png',
      alt: {
        id: 'Layar pelacakan GPS langsung Pacer menampilkan peta vektor gelap OpenFreeMap, lintasan rute terekam, jarak 0,73 km, pace rata-rata, durasi, kalori, dan tombol Jeda.',
        en: 'Pacer live GPS workout screen displaying OpenFreeMap dark vector grid, recorded route loop, 0.73 km live distance, average pace, duration, calories, and Pause button.',
      },
      caption: {
        id: 'Pelacakan GPS langsung: rute peta OpenFreeMap, pace, durasi, kalori, dan perekaman layar mati.',
        en: 'Live GPS tracking: OpenFreeMap route path, pace, duration, calories, and foreground recording.',
      },
    },
    themes: {
      src: 'screenshots/themes.png',
      alt: {
        id: 'Pengaturan tema Pacer menampilkan mode Sistem, Terang, dan Gelap serta palet warna desktop klasik termasuk Pacer Argon, KDE Breeze, Mint-Y Cinnamon, GNOME Adwaita, dan Ubuntu Yaru.',
        en: 'Pacer theme settings showing System, Light, and Dark modes plus classic Linux desktop palettes including Pacer Argon, KDE Breeze, Mint-Y Cinnamon, GNOME Adwaita, and Ubuntu Yaru.',
      },
      caption: {
        id: 'Pengaturan tampilan: mode Sistem, Terang, Gelap, dan 6 palet warna terinspirasi desktop.',
        en: 'Appearance settings: System, Light, Dark modes, and 6 desktop-inspired palettes.',
      },
    },
  };

  var state = {
    lang: 'id',
    statusMode: 'loading',
    lastReleases: null,
    lastError: null,
    latestApkUrl: null,
    latestTag: null,
    latestSha256: null,
    activeScreen: 'dashboard',
    qrMode: 'page',
    currentQrSvg: null,
    currentQrUrl: DOWNLOAD_PAGE_URL,
  };

  function $(id) {
    return document.getElementById(id);
  }

  function t(key) {
    var dict = TRANSLATIONS[state.lang] || TRANSLATIONS.id;
    return dict[key] !== undefined ? dict[key] : TRANSLATIONS.id[key];
  }

  function resolveInitialLang() {
    try {
      if (typeof URLSearchParams !== 'undefined') {
        var q = new URLSearchParams(window.location.search).get('lang');
        if (q === 'en' || q === 'id') return q;
      }
      var saved = localStorage.getItem(LANG_KEY);
      if (saved === 'en' || saved === 'id') return saved;
    } catch (_) {}
    return 'id';
  }

  function formatBytes(bytes) {
    if (typeof bytes !== 'number' || !isFinite(bytes) || bytes <= 0) return '';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  }

  function formatDate(iso) {
    if (!iso) return '';
    var d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    try {
      return new Intl.DateTimeFormat(state.lang === 'id' ? 'id-ID' : 'en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      }).format(d);
    } catch (_) {
      return d.toISOString().slice(0, 10);
    }
  }

  function stripEmDash(text) {
    return String(text || '').replace(/\s*\u2014\s*/g, ': ');
  }

  function pickApkAsset(assets) {
    if (!Array.isArray(assets)) return null;
    var found = null;
    for (var i = 0; i < assets.length; i++) {
      var a = assets[i];
      if (!a || !a.name || !a.browser_download_url) continue;
      var lower = String(a.name).toLowerCase();
      if (!lower.endsWith('.apk')) continue;
      found = a;
      if (lower.indexOf('android.apk') !== -1 || lower === 'app-release.apk') break;
    }
    return found;
  }

  function pickLinuxAsset(assets) {
    if (!Array.isArray(assets)) return null;
    for (var i = 0; i < assets.length; i++) {
      var a = assets[i];
      if (!a || !a.name || !a.browser_download_url) continue;
      var lower = String(a.name).toLowerCase();
      if (lower.endsWith('.tar.gz') || lower.endsWith('.appimage') || lower.endsWith('.deb')) {
        return a;
      }
    }
    return null;
  }

  /* Safe DOM markdown renderer (headings, lists, bold, inline code). */
  function appendInlineMarkdown(parent, text) {
    var clean = stripEmDash(text);
    var pattern = /(\*\*([^*]+)\*\*|`([^`]+)`)/g;
    var last = 0;
    var match;
    while ((match = pattern.exec(clean)) !== null) {
      if (match.index > last) {
        parent.appendChild(document.createTextNode(clean.slice(last, match.index)));
      }
      if (match[2] !== undefined) {
        var strong = document.createElement('strong');
        strong.textContent = match[2];
        parent.appendChild(strong);
      } else if (match[3] !== undefined) {
        var code = document.createElement('code');
        code.textContent = match[3];
        parent.appendChild(code);
      }
      last = pattern.lastIndex;
    }
    if (last < clean.length) {
      parent.appendChild(document.createTextNode(clean.slice(last)));
    }
  }

  function renderReleaseNotes(container, markdown) {
    if (!container) return;
    container.textContent = '';
    var text = String(markdown || '').trim();
    if (!text) {
      var empty = document.createElement('p');
      empty.className = 'pacer-muted';
      empty.textContent = t('changelogEmpty');
      container.appendChild(empty);
      return;
    }

    var lines = text.split(/\r?\n/);
    var activeList = null;

    function flushList() {
      if (activeList) {
        container.appendChild(activeList);
        activeList = null;
      }
    }

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (!line) {
        flushList();
        continue;
      }
      if (line.indexOf('### ') === 0) {
        flushList();
        var h3 = document.createElement('h3');
        h3.className = 'text-base';
        appendInlineMarkdown(h3, line.slice(4));
        container.appendChild(h3);
      } else if (line.indexOf('## ') === 0) {
        flushList();
        var h2 = document.createElement('h3');
        h2.className = 'text-lg';
        appendInlineMarkdown(h2, line.slice(3));
        container.appendChild(h2);
      } else if (line.indexOf('- ') === 0 || line.indexOf('* ') === 0) {
        if (!activeList) activeList = document.createElement('ul');
        var li = document.createElement('li');
        appendInlineMarkdown(li, line.slice(2));
        activeList.appendChild(li);
      } else {
        flushList();
        var p = document.createElement('p');
        appendInlineMarkdown(p, line);
        container.appendChild(p);
      }
    }
    flushList();
  }

  function formatErrorMessage(errInfo) {
    if (!errInfo) return t('errorDefaultDetail');
    if (errInfo.kind === 'timeout') return t('errorTimeout');
    if (errInfo.kind === 'rate_limit') return t('errorRateLimit');
    if (errInfo.kind === 'http' && errInfo.status) {
      return t('errorHttpPrefix') + errInfo.status + t('errorHttpSuffix');
    }
    return t('errorDefaultDetail');
  }

  function setStatusView(mode, errInfo) {
    state.statusMode = mode;
    if (mode === 'error') {
      state.lastError = errInfo || { kind: 'default' };
    }
    var ids = ['loading', 'ready', 'empty', 'error'];
    for (var i = 0; i < ids.length; i++) {
      var el = $('state-' + ids[i]);
      if (el) el.hidden = ids[i] !== mode;
    }
    if (mode === 'error' && $('error-detail')) {
      $('error-detail').textContent = formatErrorMessage(state.lastError);
    }
  }

  function renderErrorFallbacks() {
    if ($('error-detail')) {
      $('error-detail').textContent = formatErrorMessage(state.lastError);
    }
    if ($('download-apk-label')) {
      $('download-apk-label').textContent = t('downloadBtnDefault');
    }
    if ($('sha256-value')) {
      $('sha256-value').textContent = t('shaUnavailable');
    }
    if ($('changelog-subtitle')) {
      $('changelog-subtitle').textContent = t('changelogSubtitleDefault');
    }
    if ($('changelog-body')) {
      $('changelog-body').textContent = '';
      var p = document.createElement('p');
      p.className = 'pacer-muted';
      p.textContent = t('changelogError');
      $('changelog-body').appendChild(p);
    }
    if ($('recent-releases-list')) {
      $('recent-releases-list').textContent = '';
      var li = document.createElement('li');
      li.className = 'pacer-surface rounded-xl p-4 text-sm pacer-muted';
      li.textContent = t('recentError');
      $('recent-releases-list').appendChild(li);
    }
  }

  function renderLoadingFallbacks() {
    if ($('download-apk-label')) {
      $('download-apk-label').textContent = t('downloadBtnDefault');
    }
    if ($('sha256-value')) {
      $('sha256-value').textContent = t('shaLoading');
    }
    if ($('changelog-subtitle')) {
      $('changelog-subtitle').textContent = t('changelogSubtitleDefault');
    }
    if ($('changelog-body')) {
      $('changelog-body').textContent = '';
      var p = document.createElement('p');
      p.className = 'pacer-muted';
      p.textContent = t('changelogLoading');
      $('changelog-body').appendChild(p);
    }
    if ($('recent-releases-list')) {
      $('recent-releases-list').textContent = '';
      var li = document.createElement('li');
      li.className = 'pacer-surface rounded-xl p-4 text-sm pacer-muted';
      li.textContent = t('recentLoading');
      $('recent-releases-list').appendChild(li);
    }
  }

  function renderQr(mode) {
    var targetUrl = mode === 'apk' && state.latestApkUrl ? state.latestApkUrl : DOWNLOAD_PAGE_URL;
    state.qrMode = mode === 'apk' && state.latestApkUrl ? 'apk' : 'page';
    state.currentQrUrl = targetUrl;

    var btnPage = $('qr-mode-page');
    var btnApk = $('qr-mode-apk');
    if (btnPage && btnApk) {
      var isPage = state.qrMode === 'page';
      btnPage.setAttribute('aria-pressed', String(isPage));
      btnApk.setAttribute('aria-pressed', String(!isPage));
      btnPage.className = isPage
        ? 'min-h-11 rounded-lg bg-pacer-lime px-3 text-xs sm:text-sm font-bold text-pacer-navy transition-colors duration-150'
        : 'min-h-11 rounded-lg px-3 text-xs sm:text-sm font-semibold pacer-muted hover:text-[var(--ink)] transition-colors duration-150';
      btnApk.className = !isPage
        ? 'min-h-11 rounded-lg bg-pacer-lime px-3 text-xs sm:text-sm font-bold text-pacer-navy transition-colors duration-150'
        : 'min-h-11 rounded-lg px-3 text-xs sm:text-sm font-semibold pacer-muted hover:text-[var(--ink)] disabled:opacity-50 transition-colors duration-150';
    }

    var caption = $('qr-target-caption');
    if (caption) caption.textContent = targetUrl;

    var host = $('qr-svg-host');
    if (host && window.PacerQR) {
      var svgMarkup = window.PacerQR.toSvg(targetUrl, {
        darkColor: '#0F172A',
        lightColor: '#FFFFFF',
        quietZone: 4,
        ariaLabel: state.qrMode === 'apk'
          ? t('qrAriaApkPrefix') + (state.latestTag || t('latestWord')) + ')'
          : t('qrAriaPagePrefix') + DOWNLOAD_PAGE_URL,
      });
      state.currentQrSvg = svgMarkup;
      var parser = new DOMParser();
      var doc = parser.parseFromString(svgMarkup, 'image/svg+xml');
      var svgEl = doc.documentElement;
      if (svgEl && svgEl.tagName.toLowerCase() === 'svg') {
        svgEl.setAttribute('class', 'h-full w-full block');
        host.textContent = '';
        host.appendChild(document.importNode(svgEl, true));
      }
    }
  }

  function renderRecentReleases(releases) {
    var list = $('recent-releases-list');
    if (!list) return;
    list.textContent = '';

    var published = releases.filter(function (r) {
      return r && !r.draft && !r.prerelease;
    });

    if (published.length === 0) {
      var emptyItem = document.createElement('li');
      emptyItem.className = 'pacer-surface rounded-xl p-4 text-sm pacer-muted';
      emptyItem.textContent = t('recentEmpty');
      list.appendChild(emptyItem);
      return;
    }

    var count = Math.min(published.length, 5);
    for (var i = 0; i < count; i++) {
      var rel = published[i];
      var apk = pickApkAsset(rel.assets);
      var linux = pickLinuxAsset(rel.assets);

      var li = document.createElement('li');
      li.className = 'pacer-surface rounded-xl p-4';

      var top = document.createElement('div');
      top.className = 'flex flex-wrap items-center justify-between gap-2';

      var tagLink = document.createElement('a');
      tagLink.href = rel.html_url || RELEASES_WEB;
      tagLink.target = '_blank';
      tagLink.rel = 'noopener noreferrer';
      tagLink.className = 'inline-flex min-h-11 min-w-11 items-center font-bold text-sm sm:text-base hover:underline underline-offset-4';
      tagLink.textContent = rel.tag_name || t('releaseFallbackLabel');

      var dateEl = document.createElement('span');
      dateEl.className = 'pacer-muted text-xs';
      dateEl.textContent = formatDate(rel.published_at);

      top.appendChild(tagLink);
      top.appendChild(dateEl);
      li.appendChild(top);

      var linksRow = document.createElement('div');
      linksRow.className = 'mt-2 flex flex-wrap gap-3 text-xs';

      if (apk) {
        var apkA = document.createElement('a');
        apkA.href = apk.browser_download_url;
        apkA.className = 'pacer-link inline-flex min-h-11 items-center font-semibold underline decoration-current/40 underline-offset-4 hover:decoration-current';
        var apkSize = formatBytes(apk.size);
        apkA.textContent = apkSize ? 'Android APK (' + apkSize + ')' : 'Android APK';
        linksRow.appendChild(apkA);
      }

      if (linux) {
        var linA = document.createElement('a');
        linA.href = linux.browser_download_url;
        linA.className = 'pacer-link inline-flex min-h-11 items-center font-semibold underline decoration-current/40 underline-offset-4 hover:decoration-current';
        var linSize = formatBytes(linux.size);
        linA.textContent = linSize ? 'Linux x64 (' + linSize + ')' : 'Linux x64';
        linksRow.appendChild(linA);
      }

      if (!apk && !linux) {
        var none = document.createElement('span');
        none.className = 'pacer-muted';
        none.textContent = t('sourceReleaseGithub');
        linksRow.appendChild(none);
      }

      li.appendChild(linksRow);
      list.appendChild(li);
    }
  }

  function applyReleases(releases) {
    state.lastReleases = releases;
    var published = (Array.isArray(releases) ? releases : []).filter(function (r) {
      return r && !r.draft && !r.prerelease;
    });

    renderRecentReleases(published);

    if (published.length === 0) {
      setStatusView('empty');
      if ($('download-apk-btn')) $('download-apk-btn').href = RELEASES_WEB;
      if ($('download-apk-label')) $('download-apk-label').textContent = t('downloadBtnFallback');
      if ($('sha256-value')) $('sha256-value').textContent = t('shaNoneRelease');
      renderReleaseNotes($('changelog-body'), '');
      return;
    }

    var latest = published[0];
    var apk = pickApkAsset(latest.assets);
    var latestLinux = null;
    var latestLinuxTag = null;
    for (var i = 0; i < published.length; i++) {
      var candidate = pickLinuxAsset(published[i].assets);
      if (candidate) {
        latestLinux = candidate;
        latestLinuxTag = published[i].tag_name;
        break;
      }
    }

    var tag = latest.tag_name || t('latestWord');
    state.latestTag = tag;

    if ($('release-page-link') && latest.html_url) {
      $('release-page-link').href = latest.html_url;
    }
    if ($('changelog-gh-link') && latest.html_url) {
      $('changelog-gh-link').href = latest.html_url;
    }
    if ($('changelog-subtitle')) {
      var dateStr = formatDate(latest.published_at);
      $('changelog-subtitle').textContent = dateStr
        ? tag + t('changelogPublishedWord') + dateStr + t('changelogOnGithub')
        : tag + t('changelogOnGithub');
    }
    renderReleaseNotes($('changelog-body'), latest.body);

    var linuxLink = $('linux-download-link');
    if (linuxLink) {
      if (latestLinux) {
        linuxLink.href = latestLinux.browser_download_url;
        linuxLink.textContent = latestLinuxTag === tag
          ? 'Linux x64 (' + formatBytes(latestLinux.size) + ')'
          : 'Linux x64 (' + latestLinuxTag + ', ' + formatBytes(latestLinux.size) + ')';
        linuxLink.hidden = false;
      } else {
        linuxLink.hidden = true;
      }
    }

    if (!apk) {
      state.latestApkUrl = null;
      state.latestSha256 = null;
      setStatusView('empty');
      if ($('download-apk-btn')) $('download-apk-btn').href = latest.html_url || RELEASES_WEB;
      if ($('download-apk-label')) $('download-apk-label').textContent = t('downloadBtnFallback');
      if ($('qr-mode-apk')) $('qr-mode-apk').disabled = true;
      if ($('sha256-value')) $('sha256-value').textContent = t('shaNoneApk');
      if ($('copy-sha-btn')) $('copy-sha-btn').disabled = true;
      renderQr('page');
      return;
    }

    state.latestApkUrl = apk.browser_download_url;
    var rawDigest = typeof apk.digest === 'string' ? apk.digest.trim() : '';
    var cleanSha = rawDigest.indexOf('sha256:') === 0 ? rawDigest.slice(7) : rawDigest;
    state.latestSha256 = cleanSha || null;

    if ($('release-tag')) $('release-tag').textContent = tag;
    if ($('release-date')) $('release-date').textContent = formatDate(latest.published_at);
    if ($('apk-size')) $('apk-size').textContent = formatBytes(apk.size) || 'Android APK';
    if ($('release-title')) $('release-title').textContent = stripEmDash(latest.name || ('Pacer ' + tag));
    if ($('apk-filename')) $('apk-filename').textContent = apk.name;

    if ($('download-apk-btn')) $('download-apk-btn').href = apk.browser_download_url;
    if ($('download-apk-label')) $('download-apk-label').textContent = t('downloadBtnDefault') + ' (' + tag + ')';

    if ($('qr-mode-apk')) $('qr-mode-apk').disabled = false;

    if ($('sha256-value')) {
      $('sha256-value').textContent = state.latestSha256 || t('shaMissing');
    }
    if ($('copy-sha-btn')) {
      $('copy-sha-btn').disabled = !state.latestSha256;
    }

    setStatusView('ready');
    renderQr(state.qrMode);
  }

  function readCache() {
    try {
      var raw = localStorage.getItem(CACHE_KEY);
      if (!raw) return null;
      var parsed = JSON.parse(raw);
      if (!parsed || !Array.isArray(parsed.releases)) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  function writeCache(releases) {
    try {
      localStorage.setItem(CACHE_KEY, JSON.stringify({
        savedAt: Date.now(),
        releases: releases,
      }));
    } catch (_) {}
  }

  function loadReleases(forceNetwork) {
    var cached = !forceNetwork ? readCache() : null;
    if (cached && (Date.now() - cached.savedAt) < CACHE_TTL_MS) {
      applyReleases(cached.releases);
      return;
    }

    setStatusView('loading');
    renderLoadingFallbacks();
    var controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
    var timer = controller ? setTimeout(function () { controller.abort(); }, 10000) : null;

    fetch(RELEASES_API, {
      headers: { Accept: 'application/vnd.github+json' },
      signal: controller ? controller.signal : undefined,
    })
      .then(function (res) {
        if (!res.ok) {
          var err = new Error('HTTP ' + res.status);
          err.status = res.status;
          throw err;
        }
        return res.json();
      })
      .then(function (data) {
        if (timer) clearTimeout(timer);
        writeCache(data);
        applyReleases(data);
      })
      .catch(function (err) {
        if (timer) clearTimeout(timer);
        var stale = readCache();
        if (stale && stale.releases.length > 0 && !forceNetwork) {
          applyReleases(stale.releases);
          return;
        }
        var errInfo;
        if (err && err.name === 'AbortError') {
          errInfo = { kind: 'timeout' };
        } else if (err && err.status === 403) {
          errInfo = { kind: 'rate_limit', status: 403 };
        } else if (err && err.status) {
          errInfo = { kind: 'http', status: err.status };
        } else {
          errInfo = { kind: 'default' };
        }
        setStatusView('error', errInfo);
        renderErrorFallbacks();
      });
  }

  /* Language switcher (Indonesian default, English alternate) */
  function syncScreenshotContent() {
    var spec = SCREENSHOTS[state.activeScreen] || SCREENSHOTS.dashboard;
    var img = $('hero-screenshot-img');
    var caption = $('hero-screenshot-caption');
    if (img) {
      img.src = spec.src;
      img.alt = spec.alt[state.lang] || spec.alt.id;
    }
    if (caption) {
      caption.textContent = spec.caption[state.lang] || spec.caption.id;
    }
  }

  function syncLangButton() {
    var btn = $('lang-toggle');
    var pillId = $('lang-pill-id');
    var pillEn = $('lang-pill-en');
    var isId = state.lang === 'id';
    if (btn) {
      btn.setAttribute('aria-label', t('langToggleAria'));
    }
    if (pillId) {
      pillId.className = isId
        ? 'rounded-md bg-pacer-lime px-1.5 py-0.5 text-pacer-navy'
        : 'rounded-md px-1.5 py-0.5 pacer-muted';
    }
    if (pillEn) {
      pillEn.className = !isId
        ? 'rounded-md bg-pacer-lime px-1.5 py-0.5 text-pacer-navy'
        : 'rounded-md px-1.5 py-0.5 pacer-muted';
    }
  }

  function applyLanguage(lang, persist) {
    state.lang = lang === 'en' ? 'en' : 'id';
    document.documentElement.lang = state.lang;
    document.title = t('pageTitle');

    var metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc) metaDesc.setAttribute('content', t('metaDescription'));

    var nodes = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < nodes.length; i++) {
      var key = nodes[i].getAttribute('data-i18n');
      if (key) nodes[i].textContent = t(key);
    }

    if ($('brand-home-link')) $('brand-home-link').setAttribute('aria-label', t('homeAria'));
    if ($('primary-nav')) $('primary-nav').setAttribute('aria-label', t('navPrimaryAria'));
    if ($('mobile-nav')) $('mobile-nav').setAttribute('aria-label', t('navMobileAria'));
    if ($('screenshot-tablist')) $('screenshot-tablist').setAttribute('aria-label', t('screenTablistAria'));
    if ($('qr-target-group')) $('qr-target-group').setAttribute('aria-label', t('qrGroupAria'));

    if ($('qr-action-feedback')) $('qr-action-feedback').textContent = '';
    if ($('sha-feedback')) $('sha-feedback').textContent = '';

    syncLangButton();
    syncThemeButton();
    syncScreenshotContent();

    if (state.lastReleases !== null) {
      applyReleases(state.lastReleases);
    } else if (state.statusMode === 'error') {
      renderErrorFallbacks();
      renderQr(state.qrMode);
    } else {
      renderLoadingFallbacks();
      renderQr(state.qrMode);
    }

    if (persist) {
      try {
        localStorage.setItem(LANG_KEY, state.lang);
      } catch (_) {}
    }
  }

  function setupLanguageToggle() {
    state.lang = resolveInitialLang();
    var btn = $('lang-toggle');
    if (btn) {
      btn.addEventListener('click', function () {
        applyLanguage(state.lang === 'id' ? 'en' : 'id', true);
      });
    }
  }

  /* Theme toggle (Dark default, full Light parity) */
  function syncThemeButton() {
    var isDark = document.documentElement.classList.contains('dark');
    var btn = $('theme-toggle');
    var sun = $('theme-icon-sun');
    var moon = $('theme-icon-moon');
    var label = $('theme-label');
    if (btn) {
      btn.setAttribute('aria-pressed', String(isDark));
      btn.setAttribute('aria-label', isDark ? t('themeToLightAria') : t('themeToDarkAria'));
    }
    if (sun) sun.classList.toggle('hidden', isDark);
    if (moon) moon.classList.toggle('hidden', !isDark);
    if (label) label.textContent = isDark ? t('themeDark') : t('themeLight');
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', isDark ? '#0F172A' : '#E8EEF5');
  }

  function setupThemeToggle() {
    syncThemeButton();
    var btn = $('theme-toggle');
    if (!btn) return;
    btn.addEventListener('click', function () {
      var nextDark = !document.documentElement.classList.contains('dark');
      document.documentElement.classList.toggle('dark', nextDark);
      try {
        localStorage.setItem('pacer.theme', nextDark ? 'dark' : 'light');
      } catch (_) {}
      syncThemeButton();
    });
  }

  /* Mobile menu drawer with Escape & link-click close */
  function setupMobileMenu() {
    var btn = $('mobile-menu-btn');
    var nav = $('mobile-nav');
    if (!btn || !nav) return;

    function setOpen(open) {
      nav.hidden = !open;
      btn.setAttribute('aria-expanded', String(open));
    }

    btn.addEventListener('click', function () {
      setOpen(nav.hidden);
    });

    nav.querySelectorAll('a').forEach(function (link) {
      link.addEventListener('click', function () {
        setOpen(false);
      });
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && !nav.hidden) {
        setOpen(false);
        btn.focus();
      }
    });
  }

  /* Accessible screenshot tablist (click + ArrowLeft/ArrowRight/Home/End) */
  function setupScreenshotTabs() {
    var tabs = Array.prototype.slice.call(document.querySelectorAll('.screen-tab'));
    var panel = $('panel-screenshot');
    if (!tabs.length || !panel) return;

    function activate(tab, moveFocus) {
      var key = tab.getAttribute('data-screen');
      if (!SCREENSHOTS[key]) return;
      state.activeScreen = key;
      tabs.forEach(function (tabEl) {
        var active = tabEl === tab;
        tabEl.setAttribute('aria-selected', String(active));
        tabEl.setAttribute('tabindex', active ? '0' : '-1');
        tabEl.className = active
          ? 'screen-tab min-h-11 rounded-lg bg-pacer-lime px-2 text-xs sm:text-sm font-bold text-pacer-navy transition-colors duration-150'
          : 'screen-tab min-h-11 rounded-lg px-2 text-xs sm:text-sm font-semibold pacer-muted hover:text-[var(--ink)] transition-colors duration-150';
      });
      syncScreenshotContent();
      panel.setAttribute('aria-labelledby', tab.id);
      if (moveFocus) tab.focus();
    }

    tabs.forEach(function (tab, idx) {
      tab.addEventListener('click', function () {
        activate(tab, false);
      });
      tab.addEventListener('keydown', function (e) {
        if (e.key === 'ArrowRight') {
          e.preventDefault();
          activate(tabs[(idx + 1) % tabs.length], true);
        } else if (e.key === 'ArrowLeft') {
          e.preventDefault();
          activate(tabs[(idx - 1 + tabs.length) % tabs.length], true);
        } else if (e.key === 'Home') {
          e.preventDefault();
          activate(tabs[0], true);
        } else if (e.key === 'End') {
          e.preventDefault();
          activate(tabs[tabs.length - 1], true);
        }
      });
    });
  }

  function copyToClipboard(text, feedbackEl, okLabel) {
    if (!text) return;
    function done(ok) {
      if (!feedbackEl) return;
      feedbackEl.textContent = ok ? okLabel : t('clipboardBlocked');
      setTimeout(function () {
        if (feedbackEl.textContent === okLabel) feedbackEl.textContent = '';
      }, 2600);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () { done(true); }, function () { done(false); });
    } else {
      try {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.setAttribute('readonly', '');
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        var ok = document.execCommand('copy');
        document.body.removeChild(ta);
        done(ok);
      } catch (_) {
        done(false);
      }
    }
  }

  function setupQrAndCopyControls() {
    var btnPage = $('qr-mode-page');
    var btnApk = $('qr-mode-apk');
    if (btnPage) btnPage.addEventListener('click', function () {
      if ($('qr-action-feedback')) $('qr-action-feedback').textContent = '';
      renderQr('page');
    });
    if (btnApk) btnApk.addEventListener('click', function () {
      if (!btnApk.disabled) {
        if ($('qr-action-feedback')) $('qr-action-feedback').textContent = '';
        renderQr('apk');
      }
    });

    var copyUrlBtn = $('qr-copy-url-btn');
    if (copyUrlBtn) {
      copyUrlBtn.addEventListener('click', function () {
        copyToClipboard(state.currentQrUrl, $('qr-action-feedback'), t('copiedLink'));
      });
    }

    function escapeXml(str) {
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
    }

    function getQrExportLabels() {
      if (state.qrMode === 'apk' && state.latestApkUrl) {
        var tag = state.latestTag || 'latest';
        return {
          url: state.latestApkUrl,
          title: 'Pacer Android APK (' + tag + ')',
          subtitle: 'pacer-' + tag + '-android.apk',
        };
      }
      return {
        url: DOWNLOAD_PAGE_URL,
        title: 'Pacer Download Web',
        subtitle: 'lemondeft.github.io/pacer',
      };
    }

    function buildLabeledExportSvg(meta) {
      var encoded = window.PacerQR.encodeMatrix(meta.url);
      var quiet = 4;
      var total = encoded.size + quiet * 2;
      var cmds = [];
      for (var r = 0; r < encoded.size; r++) {
        var c = 0;
        while (c < encoded.size) {
          if (encoded.modules[r][c]) {
            var start = c;
            while (c < encoded.size && encoded.modules[r][c]) c++;
            cmds.push('M' + (start + quiet) + ',' + (r + quiet) + 'h' + (c - start) + 'v1h-' + (c - start) + 'z');
          } else {
            c++;
          }
        }
      }
      var qrPx = 512;
      var scale = (qrPx / total).toFixed(6);
      var heightPx = qrPx + 88;
      return [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + qrPx + ' ' + heightPx + '" width="' + qrPx + '" height="' + heightPx + '" role="img" aria-label="' + escapeXml(meta.title + ' QR code') + '">',
        '  <rect width="' + qrPx + '" height="' + heightPx + '" fill="#FFFFFF"/>',
        '  <g transform="scale(' + scale + ')" shape-rendering="crispEdges"><path fill="#0F172A" d="' + cmds.join('') + '"/></g>',
        '  <line x1="48" y1="506" x2="464" y2="506" stroke="#CBD5E1" stroke-width="1.5"/>',
        '  <text x="256" y="540" text-anchor="middle" font-family="system-ui, sans-serif" font-size="22" font-weight="800" fill="#0F172A">' + escapeXml(meta.title) + '</text>',
        '  <text x="256" y="566" text-anchor="middle" font-family="ui-monospace, monospace" font-size="13" font-weight="500" fill="#475569">' + escapeXml(meta.subtitle) + '</text>',
        '</svg>',
      ].join('\n');
    }

    var saveSvgBtn = $('qr-download-svg-btn');
    if (saveSvgBtn) {
      saveSvgBtn.addEventListener('click', function () {
        if (!window.PacerQR) return;
        var meta = getQrExportLabels();
        var svgText = buildLabeledExportSvg(meta);
        var blob = new Blob([svgText], { type: 'image/svg+xml;charset=utf-8' });
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url;
        a.download = state.qrMode === 'apk'
          ? 'pacer-' + (state.latestTag || 'latest') + '-apk-qr.svg'
          : 'pacer-download-web-qr.svg';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
        if ($('qr-action-feedback')) {
          $('qr-action-feedback').textContent = t('savedPrefix') + a.download;
        }
      });
    }

    var savePngLink = $('qr-download-png-link');
    if (savePngLink) {
      savePngLink.addEventListener('click', function (e) {
        if (state.qrMode !== 'apk' || !state.latestApkUrl || !window.PacerQR) return;
        e.preventDefault();
        var meta = getQrExportLabels();
        var encoded = window.PacerQR.encodeMatrix(meta.url);
        var quiet = 4;
        var total = encoded.size + quiet * 2;
        var targetPx = 1024;
        var footerH = 176;
        var scale = Math.max(1, Math.floor(targetPx / total));
        var finalSize = total * scale;
        var offset = Math.floor((targetPx - finalSize) / 2);
        var canvas = document.createElement('canvas');
        canvas.width = targetPx;
        canvas.height = targetPx + footerH;
        var ctx = canvas.getContext('2d');
        if (!ctx) return;
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(0, 0, targetPx, targetPx + footerH);
        ctx.fillStyle = '#0F172A';
        for (var r = 0; r < encoded.size; r++) {
          for (var c = 0; c < encoded.size; c++) {
            if (encoded.modules[r][c]) {
              ctx.fillRect(offset + (c + quiet) * scale, offset + (r + quiet) * scale, scale, scale);
            }
          }
        }
        ctx.strokeStyle = '#CBD5E1';
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(96, targetPx - 10);
        ctx.lineTo(targetPx - 96, targetPx - 10);
        ctx.stroke();

        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = '#0F172A';
        ctx.font = '800 44px "Outfit", system-ui, sans-serif';
        ctx.fillText(meta.title, targetPx / 2, targetPx + 42);
        ctx.fillStyle = '#475569';
        ctx.font = '500 26px "JetBrains Mono", monospace';
        ctx.fillText(meta.subtitle, targetPx / 2, targetPx + 102);

        var filename = 'pacer-' + (state.latestTag || 'latest') + '-apk-qr.png';
        var pngUrl = canvas.toDataURL('image/png');
        var a = document.createElement('a');
        a.href = pngUrl;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        if ($('qr-action-feedback')) {
          $('qr-action-feedback').textContent = t('savedPrefix') + filename;
        }
      });
    }

    var copyShaBtn = $('copy-sha-btn');
    if (copyShaBtn) {
      copyShaBtn.addEventListener('click', function () {
        if (state.latestSha256) {
          copyToClipboard(state.latestSha256, $('sha-feedback'), t('copiedSha'));
        }
      });
    }

    var retryBtn = $('retry-fetch-btn');
    if (retryBtn) {
      retryBtn.addEventListener('click', function () {
        loadReleases(true);
      });
    }
  }

  document.addEventListener('DOMContentLoaded', function () {
    setupLanguageToggle();
    setupThemeToggle();
    setupMobileMenu();
    setupScreenshotTabs();
    setupQrAndCopyControls();
    applyLanguage(state.lang, false);
    loadReleases(false);
  });
})();
