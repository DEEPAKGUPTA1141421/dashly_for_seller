import 'package:flutter/material.dart';
import '../../models/discount_config.dart';
import '../../core/widgets/app_button.dart';
import '../../utils/app_colors.dart';

/// Result of [showDiscountEditorSheet] — distinguishes "saved a config" from
/// "explicitly removed the discount" (both are meaningfully different from
/// the sheet simply being dismissed, which resolves the future to `null`).
class DiscountEditorResult {
  final DiscountConfig? config; // null when [removed] is true
  final bool removed;

  const DiscountEditorResult.saved(DiscountConfig this.config) : removed = false;
  const DiscountEditorResult.removed() : config = null, removed = true;
}

/// Opens the shared discount configuration UI as a bottom sheet. Used by both
/// the add-product creation flow (per-SKU discount during variant setup) and
/// the edit-flow "Manage discount" action on a live variant.
///
/// Pass [initial] to pre-fill an existing discount. [showRemove] shows a
/// "Remove discount" action (only meaningful when editing an existing one).
Future<DiscountEditorResult?> showDiscountEditorSheet(
  BuildContext context, {
  required String title,
  DiscountConfig? initial,
  double? mrp,
  bool showRemove = false,
}) {
  return showModalBottomSheet<DiscountEditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DiscountEditorSheet(title: title, initial: initial, mrp: mrp, showRemove: showRemove),
  );
}

class _DiscountEditorSheet extends StatefulWidget {
  final String title;
  final DiscountConfig? initial;
  final double? mrp;
  final bool showRemove;

  const _DiscountEditorSheet({
    required this.title,
    this.initial,
    this.mrp,
    this.showRemove = false,
  });

  @override
  State<_DiscountEditorSheet> createState() => _DiscountEditorSheetState();
}

class _DiscountEditorSheetState extends State<_DiscountEditorSheet> {
  late bool _enabled = widget.initial != null;
  late DiscountType _type = widget.initial?.type ?? DiscountType.percentage;
  late final TextEditingController _valueCtrl =
      TextEditingController(text: widget.initial != null ? _fmt(widget.initial!.value) : '');
  late bool _active = widget.initial?.active ?? true;
  DateTime? _startsAt;
  DateTime? _endsAt;
  late bool _scheduled = widget.initial?.startsAt != null || widget.initial?.endsAt != null;

  @override
  void initState() {
    super.initState();
    _startsAt = widget.initial?.startsAt;
    _endsAt   = widget.initial?.endsAt;
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  static String _fmt(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  String? get _error {
    if (!_enabled) return null;
    final v = double.tryParse(_valueCtrl.text.trim());
    if (v == null || v <= 0) return 'Enter a valid discount value';
    if (_type == DiscountType.percentage && v > 90) return 'Percentage discount must be 90 or less';
    if (_type == DiscountType.flat && widget.mrp != null && v >= widget.mrp!) {
      return 'Flat discount must be less than MRP';
    }
    return null;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _startsAt : _endsAt) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) && !isStart ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.white,
            onPrimary: AppColors.bg,
            surface: AppColors.surface2,
            onSurface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (d == null) return;
    setState(() {
      if (isStart) {
        _startsAt = d;
      } else {
        _endsAt = DateTime(d.year, d.month, d.day, 23, 59, 59);
      }
    });
  }

  void _save() {
    if (!_enabled) {
      Navigator.pop(context, const DiscountEditorResult.removed());
      return;
    }
    if (_error != null) {
      setState(() {}); // surface the error text below the field
      return;
    }
    final config = DiscountConfig(
      type:   _type,
      value:  double.parse(_valueCtrl.text.trim()),
      active: _active,
      startsAt: _scheduled ? _startsAt : null,
      endsAt:   _scheduled ? _endsAt   : null,
    );
    Navigator.pop(context, DiscountEditorResult.saved(config));
  }

  @override
  Widget build(BuildContext context) {
    final err = _error;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                  ],
                ),
                const Text(
                  'Add a discount',
                  style: TextStyle(color: AppColors.grey, fontSize: 12),
                ),

                if (_enabled) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeChip(
                          label: 'Percentage off',
                          selected: _type == DiscountType.percentage,
                          onTap: () => setState(() => _type = DiscountType.percentage),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TypeChip(
                          label: 'Flat amount off',
                          selected: _type == DiscountType.flat,
                          onTap: () => setState(() => _type = DiscountType.flat),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _type == DiscountType.percentage ? 'DISCOUNT %' : 'DISCOUNT AMOUNT (₹)',
                    style: const TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: AppColors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _type == DiscountType.percentage ? 'e.g. 20' : 'e.g. 100',
                      hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
                      suffixText: _type == DiscountType.percentage ? '%' : null,
                      prefixText: _type == DiscountType.flat ? '₹ ' : null,
                      filled: true,
                      fillColor: AppColors.surface2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.white, width: 1.5),
                      ),
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 6),
                    Text(err, style: const TextStyle(color: AppColors.error, fontSize: 11.5)),
                  ],

                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Schedule for later',
                          style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch(
                        value: _scheduled,
                        onChanged: (v) => setState(() => _scheduled = v),
                        activeColor: AppColors.info,
                      ),
                    ],
                  ),
                  if (_scheduled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(label: 'Starts', date: _startsAt, onTap: () => _pickDate(isStart: true)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(label: 'Ends', date: _endsAt, onTap: () => _pickDate(isStart: false)),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Active',
                          style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch(
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 22),
                Row(
                  children: [
                    if (widget.showRemove && widget.initial != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, const DiscountEditorResult.removed()),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Remove', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: AppButton(label: 'Save', onTap: _save),
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

/// A tappable summary row showing the current discount (or a prompt to add
/// one) that opens [showDiscountEditorSheet] on tap and reports the result
/// back via [onChanged]. Shared by the add-product Pricing/Variants steps
/// and the live-product "Manage discount" action.
class DiscountSummaryTile extends StatelessWidget {
  final String title;
  final DiscountConfig? discount;
  final double? mrp;
  final ValueChanged<DiscountConfig?> onChanged;

  const DiscountSummaryTile({
    super.key,
    required this.title,
    required this.discount,
    required this.onChanged,
    this.mrp,
  });

  Future<void> _open(BuildContext context) async {
    final result = await showDiscountEditorSheet(
      context,
      title: title,
      initial: discount,
      mrp: mrp,
      showRemove: discount != null,
    );
    if (result == null) return;
    onChanged(result.removed ? null : result.config);
  }

  static String _fmt(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final d = discount;
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: d != null ? AppColors.success.withOpacity(0.08) : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: d != null ? AppColors.success.withOpacity(0.35) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_offer_rounded,
              size: 15,
              color: d != null ? AppColors.success : AppColors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                d == null
                    ? 'Add a discount'
                    : d.type == DiscountType.percentage
                        ? '${_fmt(d.value)}% off${d.active ? '' : ' (inactive)'}'
                        : '₹${_fmt(d.value)} off${d.active ? '' : ' (inactive)'}',
                style: TextStyle(
                  color: d != null ? AppColors.success : AppColors.grey,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.white : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.white : AppColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.bg : AppColors.grey,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({required this.label, this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(
                    date != null
                        ? '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}'
                        : 'Select',
                    style: TextStyle(
                      color: date != null ? AppColors.white : AppColors.greyDark,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today_rounded, color: AppColors.grey, size: 13),
          ],
        ),
      ),
    );
  }
}
