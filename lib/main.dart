import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pacer/src/auth/auth_repository.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/more_screens.dart';
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
        builder: (context, mode, _) => MaterialApp(
          title: 'Pacer',
          debugShowCheckedModeBanner: false,
          theme: PacerTheme.light(),
          darkTheme: PacerTheme.dark(),
          themeMode: mode,
          home: const _Root(),
        ),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  String _route = 'loading';

  Future<void> _resolveInitialRoute() async {
    var next = 'getStarted';
    try {
      final auth = AuthRepository();
      final uid = await auth.resolveUserId();
      if (uid != null) {
        next = 'main';
        if (!langUserLocked) {
          final value = await auth.getLanguage();
          if (value == 'en' && langNotifier.value != Lang.en) {
            langNotifier.value = Lang.en;
          } else if (value == 'id' && langNotifier.value != Lang.id) {
            langNotifier.value = Lang.id;
          }
        }
        await SyncEngine.instance.refreshCounts(userId: uid);
        SyncEngine.instance.triggerSync(userId: uid);
      }
    } catch (_) {
      // Demo mode: stay on GetStarted.
    }
    if (!mounted) return;
    setState(() => _route = next);
  }

  void _enterMain() {
    setState(() => _route = 'main');
    AuthRepository().resolveUserId().then((uid) {
      if (uid != null) {
        SyncEngine.instance.triggerSync(userId: uid);
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    switch (_route) {
      case 'loading':
        return LoadingScreen(
          onDone: () {
            if (!mounted) return;
            _resolveInitialRoute();
          },
        );
      case 'create':
        return CreateAccountScreen(
          onSubmitted: _enterMain,
          // Root-switched screens have no route to pop: back means GetStarted.
          onBack: () => setState(() => _route = 'getStarted'),
        );
      case 'login':
        return LoginScreen(
          onLoggedIn: _enterMain,
          onBack: () => setState(() => _route = 'getStarted'),
        );
      case 'main':
        return const MainShell();
      case 'getStarted':
      default:
        return GetStartedScreen(
          onSignIn: () => setState(() => _route = 'create'),
          onLogIn: () => setState(() => _route = 'login'),
        );
    }
  }
}
