import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:pacer/src/ui/screens.dart';
import 'package:pacer/src/ui/widgets.dart';
import 'package:pacer/src/update/github_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _releasePayload({
  String tag = 'v9.9.9',
  bool draft = false,
  bool prerelease = false,
  bool includeApk = true,
}) => {
  'tag_name': tag,
  'body': '### What is new\n- Automatic GitHub Release updater',
  'html_url': 'https://github.com/Lemondeft/pacer/releases/tag/$tag',
  'draft': draft,
  'prerelease': prerelease,
  'assets': includeApk
      ? [
          {
            'name': 'app-release.apk',
            'browser_download_url':
                'https://github.com/Lemondeft/pacer/releases/download/$tag/app-release.apk',
            'size': 25480396,
          },
        ]
      : const [],
};

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConnectivityService.instance.setTestOverride(true);
    GitHubUpdateService.instance.resetSessionAutoCheckForTest();
    GitHubUpdateService.instance.clientFactory = null;
    langNotifier.value = Lang.en;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    ConnectivityService.instance.setTestOverride(null);
    GitHubUpdateService.instance.clientFactory = null;
  });

  group('GitHubUpdateService', () {
    test('currentVersion stays synced with pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*([^\s+#]+)', multiLine: true)
          .firstMatch(pubspec);
      expect(match, isNotNull);
      expect(GitHubUpdateService.currentVersion, match!.group(1));
    });

    test('parseVersion and isNewerVersion compare semver tags', () {
      expect(GitHubUpdateService.parseVersion('v0.2.3+5'), [0, 2, 3]);
      expect(GitHubUpdateService.isNewerVersion('v0.2.4', '0.2.3'), isTrue);
      expect(GitHubUpdateService.isNewerVersion('v0.3.0', '0.2.3'), isTrue);
      expect(GitHubUpdateService.isNewerVersion('v1.0.0', '0.2.3'), isTrue);
      expect(GitHubUpdateService.isNewerVersion('v0.2.3', '0.2.3'), isFalse);
      expect(GitHubUpdateService.isNewerVersion('v0.2.2', '0.2.3'), isFalse);
    });

    test('gates APK URL and size to Android only', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode(_releasePayload()), 200),
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final androidRes = await GitHubUpdateService.instance.checkForUpdate(
        client: client,
      );
      expect(androidRes.status, UpdateCheckStatus.available);
      expect(
        androidRes.release!.preferredDownloadUrl,
        'https://github.com/Lemondeft/pacer/releases/download/v9.9.9/app-release.apk',
      );
      expect(androidRes.release!.formattedApkSize, '24.3 MB');

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final desktopRes = await GitHubUpdateService.instance.checkForUpdate(
        client: client,
      );
      expect(desktopRes.status, UpdateCheckStatus.available);
      expect(
        desktopRes.release!.preferredDownloadUrl,
        'https://github.com/Lemondeft/pacer/releases/tag/v9.9.9',
      );
      expect(desktopRes.release!.formattedApkSize, isNull);
    });

    test('distinguishes upToDate vs failed (HTTP error, exception, offline)', () async {
      final upToDateClient = MockClient(
        (_) async => http.Response(
          jsonEncode(_releasePayload(tag: 'v${GitHubUpdateService.currentVersion}')),
          200,
        ),
      );
      final upToDateRes = await GitHubUpdateService.instance.checkForUpdate(
        client: upToDateClient,
      );
      expect(upToDateRes.status, UpdateCheckStatus.upToDate);
      expect(upToDateRes.release, isNull);

      final failClient = MockClient((_) async => http.Response('rate limit', 403));
      expect(
        (await GitHubUpdateService.instance.checkForUpdate(client: failClient))
            .status,
        UpdateCheckStatus.failed,
      );

      final throwClient = MockClient((_) async => throw Exception('timeout'));
      expect(
        (await GitHubUpdateService.instance.checkForUpdate(client: throwClient))
            .status,
        UpdateCheckStatus.failed,
      );

      ConnectivityService.instance.setTestOverride(false);
      expect(
        (await GitHubUpdateService.instance.checkForUpdate(client: upToDateClient))
            .status,
        UpdateCheckStatus.failed,
      );
    });

    test('checkOnceOnStartup retries after failure and latches after success', () async {
      final failClient = MockClient((_) async => http.Response('err', 500));
      expect(
        await GitHubUpdateService.instance.checkOnceOnStartup(client: failClient),
        isNull,
      );

      final okClient = MockClient(
        (_) async => http.Response(jsonEncode(_releasePayload()), 200),
      );
      final first = await GitHubUpdateService.instance.checkOnceOnStartup(
        client: okClient,
      );
      expect(first?.tagName, 'v9.9.9');

      // Subsequent call in same session is suppressed once latched.
      final second = await GitHubUpdateService.instance.checkOnceOnStartup(
        client: okClient,
      );
      expect(second, isNull);
    });

    test('dismissVersion suppresses auto-check unless respectDismissed=false', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(_releasePayload(tag: 'v0.2.5', includeApk: false)),
          200,
        ),
      );
      await GitHubUpdateService.instance.dismissVersion('v0.2.5');

      final autoRes = await GitHubUpdateService.instance.checkForUpdate(
        client: client,
        respectDismissed: true,
      );
      expect(autoRes.status, UpdateCheckStatus.upToDate);

      final manualRes = await GitHubUpdateService.instance.checkForUpdate(
        client: client,
        respectDismissed: false,
      );
      expect(manualRes.status, UpdateCheckStatus.available);
      expect(manualRes.release!.tagName, 'v0.2.5');
    });

    test('openReleaseDownload rejects non-https schemes', () async {
      const insecure = GitHubReleaseInfo(
        tagName: 'v0.2.4',
        version: '0.2.4',
        notes: '',
        htmlUrl: 'http://example.com/release',
      );
      expect(
        await GitHubUpdateService.instance.openReleaseDownload(insecure),
        isFalse,
      );
    });
  });

  group('Updater UI & HomeScreen centered PacerLogo', () {
    const release = GitHubReleaseInfo(
      tagName: 'v9.9.9',
      version: '9.9.9',
      notes: 'Added automatic GitHub updater and centered header logo.',
      htmlUrl: 'https://github.com/Lemondeft/pacer/releases/tag/v9.9.9',
      apkDownloadUrl:
          'https://github.com/Lemondeft/pacer/releases/download/v9.9.9/app-release.apk',
      apkSizeBytes: 25165824,
    );

    testWidgets('UpdateAvailableSheet uses readable light icon & skips version', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: PacerTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => UpdateAvailableSheet.show(context, release),
                    child: const Text('Open Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(
          find.byIcon(Icons.system_update_alt_rounded),
        );
        expect(icon.color, PacerScheme.light.accent);
        expect(find.text(S.updateAvailableTitle), findsOneWidget);
        expect(
          find.text('v${GitHubUpdateService.currentVersion} → v9.9.9'),
          findsOneWidget,
        );
        expect(find.text('APK • 24.0 MB'), findsOneWidget);

        await tester.tap(find.text(S.skipVersionCta));
        await tester.pumpAndSettle();
        expect(await GitHubUpdateService.instance.getDismissedTag(), 'v9.9.9');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('AccountScreen Check for Updates distinguishes failure vs up-to-date', (
      tester,
    ) async {
      var fail = true;
      GitHubUpdateService.instance.clientFactory = () => MockClient(
        (_) async => fail
            ? http.Response('error', 500)
            : http.Response(
                jsonEncode(
                  _releasePayload(tag: 'v${GitHubUpdateService.currentVersion}'),
                ),
                200,
              ),
      );

      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.dark(), home: const AccountScreen()),
      );
      await tester.pumpAndSettle();

      final checkBtn = find.text(
        S.checkForUpdates(GitHubUpdateService.currentVersion),
      );
      await tester.ensureVisible(checkBtn);
      await tester.tap(checkBtn);
      await tester.pumpAndSettle();
      expect(find.text(S.updateCheckFailed), findsOneWidget);

      fail = false;
      await tester.tap(checkBtn);
      await tester.pumpAndSettle();
      expect(
        find.text(S.upToDateMsg(GitHubUpdateService.currentVersion)),
        findsOneWidget,
      );
    });

    testWidgets('HomeScreen header centers PacerLogo at 390px and 320px cleanly', (
      tester,
    ) async {
      for (final size in const [Size(390, 844), Size(320, 640)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            theme: PacerTheme.dark(),
            home: const Scaffold(body: HomeScreen()),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final logoCenter = tester.getCenter(find.byType(PacerLogo));
        expect(logoCenter.dx, closeTo(size.width / 2, 0.5));
      }
      await tester.binding.setSurfaceSize(null);
    });
  });
}
