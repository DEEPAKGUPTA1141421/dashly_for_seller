import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../providers/add_product_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/sound_utils.dart';

// ── Data model for one SKU combination ───────────────────────────────────────

class _ComboItem {
  final Map<String, String> combination;
  final String label;
  final String autoSku;
  final TextEditingController priceCtrl;
  final TextEditingController mrpCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController skuCtrl;
  bool isExpanded;

  _ComboItem({
    required this.combination,
    required this.label,
    required this.autoSku,
    required this.priceCtrl,
    required this.mrpCtrl,
    required this.stockCtrl,
    required this.skuCtrl,
    this.isExpanded = false,
  });

  void dispose() {
    priceCtrl.dispose();
    mrpCtrl.dispose();
    stockCtrl.dispose();
    skuCtrl.dispose();
  }

  bool get isComplete =>
      priceCtrl.text.isNotEmpty && stockCtrl.text.isNotEmpty;

  Map<String, dynamic> toVariant() => {
    'combination': combination,
    'label':       label,
    'price':       double.tryParse(priceCtrl.text.trim()) ?? 0,
    'mrp':         double.tryParse(mrpCtrl.text.trim()) ?? 0,
    'stock':       int.tryParse(stockCtrl.text.trim()) ?? 0,
    'sku':         skuCtrl.text.trim().isEmpty ? autoSku : skuCtrl.text.trim(),
  };
}

// ── Step widget ───────────────────────────────────────────────────────────────

class VariantsStep extends ConsumerStatefulWidget {
  const VariantsStep({super.key});

  @override
  ConsumerState<VariantsStep> createState() => _VariantsStepState();
}

class _VariantsStepState extends ConsumerState<VariantsStep> {
  final List<_ComboItem> _items = [];

  @override
  void initState() {
    super.initState();
    _buildItems();
  }

  @override
  void dispose() {
    for (final item in _items) { item.dispose(); }
    super.dispose();
  }

  // ── Build combo items from variant attributes ─────────────────────────────

  void _buildItems() {
    final s       = ref.read(addProductPod);
    final combos  = _generateCombinations(s.attributes, s.attributeValues);

    final savedMap = <String, Map<String, dynamic>>{};
    for (final v in s.variants) {
      final label = v['label']?.toString() ?? '';
      if (label.isNotEmpty) savedMap[label] = Map<String, dynamic>.from(v);
    }

    for (var i = 0; i < combos.length; i++) {
      final combo   = combos[i];
      final label   = _comboLabel(combo);
      final saved   = savedMap[label];
      final autoSku = _makeAutoSku(s.productName, combo, i);

      _items.add(_ComboItem(
        combination: combo,
        label:       label,
        autoSku:     autoSku,
        priceCtrl:   TextEditingController(
            text: saved?['price'] != null && saved!['price'] != 0
                ? saved['price'].toString() : ''),
        mrpCtrl:     TextEditingController(
            text: saved?['mrp'] != null && saved!['mrp'] != 0
                ? saved['mrp'].toString() : ''),
        stockCtrl:   TextEditingController(
            text: saved?['stock'] != null && saved!['stock'] != 0
                ? saved['stock'].toString() : ''),
        skuCtrl:     TextEditingController(
            text: saved != null && (saved['sku']?.toString() ?? '').isNotEmpty
                ? saved['sku'].toString() : autoSku),
        isExpanded:  i == 0,
      ));
    }
  }

  // Cartesian product of selected values across variant attributes
  List<Map<String, String>> _generateCombinations(
      List<dynamic> attrs, Map<String, String> attrValues) {
    final variantAttrs = attrs
        .where((a) => (a as Map)['isVariantAttribute'] == true)
        .cast<Map>()
        .toList();

    if (variantAttrs.isEmpty) return [];

    final axisList = <List<Map<String, String>>>[];
    for (final attr in variantAttrs) {
      final id       = attr['id']?.toString() ?? '';
      final name     = attr['name']?.toString() ?? 'Variant';
      final selected = (attrValues[id] ?? '')
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
      if (selected.isEmpty) continue;
      axisList.add(selected.map((v) => {name: v}).toList());
    }

    if (axisList.isEmpty) return [];

    var result = [<String, String>{}];
    for (final axis in axisList) {
      final next = <Map<String, String>>[];
      for (final existing in result) {
        for (final item in axis) {
          next.add({...existing, ...item});
        }
      }
      result = next;
    }
    return result;
  }

  String _comboLabel(Map<String, String> combo) => combo.values.join(' / ');

  String _makeAutoSku(String productName, Map<String, String> combo, int idx) {
    final clean  = productName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final prefix = clean.isEmpty
        ? 'SKU'
        : clean.toUpperCase().substring(0, min(4, clean.length));
    final attrs  = combo.values.map((v) {
      final c = v.replaceAll(' ', '').toUpperCase();
      return c.substring(0, min(3, c.length));
    }).join('-');
    final num = (idx + 1).toString().padLeft(3, '0');
    return attrs.isEmpty ? '$prefix-$num' : '$prefix-$attrs-$num';
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _next() async {
    SoundUtils.success();
    await ref.read(addProductPod.notifier).saveVariantsAndContinue(
      _items.map((item) => item.toVariant()).toList(),
    );
  }

  Future<void> _showApplyAll() async {
    final priceCtrl = TextEditingController();
    final mrpCtrl   = TextEditingController();
    final stockCtrl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplyAllSheet(
        priceCtrl: priceCtrl,
        mrpCtrl:   mrpCtrl,
        stockCtrl: stockCtrl,
      ),
    );

    if (confirmed == true) {
      setState(() {
        for (final item in _items) {
          if (priceCtrl.text.isNotEmpty) item.priceCtrl.text = priceCtrl.text;
          if (mrpCtrl.text.isNotEmpty)   item.mrpCtrl.text   = mrpCtrl.text;
          if (stockCtrl.text.isNotEmpty) item.stockCtrl.text = stockCtrl.text;
        }
      });
      SoundUtils.success();
    }
    priceCtrl.dispose();
    mrpCtrl.dispose();
    stockCtrl.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return _EmptyView(onContinue: _next);
    }

    final doneCount = _items.where((i) => i.isComplete).length;

    return Column(
      children: [
        // ── Status banner ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surface2,
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.warning, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_items.length} SKU${_items.length > 1 ? 's' : ''} generated  •  $doneCount / ${_items.length} filled',
                  style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
              GestureDetector(
                onTap: _showApplyAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_all_rounded, color: AppColors.info, size: 12),
                      SizedBox(width: 4),
                      Text('Apply all',
                          style: TextStyle(
                              color: AppColors.info,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(),

        // ── Combo list ─────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              return _ComboCard(
                item:     _items[i],
                onToggle: () {
                  SoundUtils.tap();
                  setState(() => _items[i].isExpanded = !_items[i].isExpanded);
                },
                onChanged: () => setState(() {}),
              ).animate(
                delay: Duration(milliseconds: i * 50),
              ).fadeIn().slideX(begin: 0.04, end: 0);
            },
          ),
        ),

        // ── Continue button ────────────────────────────────────────────────
        Consumer(
          builder: (_, ref, __) {
            final saving = ref.watch(addProductPod).isCreating;
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: AppButton(
                isLoading: saving,
                label: doneCount == 0
                    ? 'Skip Variants'
                    : 'Continue  ($doneCount SKU${doneCount > 1 ? 's' : ''} ready)',
                onTap: _next,
                icon:  Icons.arrow_forward_rounded,
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Combo expandable card ─────────────────────────────────────────────────────

class _ComboCard extends StatelessWidget {
  final _ComboItem   item;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  const _ComboCard({
    required this.item,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isComplete
              ? AppColors.success.withOpacity(0.4)
              : item.isExpanded
                  ? AppColors.white.withOpacity(0.2)
                  : AppColors.border,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header row
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Status dot
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.isComplete
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Label
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            color:      AppColors.white,
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Done badge
                      if (item.isComplete)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Done',
                              style: TextStyle(
                                  color:      AppColors.success,
                                  fontSize:   10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(width: 8),
                      // Chevron
                      AnimatedRotation(
                        turns:    item.isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.grey, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Expanded body
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: item.isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild:  _ExpandedBody(item: item, onChanged: onChanged),
              secondChild: const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expanded inventory form ───────────────────────────────────────────────────

class _ExpandedBody extends StatelessWidget {
  final _ComboItem   item;
  final VoidCallback onChanged;

  const _ExpandedBody({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              height: 1, color: AppColors.divider,
              margin: const EdgeInsets.only(bottom: 14)),
          Row(
            children: [
              Expanded(
                child: _Field(
                  ctrl:      item.priceCtrl,
                  label:     'Sell Price',
                  hint:      '999',
                  prefix:    '₹',
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  ctrl:      item.mrpCtrl,
                  label:     'MRP',
                  hint:      '1299',
                  prefix:    '₹',
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Field(
                  ctrl:      item.stockCtrl,
                  label:     'Stock',
                  hint:      '50',
                  isNumber:  true,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  ctrl:      item.skuCtrl,
                  label:     'SKU Code',
                  hint:      item.autoSku,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Inventory text field ──────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String    label;
  final String    hint;
  final String?   prefix;
  final bool      isNumber;
  final VoidCallback onChanged;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.prefix,
    this.isNumber = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color:       AppColors.grey,
                fontSize:    10,
                fontWeight:  FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(
          controller:   ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          onChanged:    (_) => onChanged(),
          style: const TextStyle(color: AppColors.white, fontSize: 13),
          cursorColor: AppColors.white,
          decoration: InputDecoration(
            hintText:      hint,
            hintStyle:     const TextStyle(
                color: AppColors.greyDark, fontSize: 13),
            prefixText:    prefix,
            prefixStyle:   const TextStyle(
                color: AppColors.grey, fontSize: 13),
            filled:        true,
            fillColor:     AppColors.surface2,
            isDense:       true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
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
      ],
    );
  }
}

// ── Apply-to-all bottom sheet ─────────────────────────────────────────────────

class _ApplyAllSheet extends StatelessWidget {
  final TextEditingController priceCtrl;
  final TextEditingController mrpCtrl;
  final TextEditingController stockCtrl;

  const _ApplyAllSheet({
    required this.priceCtrl,
    required this.mrpCtrl,
    required this.stockCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Apply to all SKUs',
                    style: TextStyle(
                        color:      AppColors.white,
                        fontSize:   16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Leave blank to keep individual values',
                    style: TextStyle(color: AppColors.grey, fontSize: 12)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _Field(ctrl: priceCtrl, label: 'Sell Price',
                          hint: '999', prefix: '₹', onChanged: () {}),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(ctrl: mrpCtrl, label: 'MRP',
                          hint: '1299', prefix: '₹', onChanged: () {}),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 160,
                  child: _Field(ctrl: stockCtrl, label: 'Stock',
                      hint: '50', isNumber: true, onChanged: () {}),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Apply',
                            style: TextStyle(
                                color:      AppColors.bg,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state (no variant attributes selected) ──────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onContinue;
  const _EmptyView({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.layers_outlined,
                        color: AppColors.grey, size: 32),
                  ),
                  const SizedBox(height: 20),
                  const Text('No variant attributes selected',
                      style: TextStyle(
                          color:      AppColors.white,
                          fontSize:   16,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'Go back and select values for attributes\nmarked VARIANTS (e.g. Size → S, M, L).',
                    style: TextStyle(
                        color:  AppColors.grey,
                        fontSize: 13,
                        height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: AppButton(
            label: 'Skip Variants',
            onTap: onContinue,
            icon:  Icons.arrow_forward_rounded,
          ),
        ),
      ],
    );
  }
}
