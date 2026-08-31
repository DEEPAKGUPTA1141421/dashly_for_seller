import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../providers/notification_preferences_provider.dart';
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
            Container(
              color: AppColors.surface,
              padding: EdgeInsets.fromLTRB(4, MediaQuery.of(context).padding.top > 0 ? 8 : 16, 8, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.white, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3),
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.tune_rounded, color: AppColors.white, size: 20),
                            onPressed: () {
                              HapticUtils.light();
                              _showFilterSheet(context, ref);
                            },
                          ),
                          if (state.categoryFilter != null)
                            Positioned(
                              right: 8, top: 8,
                              child: Container(
                                width: 7, height: 7,
                                decoration: const BoxDecoration(color: AppColors.info, shape: BoxShape.circle),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(),
                  if (state.categoryFilter != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: _ActiveFilterChip(
                          label: notificationCategoryLabel(state.categoryFilter!),
                          onClear: () => ref.read(notificationsPod.notifier).setCategoryFilter(null),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(height: 1, color: AppColors.divider),
                ],
              ),
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
      case 'ORDER_UPDATES':    return (Icons.shopping_bag_rounded,     AppColors.info);
      case 'PAYMENT_UPDATES':  return (Icons.currency_rupee_rounded,   AppColors.success);
      case 'PRODUCT_UPDATES':  return (Icons.inventory_2_rounded,      AppColors.warning);
      case 'REVIEW_REMINDERS': return (Icons.star_rounded,             AppColors.warning);
      case 'WALLET_UPDATES':   return (Icons.account_balance_wallet_rounded, AppColors.success);
      case 'LOYALTY_UPDATES':  return (Icons.card_giftcard_rounded,    AppColors.white);
      case 'PROMOTIONS':       return (Icons.local_offer_rounded,      AppColors.white);
      case 'ACCOUNT_SECURITY': return (Icons.shield_rounded,           AppColors.error);
      case 'SYSTEM_ALERTS':    return (Icons.info_rounded,             AppColors.grey);
      default:                 return (Icons.notifications_rounded,   AppColors.grey);
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

// ── Filter sheet ─────────────────────────────────────────────────────────────

void _showFilterSheet(BuildContext context, WidgetRef ref) {
  ref.read(notificationPreferencesPod.notifier).fetch();
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _FilterSheet(),
  );
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;
  const _ActiveFilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppColors.info, fontSize: 12, fontWeight: FontWeight.w600)),
          GestureDetector(
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, color: AppColors.info, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationsPod);
    final prefState   = ref.watch(notificationPreferencesPod);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Filter', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Show only one category in your feed', style: TextStyle(color: AppColors.grey, fontSize: 12)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CategoryFilterChip(
                  label: 'All',
                  selected: notifState.categoryFilter == null,
                  onTap: () {
                    ref.read(notificationsPod.notifier).setCategoryFilter(null);
                    Navigator.of(context).pop();
                  },
                ),
                ...kNotificationCategories.map((category) => _CategoryFilterChip(
                      label: notificationCategoryLabel(category),
                      selected: notifState.categoryFilter == category,
                      onTap: () {
                        ref.read(notificationsPod.notifier).setCategoryFilter(category);
                        Navigator.of(context).pop();
                      },
                    )),
              ],
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('Notify me about', style: TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: () => ref.read(notificationPreferencesPod.notifier).setAll(true),
                  child: const Text('Select all', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => ref.read(notificationPreferencesPod.notifier).setAll(false),
                  child: const Text('Unselect all', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                ),
              ],
            ),
            if (prefState.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2)),
              )
            else
              ...kNotificationCategories.map((category) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(notificationCategoryLabel(category),
                        style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                    value: prefState.inAppEnabled[category] ?? true,
                    onChanged: (v) => ref.read(notificationPreferencesPod.notifier).setEnabled(category, v),
                  )),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryFilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticUtils.light(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.surface : AppColors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
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
