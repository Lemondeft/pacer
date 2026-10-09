import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    return MaterialApp(
      title: 'Pacer',
      debugShowCheckedModeBanner: false,
      theme: PacerTheme.light(),
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  String _route = 'getStarted';

  @override
  Widget build(BuildContext context) {
    switch (_route) {
      case 'create':
        return CreateAccountScreen(
          onSubmitted: () => setState(() => _route = 'main'),
        );
      case 'login':
        return LoginScreen(onLoggedIn: () => setState(() => _route = 'main'));
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
