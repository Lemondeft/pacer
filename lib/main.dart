import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassShaders;
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/screens.dart';
import 'package:pacer/supabase.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLanguagePreference();
  await LocalStore.init();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Demo mode: no .env bundled (no secrets in repo).
  }
  try {
    await initSupabase();
  } catch (_) {
    // Demo mode: run Figma-derived UI without backend.
  }
  await SyncEngine.instance.init();
  unawaited(LiquidGlassShaders.ensureLoaded().catchError((_) {}));
  runApp(const PacerApp());
}

class PacerApp extends StatelessWidget {
  const PacerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole tree when the language toggles so every S.* string
    // re-resolves without per-screen listeners. The nested theme listener
    // does the same for ThemeMode.system/light/dark (theme toggle only —
    // routing below is untouched).
    return ValueListenableBuilder<Lang>(
      valueListenable: langNotifier,
      builder: (context, _, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, mode, _) => ValueListenableBuilder<PacerLinuxTheme>(
          valueListenable: linuxThemeNotifier,
          builder: (context, preset, _) => MaterialApp(
            title: 'Pacer',
            debugShowCheckedModeBanner: false,
            theme: PacerTheme.light(preset),
            darkTheme: PacerTheme.dark(preset),
            themeMode: mode,
            home: const PacerAuthFlow(startWithSplash: true),
          ),
        ),
      ),
    );
  }
}
