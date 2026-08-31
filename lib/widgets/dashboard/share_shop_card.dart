import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

/// Rotating marketing lines so the share text isn't the same canned sentence
/// every time — picked deterministically per shop (stable across re-shares
/// of the same shop) rather than fully random.
const List<String> _kTaglines = [
  'Shop smart, shop local — only on Dashly.',
  'Trusted sellers. Fast delivery. That\'s Dashly.',
  'Where local shops go online — find us on Dashly.',
  'Support local, shop better. Dashly has you covered.',
  'Real sellers, real fast delivery — Dashly.',
];

class ShareShopCard extends StatefulWidget {
  final String? sellerName;
  final int? totalProducts;
  final int? totalCustomers;
  final String? coverImageUrl;

  const ShareShopCard({
    super.key,
    this.sellerName,
    this.totalProducts,
    this.totalCustomers,
    this.coverImageUrl,
  });

  @override
  State<ShareShopCard> createState() => _ShareShopCardState();
}

class _ShareShopCardState extends State<ShareShopCard> {
  bool _sharing = false;

  String get _shopName =>
      (widget.sellerName == null || widget.sellerName!.isEmpty) ? 'my shop' : widget.sellerName!;

  String get _tagline => _kTaglines[_shopName.hashCode.abs() % _kTaglines.length];

  String get _shareText {
    final buffer = StringBuffer('🏬 $_shopName is on Dashly!\n\n');

    final products = widget.totalProducts ?? 0;
    final customers = widget.totalCustomers ?? 0;
    if (products > 0) buffer.writeln('🛍️ $products+ products available');
    if (customers > 0) buffer.writeln('⭐ Trusted by $customers+ customers');
    if (products > 0 || customers > 0) buffer.writeln();

    buffer.writeln(_tagline);
    buffer.write('Check us out on Dashly — great products, fast delivery!');
    return buffer.toString();
  }

  Future<void> _share() async {
    if (_sharing) return;
    HapticUtils.medium();
    setState(() => _sharing = true);
    try {
      final coverUrl = widget.coverImageUrl;
      if (coverUrl != null && coverUrl.isNotEmpty) {
        try {
          final res = await Dio().get<List<int>>(
            coverUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          final bytes = res.data;
          if (bytes != null && bytes.isNotEmpty) {
            final dir = await getTemporaryDirectory();
            final ext = coverUrl.split('.').last.split('?').first;
            final safeExt = ext.length <= 4 ? ext : 'jpg';
            final file = File('${dir.path}/shop-cover-${DateTime.now().microsecondsSinceEpoch}.$safeExt');
            await file.writeAsBytes(bytes, flush: true);
            await Share.shareXFiles(
              [XFile(file.path)],
              text: _shareText,
              subject: 'Check out $_shopName on Dashly',
            );
            return;
          }
        } catch (_) {
          // Fall through to text-only share below.
        }
      }
      await Share.share(_shareText, subject: 'Check out $_shopName on Dashly');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

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
          const Text('Get more customers!',
              style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Sharing your shop on social media helps new customers find you. Grow your earnings right now.',
            style: TextStyle(color: AppColors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ShareButton(icon: Icons.facebook_rounded, label: 'Facebook', onTap: _share, busy: _sharing),
              _ShareButton(icon: Icons.alternate_email_rounded, label: 'Twitter', onTap: _share, busy: _sharing),
              _ShareButton(icon: Icons.camera_alt_rounded, label: 'Instagram', onTap: _share, busy: _sharing),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool busy;
  const _ShareButton({required this.icon, required this.label, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                : Icon(icon, color: AppColors.white, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
