import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/catalog_listing_provider.dart';
import '../../models/catalog_product.dart';
import '../../utils/app_colors.dart';
import 'catalog_variant_screen.dart';

class CatalogSearchScreen extends ConsumerStatefulWidget {
  const CatalogSearchScreen({super.key});

  @override
  ConsumerState<CatalogSearchScreen> createState() => _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends ConsumerState<CatalogSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSelect(CatalogProduct product) {
    ref.read(catalogListingPod.notifier).selectProduct(product);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CatalogVariantScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogListingPod);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find Product',
          style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),

      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(color: AppColors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search Samsung M51, Maggi, Dove…',
                  hintStyle: const TextStyle(color: AppColors.grey, fontSize: 14),
                  prefixIcon: const Icon(CupertinoIcons.search, color: AppColors.grey, size: 18),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: AppColors.grey, size: 18),
                          onPressed: () {
                            _controller.clear();
                            ref.read(catalogListingPod.notifier).onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onChanged: ref.read(catalogListingPod.notifier).onSearchChanged,
              ),
            ),
          ),

          if (state.isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                backgroundColor: AppColors.surface,
                color: AppColors.white,
                minHeight: 2,
              ),
            )
          else
            const SizedBox(height: 2),

          // ── Results / states ────────────────────────────────────────────────
          Expanded(
            child: _buildBody(state),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(CatalogListingState state) {
    if (!state.searchDone && state.searchQuery.length < 2) {
      return _EmptyHint(
        icon: CupertinoIcons.search,
        title: 'Search the product catalog',
        subtitle: 'Type a product name, brand, or barcode.\nSelect the match and add your price & stock.',
      );
    }

    if (state.searchDone && state.searchResults.isEmpty) {
      return _EmptyHint(
        icon: CupertinoIcons.cube_box,
        title: 'No match found',
        subtitle: 'Try a different name or barcode.\nYou can also create a completely custom product.',
        action: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Create custom product →',
            style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: state.searchResults.length,
      separatorBuilder: (_, __) =>
          const Divider(color: AppColors.border, height: 1),
      itemBuilder: (_, i) => _ProductTile(
        product: state.searchResults[i],
        onTap: () => _onSelect(state.searchResults[i]),
      ),
    );
  }
}

// ── Product tile ──────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final CatalogProduct product;
  final VoidCallback onTap;

  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        CupertinoIcons.photo,
                        color: AppColors.greyDark,
                        size: 24,
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.photo,
                      color: AppColors.greyDark,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (product.brandName != null && product.brandName!.isNotEmpty) ...[
                        Text(
                          product.brandName!,
                          style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppColors.greyDark, fontSize: 12),
                        ),
                      ],
                      if (product.categoryName != null)
                        Flexible(
                          child: Text(
                            product.categoryName!,
                            style: const TextStyle(
                              color: AppColors.grey,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.greyDark,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty / hint widget ───────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.greyDark, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.grey, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
