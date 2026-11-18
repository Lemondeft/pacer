import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/notifications/notification_model.dart';
import 'package:pacer/src/sync/connectivity_service.dart';

/// Offline-first repository + realtime listener for member notifications.
class NotificationRepository {
  final SupabaseClient? _clientOverride;
  final LocalStore? _storeOverride;
  RealtimeChannel? _channel;

  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> revisionNotifier = ValueNotifier<int>(0);
  static final Set<String> _dismissedBannerIds = {};

  NotificationRepository({SupabaseClient? client, LocalStore? store})
    : _clientOverride = client,
      _storeOverride = store;

  SupabaseClient? get _client => safeSupabaseClient(_clientOverride);
  LocalStore get _store => _storeOverride ?? LocalStore.instance;

  /// Marks an in-app banner notification dismissed for this session.
  static void dismissBanner(String notificationId) {
    if (_dismissedBannerIds.add(notificationId)) {
      revisionNotifier.value++;
    }
  }

  /// Clears session banner dismissals (for logout/demo reset/tests).
  static void resetBannerDismissals() {
    if (_dismissedBannerIds.isNotEmpty) {
      _dismissedBannerIds.clear();
      revisionNotifier.value++;
    }
  }

  /// Resets unread counter, dismissed banners, and bumps revision on sign-out
  /// or account switch so stale badges/banners from prior users disappear.
  static void resetSession() {
    _dismissedBannerIds.clear();
    if (unreadCountNotifier.value != 0) {
      unreadCountNotifier.value = 0;
    }
    revisionNotifier.value++;
  }

  /// Returns the newest unread team-challenge assignment notification not yet dismissed.
  static AppNotification? topAssignedBannerFrom(List<AppNotification> items) {
    for (final n in items) {
      if (!n.isRead &&
          n.type == 'team_challenge_assigned' &&
          !_dismissedBannerIds.contains(n.id)) {
        return n;
      }
    }
    return null;
  }

  static void _syncUnreadCount(List<AppNotification> items) {
    final unread = items.where((n) => !n.isRead).length;
    if (unreadCountNotifier.value != unread) {
      unreadCountNotifier.value = unread;
    }
  }

  /// Refreshes notification counters from in-memory Demo Mode items.
  static void syncDemoUnread() {
    _syncUnreadCount(PacerDummyData.getDemoNotifications());
    revisionNotifier.value++;
  }

  Future<List<AppNotification>> listNotifications({
    bool forceRefresh = false,
  }) async {
    if (await isDemoAccount(client: _client, store: _store)) {
      final items = PacerDummyData.getDemoNotifications();
      _syncUnreadCount(items);
      return items;
    }
    final userId = await resolveActiveUserId(client: _client, store: _store);
    if (userId == null) return const [];
    final c = _client;
    return offlineRead<List<AppNotification>>(
      store: _store,
      syncKey: 'notifications_$userId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(seconds: 45),
      readLocal: () async {
        final local = await _store.getNotifications(userId);
        _syncUnreadCount(local);
        return local;
      },
      fetchRemote: () async {
        final rows = await c!
            .from('user_notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(50);
        final remote = [
          for (final row in rows)
            AppNotification.fromJson(Map<String, dynamic>.from(row)),
        ];
        await _store.saveNotifications(userId, remote);
        _syncUnreadCount(remote);
        return remote;
      },
      writeLocal: (_) async {},
      isEmpty: (list) => list.isEmpty,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    if (await isDemoAccount(client: _client, store: _store)) {
      PacerDummyData.markDemoNotificationRead(notificationId);
      _syncUnreadCount(PacerDummyData.getDemoNotifications());
      revisionNotifier.value++;
      return;
    }
    final userId = await resolveActiveUserId(client: _client, store: _store);
    if (userId == null) return;
    await _store.markNotificationReadLocal(userId, notificationId);
    final updated = await _store.getNotifications(userId);
    _syncUnreadCount(updated);
    revisionNotifier.value++;
    final c = _client;
    if (c != null && c.auth.currentUser != null) {
      try {
        await c
            .from('user_notifications')
            .update({'is_read': true})
            .eq('id', notificationId)
            .eq('user_id', userId);
      } catch (_) {}
    }
  }

  Future<void> markAllRead() async {
    if (await isDemoAccount(client: _client, store: _store)) {
      PacerDummyData.markAllDemoNotificationsRead();
      _syncUnreadCount(PacerDummyData.getDemoNotifications());
      revisionNotifier.value++;
      return;
    }
    final userId = await resolveActiveUserId(client: _client, store: _store);
    if (userId == null) return;
    await _store.markAllNotificationsReadLocal(userId);
    unreadCountNotifier.value = 0;
    revisionNotifier.value++;
    final c = _client;
    if (c != null && c.auth.currentUser != null) {
      try {
        await c
            .from('user_notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('is_read', false);
      } catch (_) {}
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    if (await isDemoAccount(client: _client, store: _store)) {
      PacerDummyData.deleteDemoNotification(notificationId);
      _syncUnreadCount(PacerDummyData.getDemoNotifications());
      revisionNotifier.value++;
      return;
    }
    final userId = await resolveActiveUserId(client: _client, store: _store);
    if (userId == null) return;
    await _store.deleteNotificationLocal(userId, notificationId);
    final updated = await _store.getNotifications(userId);
    _syncUnreadCount(updated);
    revisionNotifier.value++;
    final c = _client;
    if (c != null && c.auth.currentUser != null) {
      try {
        await c
            .from('user_notifications')
            .delete()
            .eq('id', notificationId)
            .eq('user_id', userId);
      } catch (_) {}
    }
  }

  Future<void> clearAllNotifications() async {
    if (await isDemoAccount(client: _client, store: _store)) {
      PacerDummyData.clearDemoNotifications();
      _syncUnreadCount(const []);
      revisionNotifier.value++;
      return;
    }
    final userId = await resolveActiveUserId(client: _client, store: _store);
    if (userId == null) return;
    await _store.clearNotificationsLocal(userId);
    unreadCountNotifier.value = 0;
    revisionNotifier.value++;
    final c = _client;
    if (c != null && c.auth.currentUser != null) {
      try {
        await c.from('user_notifications').delete().eq('user_id', userId);
      } catch (_) {}
    }
  }

  Future<void> refreshUnreadCount({bool forceRefresh = false}) async {
    try {
      await listNotifications(forceRefresh: forceRefresh);
    } catch (_) {}
  }

  /// Subscribes to live inserts on `public.user_notifications` for the active user.
  void watchNotifications({void Function(AppNotification)? onIncoming}) {
    dispose();
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null || !ConnectivityService.instance.value) {
      return;
    }
    _channel = c
        .channel('user_notifications:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final item = AppNotification.fromJson(
              Map<String, dynamic>.from(payload.newRecord),
            );
            unawaited(() async {
              final existing = await _store.getNotifications(uid);
              final merged = [
                item,
                for (final e in existing)
                  if (e.id != item.id) e,
              ];
              await _store.saveNotifications(uid, merged);
              _syncUnreadCount(merged);
              revisionNotifier.value++;
            }());
            onIncoming?.call(item);
          },
        )
        .subscribe();
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
