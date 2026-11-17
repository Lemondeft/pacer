import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateCheckStatus { available, upToDate, failed }

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final GitHubReleaseInfo? release;
  const UpdateCheckResult(this.status, [this.release]);
}

/// Parsed metadata for a published GitHub Release of `Lemondeft/pacer`.
class GitHubReleaseInfo {
  final String tagName;
  final String version;
  final String notes;
  final String htmlUrl;
  final String? apkDownloadUrl;
  final int? apkSizeBytes;

  const GitHubReleaseInfo({
    required this.tagName,
    required this.version,
    required this.notes,
    required this.htmlUrl,
    this.apkDownloadUrl,
    this.apkSizeBytes,
  });

  bool get usesApkAsset =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      apkDownloadUrl != null &&
      apkDownloadUrl!.isNotEmpty;

  String get preferredDownloadUrl => usesApkAsset ? apkDownloadUrl! : htmlUrl;

  String? get formattedApkSize {
    final bytes = apkSizeBytes;
    if (!usesApkAsset || bytes == null || bytes <= 0) return null;
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory GitHubReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawTag = (json['tag_name'] ?? '').toString().trim();
    final cleanVer = GitHubUpdateService.normalizeVersionString(rawTag);
    final rawBody = (json['body'] ?? '').toString().trim();
    final html =
        (json['html_url'] ?? 'https://github.com/Lemondeft/pacer/releases')
            .toString()
            .trim();

    String? apkUrl;
    int? apkSize;
    final assets = json['assets'];
    if (assets is List) {
      for (final item in assets) {
        if (item is! Map) continue;
        final name = (item['name'] ?? '').toString().toLowerCase();
        final url = (item['browser_download_url'] ?? '').toString().trim();
        if (!name.endsWith('.apk') || url.isEmpty) continue;
        apkUrl = url;
        final sizeVal = item['size'];
        apkSize = sizeVal is num ? sizeVal.toInt() : null;
        if (name == 'app-release.apk') break;
      }
    }

    return GitHubReleaseInfo(
      tagName: rawTag.isNotEmpty ? rawTag : 'v$cleanVer',
      version: cleanVer,
      notes: rawBody,
      htmlUrl: html,
      apkDownloadUrl: apkUrl,
      apkSizeBytes: apkSize,
    );
  }
}

/// Checks `https://api.github.com/repos/Lemondeft/pacer/releases/latest`
/// against [currentVersion] and manages version-dismissal state.
class GitHubUpdateService {
  GitHubUpdateService._();
  static final GitHubUpdateService instance = GitHubUpdateService._();

  static const String currentVersion = '0.2.8';
  static const String latestReleaseEndpoint =
      'https://api.github.com/repos/Lemondeft/pacer/releases/latest';
  static const String _dismissedTagPrefKey = 'pacer.dismissed_update_tag';

  bool _autoCheckedThisSession = false;
  http.Client Function()? clientFactory;

  static String normalizeVersionString(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1).trim();
    return s.split(RegExp(r'[+-]')).first.trim();
  }

  static List<int> parseVersion(String raw) {
    final normalized = normalizeVersionString(raw);
    if (normalized.isEmpty) return const [0, 0, 0];
    final parts = normalized.split('.');
    return List<int>.generate(
      3,
      (i) => i < parts.length ? (int.tryParse(parts[i].trim()) ?? 0) : 0,
    );
  }

  static bool isNewerVersion(
    String latestTag, [
    String current = currentVersion,
  ]) {
    final a = parseVersion(latestTag);
    final b = parseVersion(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  Future<UpdateCheckResult> checkForUpdate({
    bool respectDismissed = true,
    http.Client? client,
    String? currentVersionOverride,
  }) async {
    if (!ConnectivityService.instance.value) {
      return const UpdateCheckResult(UpdateCheckStatus.failed);
    }
    final ownClient = client == null;
    final httpClient = client ?? clientFactory?.call() ?? http.Client();
    try {
      final response = await httpClient
          .get(
            Uri.parse(latestReleaseEndpoint),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Pacer-Flutter-App',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return const UpdateCheckResult(UpdateCheckStatus.failed);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const UpdateCheckResult(UpdateCheckStatus.failed);
      }
      if (decoded['draft'] == true || decoded['prerelease'] == true) {
        return const UpdateCheckResult(UpdateCheckStatus.upToDate);
      }

      final info = GitHubReleaseInfo.fromJson(decoded);
      final baseline = currentVersionOverride ?? currentVersion;
      if (!isNewerVersion(info.tagName, baseline)) {
        return const UpdateCheckResult(UpdateCheckStatus.upToDate);
      }

      if (respectDismissed) {
        final dismissed = await getDismissedTag();
        if (dismissed != null &&
            normalizeVersionString(dismissed) == info.version) {
          return const UpdateCheckResult(UpdateCheckStatus.upToDate);
        }
      }

      return UpdateCheckResult(UpdateCheckStatus.available, info);
    } catch (_) {
      return const UpdateCheckResult(UpdateCheckStatus.failed);
    } finally {
      if (ownClient) httpClient.close();
    }
  }

  Future<GitHubReleaseInfo?> checkOnceOnStartup({http.Client? client}) async {
    if (_autoCheckedThisSession) return null;
    final result = await checkForUpdate(respectDismissed: true, client: client);
    if (result.status == UpdateCheckStatus.failed) return null;
    _autoCheckedThisSession = true;
    return result.release;
  }

  void resetSessionAutoCheckForTest() {
    _autoCheckedThisSession = false;
  }

  Future<String?> getDismissedTag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_dismissedTagPrefKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> dismissVersion(String tagName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedTagPrefKey, tagName.trim());
    } catch (_) {}
  }

  Future<bool> openReleaseDownload(GitHubReleaseInfo info) async {
    final uri = Uri.tryParse(info.preferredDownloadUrl);
    if (uri == null || uri.scheme != 'https') return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
