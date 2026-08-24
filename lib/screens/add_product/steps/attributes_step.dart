import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../providers/add_product_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/sound_utils.dart';

class AttributesStep extends ConsumerStatefulWidget {
  const AttributesStep({super.key});

  @override
  ConsumerState<AttributesStep> createState() => _AttributesStepState();
}

class _AttributesStepState extends ConsumerState<AttributesStep> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<String>> _selected = {};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final s = ref.read(addProductPod);
    for (final raw in s.attributes) {
      final attr      = raw as Map;
      final id        = _id(attr);
      if (id.isEmpty) continue;
      final fieldType = (attr['fieldType'] as String? ?? 'TEXT').toUpperCase();
      final saved     = s.attributeValues[id] ?? '';
      if (fieldType == 'ENUMERATION') {
        _selected[id] = saved.isNotEmpty
            ? saved.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList()
            : [];
      } else {
        _controllers[id] = TextEditingController(text: saved);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  String _id(Map attr) =>
      attr['id']?.toString() ?? attr['attributeId']?.toString() ?? '';

  Future<void> _next() async {
    final values = <String, String>{};
    for (final e in _controllers.entries) {
      final v = e.value.text.trim();
      if (v.isNotEmpty) values[e.key] = v;
    }
    for (final e in _selected.entries) {
      if (e.value.isNotEmpty) values[e.key] = e.value.join(',');
    }
    SoundUtils.success();
    await ref.read(addProductPod.notifier).saveAttributesAndContinue(values);
  }

  void _openSheet(Map attr) {
    final id      = _id(attr);
    final label   = attr['name'] as String? ?? 'Select';
    final isRadio = attr['isRadio'] as bool? ?? true;
    final options = (attr['options'] as List<dynamic>?)?.cast<String>() ?? [];
    final current = List<String>.from(_selected[id] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectSheet(
        title:    label,
        options:  options,
        selected: current,
        isRadio:  isRadio,
        onDone: (vals) {
          setState(() => _selected[id] = vals);
          SoundUtils.select();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attrs = ref.watch(addProductPod).attributes;

    // Group: variant first, then non-variant non-additional, then additional
    final variantAttrs    = attrs.where((a) => (a as Map)['isVariantAttribute'] == true).toList();
    final regularAttrs    = attrs.where((a) {
      final m = a as Map;
      return m['isVariantAttribute'] != true && m['isAdditionalAttribute'] != true;
    }).toList();
    final additionalAttrs = attrs.where((a) => (a as Map)['isAdditionalAttribute'] == true).toList();

    if (attrs.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.tune_rounded,
                        color: AppColors.grey, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text('No attributes for this category',
                      style: TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('You can skip this step.',
                      style: TextStyle(color: AppColors.grey, fontSize: 13)),
                ],
              ),
            ),
          ),
          _BottomBar(onNext: _next),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Variant attributes section ─────────────────────────────
                if (variantAttrs.isNotEmpty) ...[
                  _SectionHeader(
                    title:    'SKU Variants',
                    subtitle: 'These create separate inventory entries (e.g. Size S, M, L)',
                    icon:     Icons.layers_rounded,
                    iconColor: AppColors.warning,
                  ).animate().fadeIn(),
                  ...variantAttrs.asMap().entries.map((e) => _AttrRow(
                    attr:        e.value as Map,
                    controllers: _controllers,
                    selected:    _selected,
                    onOpenSheet: () => _openSheet(e.value as Map),
                    onChanged:   () => setState(() {}),
                  ).animate(delay: Duration(milliseconds: e.key * 40)).fadeIn()),
                  Container(
                    height: 1, color: AppColors.divider,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ],

                // ── Regular attributes section ─────────────────────────────
                if (regularAttrs.isNotEmpty) ...[
                  _SectionHeader(
                    title:    'Product Details',
                    subtitle: 'Required fields are marked *',
                    icon:     Icons.info_outline_rounded,
                    iconColor: AppColors.grey,
                  ).animate().fadeIn(delay: variantAttrs.isNotEmpty ? 80.ms : 0.ms),
                  ...regularAttrs.asMap().entries.map((e) => _AttrRow(
                    attr:        e.value as Map,
                    controllers: _controllers,
                    selected:    _selected,
                    onOpenSheet: () => _openSheet(e.value as Map),
                    onChanged:   () => setState(() {}),
                  ).animate(delay: Duration(milliseconds: e.key * 40 + (variantAttrs.isNotEmpty ? 60 : 0))).fadeIn()),
                ],

                // ── Additional attributes section ──────────────────────────
                if (additionalAttrs.isNotEmpty) ...[
                  if (regularAttrs.isNotEmpty || variantAttrs.isNotEmpty)
                    Container(height: 1, color: AppColors.divider,
                        margin: const EdgeInsets.symmetric(vertical: 4)),
                  _SectionHeader(
                    title:    'Additional Details',
                    subtitle: 'Filling these gives better visibility',
                    icon:     Icons.lightbulb_outline_rounded,
                    iconColor: AppColors.warning,
                    isTip: true,
                  ),
                  ...additionalAttrs.asMap().entries.map((e) => _AttrRow(
                    attr:        e.value as Map,
                    controllers: _controllers,
                    selected:    _selected,
                    onOpenSheet: () => _openSheet(e.value as Map),
                    onChanged:   () => setState(() {}),
                  )),
                ],
              ],
            ),
          ),
        ),
        _BottomBar(onNext: _next),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String   title;
  final String   subtitle;
  final IconData icon;
  final Color    iconColor;
  final bool     isTip;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.isTip = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      color: AppColors.surface2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.grey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single attribute row ──────────────────────────────────────────────────────

class _AttrRow extends StatelessWidget {
  final Map                                attr;
  final Map<String, TextEditingController> controllers;
  final Map<String, List<String>>          selected;
  final VoidCallback                       onOpenSheet;
  final VoidCallback                       onChanged;

  const _AttrRow({
    required this.attr,
    required this.controllers,
    required this.selected,
    required this.onOpenSheet,
    required this.onChanged,
  });

  String get _id =>
      attr['id']?.toString() ?? attr['attributeId']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final name            = attr['name'] as String? ?? 'Attribute';
    final isRequired      = attr['isRequired'] as bool? ?? false;
    final isVariantAttr   = attr['isVariantAttribute'] as bool? ?? false;
    final isImageAttr     = attr['isImageAttribute'] as bool? ?? false;
    final fieldType       = (attr['fieldType'] as String? ?? 'TEXT').toUpperCase();
    final isEnum          = fieldType == 'ENUMERATION';
    final vals            = selected[_id] ?? [];
    final ctrl            = controllers[_id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Label + badges ─────────────────────────────────────────
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: name,
                        style: const TextStyle(
                            color: AppColors.grey, fontSize: 13),
                        children: [
                          if (isRequired)
                            const TextSpan(
                              text: ' *',
                              style: TextStyle(color: AppColors.error),
                            ),
                        ],
                      ),
                    ),
                    if (isVariantAttr || isImageAttr) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4, runSpacing: 3,
                        children: [
                          if (isVariantAttr)
                            _Badge(label: 'VARIANTS', color: AppColors.warning),
                          if (isImageAttr)
                            _Badge(label: 'IMAGES', color: AppColors.info),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ── Input ──────────────────────────────────────────────────
              Expanded(
                child: isEnum
                    ? _SelectButton(
                        selected:       vals,
                        onTap:          onOpenSheet,
                        isVariantAttr:  isVariantAttr,
                      )
                    : _InlineTextField(
                        controller: ctrl ?? TextEditingController(),
                        isNumber:   fieldType == 'NUMBER',
                        onChanged:  onChanged,
                      ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: AppColors.divider,
            margin: const EdgeInsets.symmetric(horizontal: 16)),
      ],
    );
  }
}

// ── Small badge chip ──────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:       color,
          fontSize:    9,
          fontWeight:  FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Inline text field ─────────────────────────────────────────────────────────

class _InlineTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool                  isNumber;
  final VoidCallback          onChanged;

  const _InlineTextField({
    required this.controller,
    required this.isNumber,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged:    (_) => onChanged(),
      style: const TextStyle(color: AppColors.white, fontSize: 14),
      cursorColor: AppColors.white,
      decoration: InputDecoration(
        hintText:  'Enter value',
        hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
        filled:    true,
        fillColor: AppColors.surface,
        isDense:   true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.white, width: 1.5)),
      ),
    );
  }
}

// ── Select button ─────────────────────────────────────────────────────────────

class _SelectButton extends StatelessWidget {
  final List<String> selected;
  final VoidCallback onTap;
  final bool         isVariantAttr;

  const _SelectButton({
    required this.selected,
    required this.onTap,
    this.isVariantAttr = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = selected.isNotEmpty;
    final borderColor = hasValue
        ? (isVariantAttr ? AppColors.warning.withOpacity(0.5) : Colors.white38)
        : AppColors.border;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: hasValue
                  ? Wrap(
                      spacing: 4, runSpacing: 4,
                      children: selected.map((v) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isVariantAttr
                              ? AppColors.warning.withOpacity(0.12)
                              : AppColors.surface2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isVariantAttr
                                ? AppColors.warning.withOpacity(0.3)
                                : AppColors.border,
                          ),
                        ),
                        child: Text(v,
                          style: TextStyle(
                            color: isVariantAttr ? AppColors.warning : AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                    )
                  : Text(
                      'Select',
                      style: const TextStyle(
                          color: AppColors.greyDark,
                          fontSize: 14),
                    ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Searchable select bottom sheet ────────────────────────────────────────────

class _SelectSheet extends StatefulWidget {
  final String       title;
  final List<String> options;
  final List<String> selected;
  final bool         isRadio;
  final void Function(List<String>) onDone;

  const _SelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.isRadio,
    required this.onDone,
  });

  @override
  State<_SelectSheet> createState() => _SelectSheetState();
}

class _SelectSheetState extends State<_SelectSheet> {
  late List<String> _current;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _current = List.from(widget.selected);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(String val) {
    setState(() {
      if (widget.isRadio) {
        _current = [val];
        widget.onDone(_current);
      } else {
        if (_current.contains(val)) {
          _current.remove(val);
        } else {
          _current.add(val);
        }
      }
    });
    SoundUtils.select();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((o) => o.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize:     0.4,
      maxChildSize:     0.9,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      style: const TextStyle(
                          color:      AppColors.white,
                          fontSize:   13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8),
                    ),
                  ),
                  if (!widget.isRadio)
                    Text(
                      '${_current.length} selected',
                      style: const TextStyle(color: AppColors.grey, fontSize: 12),
                    ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.grey, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextFormField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                cursorColor: AppColors.white,
                decoration: InputDecoration(
                  hintText:  'Search ${widget.title}',
                  hintStyle: const TextStyle(
                      color: AppColors.greyDark, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.grey, size: 18),
                  filled:    true,
                  fillColor: AppColors.surface2,
                  isDense:   true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.white, width: 1.5)),
                ),
              ),
            ),
            Container(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    Container(height: 1, color: AppColors.divider),
                itemBuilder: (_, i) {
                  final opt        = filtered[i];
                  final isSelected = _current.contains(opt);
                  return GestureDetector(
                    onTap: () => _toggle(opt),
                    child: Container(
                      color: isSelected
                          ? AppColors.white.withOpacity(0.06)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              shape: widget.isRadio
                                  ? BoxShape.circle
                                  : BoxShape.rectangle,
                              borderRadius: widget.isRadio
                                  ? null
                                  : BorderRadius.circular(5),
                              color: isSelected
                                  ? AppColors.white
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.greyDark,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded,
                                    size: 13, color: AppColors.bg)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(opt,
                                style: TextStyle(
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.grey,
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (!widget.isRadio)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: AppButton(
                  label: _current.isEmpty
                      ? 'Done'
                      : 'Done  (${_current.length} selected)',
                  onTap: () => widget.onDone(_current),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends ConsumerWidget {
  final VoidCallback onNext;
  const _BottomBar({required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state  = ref.watch(addProductPod);
    final saving = state.isCreating;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: AppButton(
        isLoading: saving,
        label: state.isEditMode ? 'Update' : 'Continue',
        onTap: onNext,
        icon:  state.isEditMode ? Icons.check_rounded : Icons.arrow_forward_rounded,
      ),
    );
  }
}
