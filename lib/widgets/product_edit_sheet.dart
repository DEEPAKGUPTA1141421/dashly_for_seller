import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../providers/products_provider.dart';
import '../utils/app_colors.dart';

class ProductEditSheet extends ConsumerStatefulWidget {
  final Map product;

  const ProductEditSheet({super.key, required this.product});

  static Future<bool> show(BuildContext context, Map product) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ProductEditSheet(product: product),
        ) ??
        false;
  }

  @override
  ConsumerState<ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends ConsumerState<ProductEditSheet> {
  bool _loading = true;
  Map<String, dynamic> _editData = {};

  // Basic info
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  // Brand
  String? _selectedBrandId;

  // Tags
  List<Map<String, dynamic>> _tags = [];
  final _tagCtrl = TextEditingController();

  // Attributes
  List<Map<String, dynamic>> _attributes = [];
  final Map<String, TextEditingController> _attrCtrls = {};

  bool _savingBasic      = false;
  bool _savingBrand      = false;
  bool _savingAttrs      = false;
  bool _addingTag        = false;

  String get _productId => (widget.product['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product['name'] as String? ?? '');
    _descCtrl = TextEditingController();
    _selectedBrandId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEditData());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    for (final c in _attrCtrls.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadEditData() async {
    final data = await ref.read(productsPod.notifier).fetchEditData(_productId);
    if (!mounted) return;
    _editData = data;

    // Populate fields
    _nameCtrl.text = data['name'] as String? ?? _nameCtrl.text;
    _descCtrl.text = data['description'] as String? ?? '';
    _selectedBrandId = data['brandId'] as String?;
    _tags = (data['tags'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .toList() ??
        [];

    final rawAttrs = (data['attributes'] as List<dynamic>?) ?? [];
    _attributes = rawAttrs
        .cast<Map<String, dynamic>>()
        .where((a) => !(a['isImage'] as bool? ?? false))
        .toList();

    for (final a in _attributes) {
      final id = a['productAttributeId'] as String;
      _attrCtrls[id] =
          TextEditingController(text: a['value'] as String? ?? '');
    }

    setState(() => _loading = false);
  }

  // ── Save basic info ────────────────────────────────────────────────────────
  Future<void> _saveBasic() async {
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (name.length < 2) {
      AppToast.show(context, message: 'Name must be at least 2 characters', type: ToastType.error);
      return;
    }
    if (desc.length < 2) {
      AppToast.show(context, message: 'Description must be at least 2 characters', type: ToastType.error);
      return;
    }
    final catId = _editData['categoryId'] as String? ?? '';
    final step  = _editData['step']       as String? ?? 'LIVE';
    if (catId.isEmpty) {
      AppToast.show(context, message: 'Category not found — reopen product', type: ToastType.error);
      return;
    }
    setState(() => _savingBasic = true);
    final ok = await ref.read(productsPod.notifier).updateBasicInfo(
      _productId,
      name: name, description: desc, categoryId: catId, step: step,
    );
    if (!mounted) return;
    setState(() => _savingBasic = false);
    AppToast.show(context,
        message: ok ? 'Basic info saved' : ref.read(productsPod).error ?? 'Save failed',
        type: ok ? ToastType.success : ToastType.error);
  }

  // ── Save brand ─────────────────────────────────────────────────────────────
  Future<void> _saveBrand() async {
    if (_selectedBrandId == null) return;
    setState(() => _savingBrand = true);
    final ok = await ref
        .read(productsPod.notifier)
        .updateBrand(_productId, _selectedBrandId!);
    if (!mounted) return;
    setState(() => _savingBrand = false);
    AppToast.show(context,
        message: ok ? 'Brand updated' : ref.read(productsPod).error ?? 'Update failed',
        type: ok ? ToastType.success : ToastType.error);
  }

  // ── Add tag ────────────────────────────────────────────────────────────────
  Future<void> _addTag() async {
    final tag = _tagCtrl.text.trim();
    if (tag.isEmpty) return;
    setState(() => _addingTag = true);
    final ok = await ref.read(productsPod.notifier).addTags(_productId, [tag]);
    if (!mounted) return;
    setState(() => _addingTag = false);
    if (ok) {
      _tagCtrl.clear();
      setState(() {
        _tags.add({'id': '', 'name': tag});
      });
      AppToast.show(context, message: 'Tag added', type: ToastType.success);
    } else {
      AppToast.show(context,
          message: ref.read(productsPod).error ?? 'Failed to add tag',
          type: ToastType.error);
    }
  }

  // ── Remove tag ─────────────────────────────────────────────────────────────
  Future<void> _removeTag(Map<String, dynamic> tag) async {
    final tagId = tag['id'] as String? ?? '';
    if (tagId.isEmpty) {
      setState(() => _tags.remove(tag));
      return;
    }
    final ok = await ref.read(productsPod.notifier).removeTag(_productId, tagId);
    if (!mounted) return;
    if (ok) {
      setState(() => _tags.remove(tag));
    } else {
      AppToast.show(context, message: 'Failed to remove tag', type: ToastType.error);
    }
  }

  // ── Save attributes ────────────────────────────────────────────────────────
  Future<void> _saveAttrs() async {
    final step = _editData['step'] as String? ?? 'LIVE';
    final attrs = _attributes.map((a) {
      final id = a['productAttributeId'] as String;
      return {
        'productAttributeId':  a['productAttributeId'],
        'categoryAttributeId': a['categoryAttributeId'],
        'value': _attrCtrls[id]?.text.trim() ?? '',
      };
    }).where((a) => (a['value'] as String).isNotEmpty).toList();

    if (attrs.isEmpty) return;
    setState(() => _savingAttrs = true);
    final ok = await ref
        .read(productsPod.notifier)
        .saveAttributes(_productId, step, attrs.cast<Map<String, dynamic>>());
    if (!mounted) return;
    setState(() => _savingAttrs = false);
    AppToast.show(context,
        message: ok ? 'Attributes saved' : ref.read(productsPod).error ?? 'Save failed',
        type: ok ? ToastType.success : ToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    final brands = ref.watch(productsPod).brands;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  const Text('Edit Product',
                      style: TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (_loading)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? _buildShimmer()
                  : SingleChildScrollView(
                      controller: ctrl,
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBasicSection(),
                          const SizedBox(height: 16),
                          _buildBrandSection(brands),
                          const SizedBox(height: 16),
                          _buildTagsSection(),
                          if (_attributes.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildAttributesSection(),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _buildBasicSection() {
    return _SectionCard(
      title: 'Basic Info',
      child: Column(
        children: [
          _Field(label: 'Product Name', controller: _nameCtrl, hint: 'Product name'),
          const SizedBox(height: 12),
          _Field(
            label: 'Description',
            controller: _descCtrl,
            hint: 'Product description',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _SaveButton(
            label: 'Save Basic Info',
            loading: _savingBasic,
            onTap: _saveBasic,
          ),
        ],
      ),
    );
  }

  Widget _buildBrandSection(List<dynamic> brands) {
    return _SectionCard(
      title: 'Brand',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedBrandId,
            hint: const Text('Select brand',
                style: TextStyle(color: AppColors.greyDark, fontSize: 14)),
            dropdownColor: AppColors.surface2,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.white, width: 1.5)),
            ),
            style: const TextStyle(color: AppColors.white, fontSize: 14),
            items: brands.map((b) {
              final m = b as Map;
              return DropdownMenuItem<String>(
                value: m['id']?.toString(),
                child: Text(m['name']?.toString() ?? '',
                    style: const TextStyle(color: AppColors.white)),
              );
            }).toList(),
            onChanged: (v) {
              setState(() {
                _selectedBrandId = v;
              });
            },
          ),
          const SizedBox(height: 12),
          _SaveButton(
            label: 'Save Brand',
            loading: _savingBrand,
            onTap: _selectedBrandId != null ? _saveBrand : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return _SectionCard(
      title: 'Tags',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((t) {
                return Chip(
                  label: Text(t['name'] as String? ?? '',
                      style: const TextStyle(
                          color: AppColors.white, fontSize: 12)),
                  backgroundColor: AppColors.surface2,
                  side: const BorderSide(color: AppColors.border),
                  deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.grey),
                  onDeleted: () => _removeTag(t),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          if (_tags.isNotEmpty) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagCtrl,
                  style: const TextStyle(color: AppColors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add a tag',
                    hintStyle: const TextStyle(
                        color: AppColors.greyDark, fontSize: 14),
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.white, width: 1.5)),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: 10),
              _addingTag
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white))
                  : GestureDetector(
                      onTap: _addTag,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: AppColors.bg, size: 20),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttributesSection() {
    return _SectionCard(
      title: 'Attributes',
      child: Column(
        children: [
          ..._attributes.where((a) => !(a['isVariant'] as bool? ?? false)).map((a) {
            final id   = a['productAttributeId'] as String;
            final name = a['name'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Field(
                label: name,
                controller: _attrCtrls[id]!,
                hint: 'Enter $name',
              ),
            );
          }),
          _SaveButton(
            label: 'Save Attributes',
            loading: _savingAttrs,
            onTap: _saveAttrs,
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: AppShimmer(
        child: Column(
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
                color: AppColors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.greyDark, fontSize: 14),
            filled: true,
            fillColor: AppColors.bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.white, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _SaveButton({required this.label, required this.loading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(
        onPressed: (loading || onTap == null) ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.surface,
          foregroundColor: AppColors.bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.bg))
            : Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}
