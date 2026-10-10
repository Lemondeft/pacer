import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:pacer/src/ui/screens.dart';
import 'package:pacer/supabase.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const PacerApp());
}

class PacerApp extends StatelessWidget {
  const PacerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole tree when the language toggles so every S.* string
    // re-resolves without per-screen listeners.
    return ValueListenableBuilder<Lang>(
      valueListenable: langNotifier,
      builder: (context, _, _) => MaterialApp(
        title: 'Pacer',
        debugShowCheckedModeBanner: false,
        theme: PacerTheme.light(),
        themeMode: ThemeMode.light,
        home: const _Root(),
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

  @override
  Widget build(BuildContext context) {
    switch (_route) {
      case 'loading':
        return LoadingScreen(
          onDone: () {
            if (mounted) setState(() => _route = 'getStarted');
          },
        );
      case 'create':
        return CreateAccountScreen(
          onSubmitted: () => setState(() => _route = 'main'),
          // Root-switched screens have no route to pop: back means GetStarted.
          onBack: () => setState(() => _route = 'getStarted'),
        );
      case 'login':
        return LoginScreen(
          onLoggedIn: () => setState(() => _route = 'main'),
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
