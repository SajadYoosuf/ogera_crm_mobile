/// NotificationViewModel manages the notification inbox state.
///
/// WHAT IT DOES:
///   - Loads the notification list from GET /notifications.
///   - Tracks unread_count for the bell badge.
///   - Provides optimistic updates for mark-read actions.
///
/// WHY OPTIMISTIC UPDATES:
///   Tapping a notification should feel instant. We update the local list
///   immediately and then let the server confirm in the background.
library;

import 'package:flutter/foundation.dart';

import '../services/notification_service.dart';

class NotificationViewModel extends ChangeNotifier {
  NotificationViewModel(this._service);

  final NotificationService _service;

  bool _isLoading = false;
  String? _error;
  final List<AppNotification> _items = [];
  int _unreadCount = 0;

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Loading ──────────────────────────────────────────────────────────────

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.list();
      _items
        ..clear()
        ..addAll(result.items);
      _unreadCount = result.unreadCount;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Marks all notifications as read (optimistic: updates UI immediately).
  Future<void> markAllRead() async {
    // Optimistic: flip all items locally first.
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true);
      }
    }
    _unreadCount = 0;
    notifyListeners();

    try {
      await _service.markAllRead();
    } catch (_) {
      // Silent fail — the backend will resync on next load.
    }
  }

  /// Marks one notification as read (optimistic).
  Future<void> markRead(int id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1 && !_items[idx].isRead) {
      _items[idx] = _items[idx].copyWith(isRead: true);
      if (_unreadCount > 0) _unreadCount--;
      notifyListeners();
    }

    try {
      await _service.markRead(id);
    } catch (_) {
      // Silent fail.
    }
  }

  /// Called when an FCM push arrives to increment the badge count
  /// without reloading the full list.
  void onPushReceived() {
    _unreadCount++;
    notifyListeners();
  }
}
