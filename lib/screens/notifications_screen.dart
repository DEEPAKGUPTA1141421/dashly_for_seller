import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../providers/notifications_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsPod.notifier).fetchNotifications());
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(notificationsPod.notifier).fetchNotifications(reset: false);
    }
  }

  Future<void> _refresh() async {
    HapticUtils.light();
    await ref.read(notificationsPod.notifier).fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsPod);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (state.unreadCount > 0)
                    TextButton(
                      onPressed: () {
                        HapticUtils.light();
                        ref.read(notificationsPod.notifier).markAllRead();
                      },
                      child: const Text('Mark all read', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                    ),
                ],
              ).animate().fadeIn(),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: state.isLoading
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: 6,
                      itemBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: AppShimmer(child: ShimmerBox(height: 80)),
                      ),
                    )
                  : state.notifications.isEmpty
                      ? _EmptyNotifications()
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          color: AppColors.white,
                          backgroundColor: AppColors.surface,
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: state.notifications.length + (state.isLoadingMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == state.notifications.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey),
                                  )),
                                );
                              }
                              final notif = state.notifications[i] as Map<String, dynamic>;
                              return _NotifTile(
                                notif: notif,
                                index: i,
                                onTap: () {
                                  if (notif['read'] != true) {
                                    ref.read(notificationsPod.notifier).markRead(notif['id'].toString());
                                  }
                                },
                                onDelete: () {
                                  HapticUtils.medium();
                                  ref.read(notificationsPod.notifier).deleteNotification(notif['id'].toString());
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tiles ──────────────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotifTile({
    required this.notif,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isRead    = notif['read'] == true;
    final category  = (notif['category'] as String? ?? 'INFO').toUpperCase();
    final title     = notif['title'] as String? ?? '';
    final body      = notif['body']  as String? ?? '';
    final createdAt = notif['createdAt'] as String? ?? '';

    final (iconData, iconColor) = _categoryIcon(category);

    return Dismissible(
      key: Key(notif['id']?.toString() ?? '$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRead ? AppColors.surface : AppColors.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRead ? AppColors.border : AppColors.white.withOpacity(0.15),
              width: isRead ? 1 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 13,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: AppColors.info, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.grey, fontSize: 12, height: 1.4),
                      ),
                    ],
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(createdAt),
                        style: const TextStyle(color: AppColors.greyDark, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: index * 30)).slideX(begin: 0.03, end: 0),
      ),
    );
  }

  (IconData, Color) _categoryIcon(String category) {
    switch (category) {
      case 'ORDER':   return (Icons.shopping_bag_rounded,   AppColors.info);
      case 'PAYMENT': return (Icons.currency_rupee_rounded, AppColors.success);
      case 'STOCK':   return (Icons.inventory_2_rounded,    AppColors.warning);
      case 'PROMO':   return (Icons.local_offer_rounded,    AppColors.white);
      default:        return (Icons.notifications_rounded,  AppColors.grey);
    }
  }

  String _formatTime(String iso) {
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24) return '${diff.inHours}h ago';
      if (diff.inDays    <  7) return '${diff.inDays}d ago';
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }
}

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.notifications_none_rounded, color: AppColors.greyDark, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No notifications yet', style: TextStyle(color: AppColors.grey, fontSize: 14)),
        ],
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
