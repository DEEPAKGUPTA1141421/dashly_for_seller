import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

class ProTip {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const ProTip({required this.icon, required this.title, required this.onTap});
}

class ProTipsCard extends StatelessWidget {
  final List<ProTip> tips;

  const ProTipsCard({super.key, required this.tips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pro tips',
              style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Need some ideas to grow your shop?',
              style: TextStyle(color: AppColors.grey, fontSize: 12)),
          const SizedBox(height: 14),
          Wrap(
            runSpacing: 12,
            children: tips.map((t) => _TipTile(tip: t)).toList(),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _TipTile extends StatelessWidget {
  final ProTip tip;
  const _TipTile({required this.tip});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () { HapticUtils.light(); tip.onTap(); },
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
              child: Icon(tip.icon, color: AppColors.white, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(tip.title,
                  style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}
