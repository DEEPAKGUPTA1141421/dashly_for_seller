import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/theme/responsive.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

/// Left sidebar navigation for tablet/desktop breakpoints — mirrors
/// [SellerBottomNav]'s tab list (same order/icons/labels), used in place
/// of the bottom nav bar when there's enough horizontal space.
class SidebarNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SidebarNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(
      icon:       CupertinoIcons.house,
      activeIcon: CupertinoIcons.house_fill,
      label: 'Dashboard',
    ),
    _NavItem(
      icon:       CupertinoIcons.doc_text,
      activeIcon: CupertinoIcons.doc_text_fill,
      label: 'Orders',
    ),
    _NavItem(
      icon:       CupertinoIcons.doc_plaintext,
      activeIcon: CupertinoIcons.doc_plaintext,
      label: 'Invoices',
    ),
    _NavItem(
      icon:       CupertinoIcons.cube_box,
      activeIcon: CupertinoIcons.cube_box_fill,
      label: 'Products',
    ),
    _NavItem(
      icon:       CupertinoIcons.chart_bar,
      activeIcon: CupertinoIcons.chart_bar_fill,
      label: 'Analytics',
    ),
    _NavItem(
      icon:       CupertinoIcons.gear,
      activeIcon: CupertinoIcons.gear_solid,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final iconOnly = Responsive.isTablet(context);
    final width = iconOnly ? 72.0 : 220.0;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        right: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Brand(iconOnly: iconOnly),
            const SizedBox(height: 8),
            for (var i = 0; i < _items.length; i++)
              _SidebarItem(
                item: _items[i],
                selected: i == currentIndex,
                iconOnly: iconOnly,
                onTap: () {
                  HapticUtils.light();
                  onTap(i);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool iconOnly;
  const _Brand({required this.iconOnly});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 20, vertical: 24),
      child: iconOnly
          ? const Center(
              child: Icon(CupertinoIcons.bag_fill, color: AppColors.accent, size: 26),
            )
          : const Row(
              children: [
                Icon(CupertinoIcons.bag_fill, color: AppColors.accent, size: 24),
                SizedBox(width: 10),
                Text(
                  'Dashly',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool iconOnly;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.iconOnly,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.accent : AppColors.grey;

    final content = iconOnly
        ? Center(
            child: Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: fg,
            ),
          )
        : Row(
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 20,
                color: fg,
              ),
              const SizedBox(width: 14),
              Text(
                item.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? AppColors.surface2 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: iconOnly ? 8 : 14,
              vertical: 12,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
