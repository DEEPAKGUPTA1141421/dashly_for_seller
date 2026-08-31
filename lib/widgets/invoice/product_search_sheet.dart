import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

/// Search sheet over the seller's own live products — used both by the
/// "Search product" button and (with a pre-filled, non-editable query) by
/// the barcode scanner, so a scanned code and a typed search resolve to the
/// exact same product-picking UX and result shape.
class ProductSearchSheet extends StatefulWidget {
  final String? initialQuery;
  const ProductSearchSheet({super.key, this.initialQuery});

  /// Resolves to the picked product map ({id, name, imageUrl, price, brand, ...})
  /// or null if dismissed without a pick.
  static Future<Map<String, dynamic>?> show(BuildContext context, {String? initialQuery}) {
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductSearchSheet(initialQuery: initialQuery),
    );
  }

  @override
  State<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<ProductSearchSheet> {
  late final TextEditingController _ctrl;
  Timer? _debounce;
  bool _loading = false;
  bool _searched = false;
  List<dynamic> _results = [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _search(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.client.get(
        ApiEndpoints.sellerProducts,
        queryParameters: {'page': 0, 'size': 20, 'query': query.trim(), 'isActive': true},
      );
      final body = res.data as Map<String, dynamic>?;
      final data = body?['data'];
      final list = (data is Map && data['products'] is List)
          ? List<dynamic>.from(data['products'] as List)
          : <dynamic>[];
      if (mounted) setState(() { _results = list; _loading = false; _searched = true; });
    } catch (_) {
      if (mounted) setState(() { _results = []; _loading = false; _searched = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Search Product', style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: AppColors.grey, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _ctrl,
                autofocus: widget.initialQuery == null,
                onChanged: _onChanged,
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search your products…',
                  hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey, size: 20),
                  filled: true,
                  fillColor: AppColors.surface2,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey))
                  : !_searched
                      ? const Center(child: Text('Type to search your products', style: TextStyle(color: AppColors.greyDark, fontSize: 13)))
                      : _results.isEmpty
                          ? _NotFound(query: _ctrl.text)
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 16),
                              itemCount: _results.length,
                              itemBuilder: (_, i) {
                                final p = _results[i] as Map;
                                final name = p['name'] as String? ?? 'Product';
                                final price = _numOf(p['price']).toDouble();
                                final imageUrl = p['imageUrl'] as String?;
                                return GestureDetector(
                                  onTap: () {
                                    HapticUtils.light();
                                    Navigator.of(context).pop(Map<String, dynamic>.from(p));
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface2,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: 44, height: 44,
                                            color: AppColors.surface3,
                                            child: imageUrl != null && imageUrl.isNotEmpty
                                                ? Image.network(imageUrl, fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, color: AppColors.grey, size: 18))
                                                : const Icon(Icons.inventory_2_rounded, color: AppColors.grey, size: 18),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: AppColors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                                        ),
                                        Text('₹${price.toStringAsFixed(0)}',
                                            style: const TextStyle(color: AppColors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

num _numOf(dynamic v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? 0;
}

class _NotFound extends StatelessWidget {
  final String query;
  const _NotFound({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, color: AppColors.greyDark, size: 36),
            const SizedBox(height: 12),
            const Text('No matching products', style: TextStyle(color: AppColors.grey, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('"$query" isn\'t in your catalog — add it as a custom item instead.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.greyDark, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
