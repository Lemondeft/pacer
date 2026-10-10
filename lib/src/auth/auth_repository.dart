import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/supabase.dart';
import 'package:pacer/src/auth/user_model.dart';

/// Backend-only auth (DFD process 1.0 LOGIN/KELOLA USER). No widgets.
///
/// Uses the anon-key client from [supa]; service_role is never referenced.
/// RLS on public.users allows insert/update only on the caller's own row.
/// Thrown when sign-up succeeds but email confirmation is pending:
/// there is a user but no session, so the profile row cannot be RLS-inserted.
class EmailConfirmationRequired implements Exception {
  const EmailConfirmationRequired();
}

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client}) : _client = client ?? supa;

  /// Registers via Supabase Auth, then creates the public.users profile row.
  /// Throws [EmailConfirmationRequired] when the project requires email
  /// confirmation (session == null): the row cannot be RLS-inserted yet.
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String nama,
  }) async {
    final res = await _client.auth.signUp(email: email, password: password);
    final user = res.user;
    if (user == null) {
      throw StateError('Sign-up succeeded without a user session.');
    }
    if (res.session == null) {
      throw const EmailConfirmationRequired();
    }
    await _client.from('users').insert(buildUserRow(id: user.id, nama: nama));
    final profile = await getProfile();
    return profile ?? UserProfile(id: user.id, nama: nama);
  }

  /// Email/password sign-in. Throws [AuthException] on bad credentials.
  /// Self-heals a missing profile row (e.g. signed up before confirmation).
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
    final id = currentUserId();
    if (id == null) return;
    final profile = await getProfile();
    if (profile == null) {
      try {
        await _client.from('users').insert(buildUserRow(id: id, nama: ''));
      } catch (_) {
        // RLS denial or race with a concurrent insert: profile stays missing
        // until the next sign-in; reads already tolerate a null profile.
      }
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  String? currentUserId() => _client.auth.currentUser?.id;

  /// Reads the caller's own profile row (RLS: id == auth.uid()).
  Future<UserProfile?> getProfile() async {
    final id = currentUserId();
    if (id == null) return null;
    final row = await _client.from('users').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(row));
  }

  /// Updates the caller's own display name.
  Future<void> updateProfile({required String nama}) async {
    final id = currentUserId();
    if (id == null) {
      throw StateError('No signed-in user.');
    }
    await _client.from('users').update({'nama': nama}).eq('id', id);
  }
}
