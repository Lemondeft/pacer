import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initialize Supabase. Reads SUPABASE_URL / SUPABASE_ANON_KEY from `.env`.
/// Get values from https://supabase.com/dashboard/project/_/settings/api
Future<void> initSupabase() async {
  final url = dotenv.env['SUPABASE_URL'] ?? '';
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (url.isEmpty || anonKey.isEmpty || url.contains('your-supabase')) {
    throw StateError(
      'Missing Supabase config. Copy .env.example to .env and set '
      'SUPABASE_URL and SUPABASE_ANON_KEY.',
    );
  }

  await Supabase.initialize(url: url, publishableKey: anonKey);
}

/// Global Supabase client accessor (valid after [initSupabase]).
SupabaseClient get supa => Supabase.instance.client;
