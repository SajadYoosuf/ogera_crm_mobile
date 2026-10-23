/// Notifications screen — the in-app inbox.
///
/// WHAT IT SHOWS:
///   - A list of notifications, unread ones first.
///   - Tapping an item marks it as read.
///   - "Mark all read" action in the app bar.
///
/// PUSHED FROM:
///   The bell icon in the Home tab AppBar (NotificationBellButton).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/state_views.dart';
import '../../services/notification_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/notification_view_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationViewModel>();

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (vm.unreadCount > 0)
            TextButton(
              onPressed: vm.markAllRead,
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: Builder(
          builder: (context) {
            if (vm.isLoading) {
              return const LoadingListView(itemHeight: 72);
            }
            if (vm.error != null) {
              return ErrorStateView(
                message: vm.error!,
                onRetry: vm.load,
              );
            }
            if (vm.items.isEmpty) {
              return const EmptyStateView(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications',
                message: 'You are all caught up!',
              );
            }

            return ListView.separated(
              itemCount: vm.items.length,
              separatorBuilder: (context, _) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, i) => _NotifTile(
                item: vm.items[i],
                onTap: () => vm.markRead(vm.items[i].id),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 12),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isRead
                      ? Colors.transparent
                      : OgeraColors.blue,
                ),
              ),
            ),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          item.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: OgeraColors.muted,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(item.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: OgeraColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Bell button (used in HomeTab AppBar) ─────────────────────────────────────

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationViewModel>();
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: vm,
            child: const NotificationsScreen(),
          ),
        ),
      ),
      icon: Badge(
        isLabelVisible: vm.unreadCount > 0,
        label: Text(
          '${vm.unreadCount > 99 ? '99+' : vm.unreadCount}',
          style: const TextStyle(fontSize: 10),
        ),
        backgroundColor: OgeraColors.danger,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
