import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Classifies errors that indicate connectivity/backend unreachability rather
/// than deterministic validation or RLS failures.
bool isTransientNetworkError(Object error) {
  if (error is TimeoutException) return true;
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code.startsWith('5')) return true;
  }
  final typeName = error.runtimeType.toString().toLowerCase();
  if (typeName.contains('socketexception') ||
      typeName.contains('handshakeexception') ||
      typeName.contains('clientexception')) {
    return true;
  }
  final msg = error.toString().toLowerCase();
  return msg.contains('socketexception') ||
      msg.contains('failed host lookup') ||
      msg.contains('connection refused') ||
      msg.contains('connection timed out') ||
      msg.contains('connection reset') ||
      msg.contains('connection closed') ||
      msg.contains('network is unreachable') ||
      msg.contains('clientexception') ||
      msg.contains('xmlhttprequest') ||
      msg.contains('failed to fetch') ||
      msg.contains('timed out');
}

/// True when an error reflects an expired or invalid auth session that needs
/// refresh/re-login before protected outbox mutations can continue.
bool isAuthSessionError(Object error) {
  if (error is AuthException) return true;
  if (error is PostgrestException) {
    final code = (error.code ?? '').toUpperCase();
    final msg = error.message.toLowerCase();
    return code == 'PGRST301' ||
        code == '401' ||
        msg.contains('jwt expired') ||
        msg.contains('invalid jwt');
  }
  return false;
}

/// Tracks OS transport connectivity plus observed Supabase request outcomes.
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService();

  final Connectivity? _connectivity;
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool? _testOverride;
  bool _started = false;

  ConnectivityService({this._connectivity});

  Connectivity get _plugin => _connectivity ?? Connectivity();

  bool get value => _testOverride ?? isOnline.value;

  /// Test hook: forces online/offline state without platform channels.
  void setTestOverride(bool? online) {
    _testOverride = online;
    if (online != null && isOnline.value != online) {
      isOnline.value = online;
    }
  }

  /// Starts OS connectivity monitoring; safe no-op in headless widget tests.
  Future<void> init({void Function()? onReconnect}) async {
    if (_started) return;
    _started = true;
    try {
      final initial = await _plugin.checkConnectivity();
      _applyResults(initial, onReconnect: null);
    } catch (_) {
      // MissingPluginException in widget tests: keep optimistic default.
    }
    try {
      _sub = _plugin.onConnectivityChanged.listen(
        (results) => _applyResults(results, onReconnect: onReconnect),
        onError: (_) {},
      );
    } catch (_) {}
  }

  void reportReachable(bool reachable) {
    if (_testOverride != null) return;
    if (isOnline.value != reachable) {
      isOnline.value = reachable;
    }
  }

  void _applyResults(
    List<ConnectivityResult> results, {
    required void Function()? onReconnect,
  }) {
    if (_testOverride != null) return;
    final hasTransport = results.any((r) => r != ConnectivityResult.none);
    final wasOffline = !isOnline.value;
    isOnline.value = hasTransport;
    if (hasTransport && wasOffline) {
      onReconnect?.call();
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
