import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/widgets/app_toast.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

/// Opens a high-quality bottom sheet for sharing a product across social
/// platforms. The list of platforms (label, color, icon, share action) is
/// backend-driven — fetched from GET /api/v1/config/social_share_platforms —
/// so it can be reordered/added-to/removed without an app release.
Future<void> showShareProductSheet(BuildContext context, Map product) {
  HapticUtils.medium();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ShareProductSheet(product: product),
  );
}

// ── Icon-key → Flutter glyph. Only the visual glyph lives on the client;
// the label/color/order/action all come from the backend config. ─────────
const Map<String, IconData> _kIcons = {
  'whatsapp':  Icons.chat_rounded,
  'telegram':  Icons.send_rounded,
  'twitter':   Icons.close_rounded,
  'facebook':  Icons.facebook_rounded,
  'instagram': Icons.camera_alt_rounded,
  'sms':       Icons.sms_rounded,
  'email':     Icons.email_rounded,
  'more':      Icons.more_horiz_rounded,
};

class SharePlatform {
  final String key;
  final String label;
  final Color color;
  final String icon;
  final String action; // 'deeplink' | 'system_share'
  final int order;
  final String? urlTemplate;
  final String? fallbackUrlTemplate;

  SharePlatform({
    required this.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.action,
    required this.order,
    this.urlTemplate,
    this.fallbackUrlTemplate,
  });

  factory SharePlatform.fromJson(Map<String, dynamic> j) {
    Color parseColor(String? hex) {
      if (hex == null || hex.isEmpty) return AppColors.white;
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    }

    final orderRaw = j['order'];
    return SharePlatform(
      key:      j['key'] as String? ?? '',
      label:    j['label'] as String? ?? '',
      color:    parseColor(j['color'] as String?),
      icon:     j['icon'] as String? ?? 'more',
      action:   j['action'] as String? ?? 'system_share',
      order:    orderRaw is num ? orderRaw.toInt() : 0,
      urlTemplate:         j['urlTemplate'] as String?,
      fallbackUrlTemplate: j['fallbackUrlTemplate'] as String?,
    );
  }
}

class ShareProductSheet extends StatefulWidget {
  final Map product;
  const ShareProductSheet({super.key, required this.product});

  @override
  State<ShareProductSheet> createState() => _ShareProductSheetState();
}

class _ShareProductSheetState extends State<ShareProductSheet> {
  bool _loading = true;
  String? _error;
  List<SharePlatform> _platforms = [];

  @override
  void initState() {
    super.initState();
    _fetchPlatforms();
  }

  Future<void> _fetchPlatforms() async {
    try {
      final res  = await ApiClient.instance.client
          .get('${ApiEndpoints.config}/social_share_platforms');
      final body = res.data as Map<String, dynamic>?;
      final data = body?['data'];
      if (data is List) {
        final list = data
            .whereType<Map>()
            .map((e) => SharePlatform.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        setState(() {
          _platforms = list;
          _loading   = false;
        });
        return;
      }
      setState(() { _error = 'No share platforms configured'; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load share options'; _loading = false; });
    }
  }

  String get _name => widget.product['name'] as String? ?? 'Product';

  String get _priceStr {
    final raw = widget.product['price'];
    final num_ = raw is num ? raw : num.tryParse(raw?.toString() ?? '') ?? 0;
    return num_ == num_.truncate() ? num_.toInt().toString() : num_.toStringAsFixed(2);
  }

  String get _imageUrl => widget.product['imageUrl'] as String? ?? '';

  String get _brand => widget.product['brand'] as String? ?? '';

  String get _shareText {
    final brandPart = _brand.isNotEmpty ? ' by $_brand' : '';
    return 'Check out "$_name"$brandPart — ₹$_priceStr\n\n'
        'Available now on Dashly. Grab yours today!';
  }

  Future<void> _handleTap(SharePlatform p) async {
    HapticUtils.light();
    try {
      if (p.action == 'deeplink' && p.urlTemplate != null) {
        final text    = Uri.encodeComponent(_shareText);
        final subject = Uri.encodeComponent('Check out $_name');
        final url = p.urlTemplate!.replaceAll('{text}', text).replaceAll('{subject}', subject);
        final fallback = p.fallbackUrlTemplate
            ?.replaceAll('{text}', text)
            .replaceAll('{subject}', subject);
        await _launch(Uri.parse(url), fallback: fallback != null ? Uri.parse(fallback) : null);
      } else {
        await Share.share(_shareText, subject: _name);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Could not open ${p.label}', type: ToastType.error);
      }
    }
  }

  Future<void> _launch(Uri uri, {Uri? fallback}) async {
    try {
      final canLaunch = await canLaunchUrl(uri);
      final ok = canLaunch && await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && fallback != null) {
        final canLaunchFallback = await canLaunchUrl(fallback);
        if (canLaunchFallback) {
          await launchUrl(fallback, mode: LaunchMode.externalApplication);
          return;
        }
      }
      if (!ok && fallback == null && mounted) {
        AppToast.show(context, message: 'No app found to open this', type: ToastType.error);
      }
    } catch (_) {
      if (fallback != null) {
        try {
          await launchUrl(fallback, mode: LaunchMode.externalApplication);
          return;
        } catch (_) {}
      }
      if (mounted) AppToast.show(context, message: 'No app found to share this', type: ToastType.error);
    }
  }

  Future<void> _copyLink() async {
    HapticUtils.light();
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (mounted) AppToast.show(context, message: 'Copied to clipboard', type: ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, -8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text('Share Product',
                    style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: AppColors.grey, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Product preview card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 52, height: 52,
                      color: AppColors.surface3,
                      child: _imageUrl.isNotEmpty
                          ? Image.network(_imageUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: AppColors.greyDark, size: 22))
                          : const Icon(Icons.inventory_2_rounded, color: AppColors.greyDark, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text('₹$_priceStr',
                            style: const TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.08, end: 0),

          const SizedBox(height: 20),

          // Social grid — backend-driven
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2)),
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Text(_error!, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () { setState(() { _loading = true; _error = null; }); _fetchPlatforms(); },
                              child: const Text('Retry', style: TextStyle(color: AppColors.info, fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      )
                    : GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.82,
                        children: [
                          for (var i = 0; i < _platforms.length; i++)
                            _ShareTile(
                              platform: _platforms[i],
                              onTap: () => _handleTap(_platforms[i]),
                              delay: i,
                            ),
                        ],
                      ),
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(height: 1, color: AppColors.divider),
          ),
          const SizedBox(height: 4),

          // Copy link row
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
            child: GestureDetector(
              onTap: _copyLink,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.link_rounded, color: AppColors.grey, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Copy product details',
                          style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.copy_rounded, color: AppColors.grey, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareTile extends StatelessWidget {
  final SharePlatform platform;
  final VoidCallback onTap;
  final int delay;

  const _ShareTile({required this.platform, required this.onTap, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    final iconColor = platform.color.computeLuminance() > 0.6 ? AppColors.bg : AppColors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: platform.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: platform.color.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Icon(_kIcons[platform.icon] ?? Icons.share_rounded, color: iconColor, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          platform.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.grey, fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
      ],
    ).animate().fadeIn(delay: Duration(milliseconds: 40 * delay), duration: 220.ms).scale(begin: const Offset(0.85, 0.85));
  }
}
