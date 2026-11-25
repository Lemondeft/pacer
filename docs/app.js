/* Pacer static download page controller:
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
  var CACHE_TTL_MS = 10 * 60 * 1000;

  var SCREENSHOTS = {
    dashboard: {
      src: 'screenshots/dashboard.png',
      alt: 'Pacer Android dashboard showing active 5-day streak, quick-start sport buttons for Running, Jogging, Cycling, and Walking, weekly distance bar chart, and floating bottom navigation pill.',
      caption: 'Home dashboard: 5-day streak card, 4 sport quick-starts, and weekly volume chart.',
    },
    tracking: {
      src: 'screenshots/tracking.png',
      alt: 'Pacer live GPS workout screen displaying OpenFreeMap dark vector grid, recorded route loop, 0.73 km live distance, average pace, duration, calories, and Pause button.',
      caption: 'Live GPS tracking: OpenFreeMap route path, pace, duration, calories, and foreground recording.',
    },
    themes: {
      src: 'screenshots/themes.png',
      alt: 'Pacer theme settings showing System, Light, and Dark modes plus classic Linux desktop palettes including Pacer Argon, KDE Breeze, Mint-Y Cinnamon, GNOME Adwaita, and Ubuntu Yaru.',
      caption: 'Appearance settings: System, Light, Dark modes, and 6 desktop-inspired palettes.',
    },
  };

  var state = {
    latestApkUrl: null,
    latestTag: null,
    latestSha256: null,
    qrMode: 'page',
    currentQrSvg: null,
    currentQrUrl: DOWNLOAD_PAGE_URL,
  };

  function $(id) {
    return document.getElementById(id);
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
      return new Intl.DateTimeFormat('en-US', {
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

  /* Safe DOM markdown renderer (headings, lists, bold, inline code, links). */
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
    container.textContent = '';
    var text = String(markdown || '').trim();
    if (!text) {
      var empty = document.createElement('p');
      empty.className = 'pacer-muted';
      empty.textContent = 'No release notes were published for this tag.';
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

  function setStatusView(mode, errorText) {
    var ids = ['loading', 'ready', 'empty', 'error'];
    for (var i = 0; i < ids.length; i++) {
      var el = $('state-' + ids[i]);
      if (el) el.hidden = ids[i] !== mode;
    }
    if (mode === 'error' && errorText && $('error-detail')) {
      $('error-detail').textContent = errorText;
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
          ? 'QR code for direct Pacer APK download (' + (state.latestTag || 'latest') + ')'
          : 'QR code for Pacer download page ' + DOWNLOAD_PAGE_URL,
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
      emptyItem.textContent = 'No published releases found yet.';
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
      tagLink.textContent = rel.tag_name || 'Release';

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
        none.textContent = 'Source release on GitHub';
        linksRow.appendChild(none);
      }

      li.appendChild(linksRow);
      list.appendChild(li);
    }
  }

  function applyReleases(releases) {
    var published = (Array.isArray(releases) ? releases : []).filter(function (r) {
      return r && !r.draft && !r.prerelease;
    });

    renderRecentReleases(published);

    if (published.length === 0) {
      setStatusView('empty');
      if ($('sha256-value')) $('sha256-value').textContent = 'No published release available yet.';
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

    var tag = latest.tag_name || 'Latest';
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
        ? tag + ' published ' + dateStr + ' on GitHub Releases.'
        : tag + ' on GitHub Releases.';
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
      if ($('download-apk-label')) $('download-apk-label').textContent = 'Open GitHub Releases';
      if ($('qr-mode-apk')) $('qr-mode-apk').disabled = true;
      if ($('sha256-value')) $('sha256-value').textContent = 'No APK digest attached to this release.';
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
    if ($('download-apk-label')) $('download-apk-label').textContent = 'Download Android APK (' + tag + ')';

    if ($('qr-mode-apk')) $('qr-mode-apk').disabled = false;

    if ($('sha256-value')) {
      $('sha256-value').textContent = state.latestSha256 || 'SHA-256 digest was not published for this release.';
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
    var controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
    var timer = controller ? setTimeout(function () { controller.abort(); }, 6000) : null;

    fetch(RELEASES_API, {
      headers: { Accept: 'application/vnd.github+json' },
      signal: controller ? controller.signal : undefined,
    })
      .then(function (res) {
        if (!res.ok) {
          var err = new Error(
            res.status === 403
              ? 'GitHub API rate limit reached for this network. Use the direct button below to open GitHub Releases.'
              : 'GitHub returned HTTP ' + res.status + '. Use the button below to open GitHub Releases directly.'
          );
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
        var msg = (err && err.name === 'AbortError')
          ? 'The request to GitHub timed out. Check your connection or open GitHub Releases directly.'
          : (err && err.message) || 'Check your connection or open GitHub Releases directly.';
        setStatusView('error', msg);
        if ($('sha256-value')) $('sha256-value').textContent = 'Unavailable while offline or rate-limited.';
        if ($('changelog-body')) {
          $('changelog-body').textContent = '';
          var p = document.createElement('p');
          p.className = 'pacer-muted';
          p.textContent = 'Release notes could not be loaded right now. Open GitHub Releases to view the changelog.';
          $('changelog-body').appendChild(p);
        }
        if ($('recent-releases-list')) {
          $('recent-releases-list').textContent = '';
          var li = document.createElement('li');
          li.className = 'pacer-surface rounded-xl p-4 text-sm pacer-muted';
          li.textContent = 'Archive unavailable right now. Browse all versions directly on GitHub.';
          $('recent-releases-list').appendChild(li);
        }
      });
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
      btn.setAttribute('aria-label', isDark ? 'Switch to light theme' : 'Switch to dark theme');
    }
    if (sun) sun.classList.toggle('hidden', isDark);
    if (moon) moon.classList.toggle('hidden', !isDark);
    if (label) label.textContent = isDark ? 'Dark' : 'Light';
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
    var img = $('hero-screenshot-img');
    var caption = $('hero-screenshot-caption');
    var panel = $('panel-screenshot');
    if (!tabs.length || !img || !caption || !panel) return;

    function activate(tab, moveFocus) {
      var key = tab.getAttribute('data-screen');
      var spec = SCREENSHOTS[key];
      if (!spec) return;
      tabs.forEach(function (t) {
        var active = t === tab;
        t.setAttribute('aria-selected', String(active));
        t.setAttribute('tabindex', active ? '0' : '-1');
        t.className = active
          ? 'screen-tab min-h-11 rounded-lg bg-pacer-lime px-2 text-xs sm:text-sm font-bold text-pacer-navy transition-colors duration-150'
          : 'screen-tab min-h-11 rounded-lg px-2 text-xs sm:text-sm font-semibold pacer-muted hover:text-[var(--ink)] transition-colors duration-150';
      });
      img.src = spec.src;
      img.alt = spec.alt;
      caption.textContent = spec.caption;
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
      feedbackEl.textContent = ok ? okLabel : 'Clipboard access blocked. Select and copy the text above.';
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
        copyToClipboard(state.currentQrUrl, $('qr-action-feedback'), 'Copied link to clipboard.');
      });
    }

    var saveSvgBtn = $('qr-download-svg-btn');
    if (saveSvgBtn) {
      saveSvgBtn.addEventListener('click', function () {
        if (!state.currentQrSvg) renderQr(state.qrMode);
        if (!state.currentQrSvg) return;
        var blob = new Blob([state.currentQrSvg], { type: 'image/svg+xml;charset=utf-8' });
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url;
        a.download = state.qrMode === 'apk'
          ? 'pacer-' + (state.latestTag || 'latest') + '-apk-qr.svg'
          : 'pacer-download-page-qr.svg';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
        if ($('qr-action-feedback')) {
          $('qr-action-feedback').textContent = 'Saved ' + a.download;
        }
      });
    }

    var copyShaBtn = $('copy-sha-btn');
    if (copyShaBtn) {
      copyShaBtn.addEventListener('click', function () {
        if (state.latestSha256) {
          copyToClipboard(state.latestSha256, $('sha-feedback'), 'Copied SHA-256 digest.');
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
    setupThemeToggle();
    setupMobileMenu();
    setupScreenshotTabs();
    setupQrAndCopyControls();
    renderQr('page');
    loadReleases(false);
  });
})();
