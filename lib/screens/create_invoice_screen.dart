import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_toast.dart';
import '../models/invoice_draft.dart';
import '../providers/create_invoice_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/invoice/custom_item_sheet.dart';
import '../widgets/invoice/customer_form_sheet.dart';
import '../widgets/invoice/price_warning_dialog.dart';
import '../widgets/invoice/product_search_sheet.dart';
import 'barcode_scanner_screen.dart';
import 'invoice_result_screen.dart';

/// Path A (existing product) and Path B (custom item) both funnel into the
/// same local draft (createInvoicePod) — the seller builds the invoice
/// entirely client-side, then a single "Generate Invoice" call creates +
/// finalizes it on the backend. See CreateInvoiceNotifier for that flow.
class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(createInvoicePod.notifier).reset());
  }

  Future<void> _pickCustomer() async {
    final current = ref.read(createInvoicePod).customer;
    final result = await CustomerFormSheet.show(context, initial: current);
    if (result != null) ref.read(createInvoicePod.notifier).setCustomer(result);
  }

  Future<void> _searchProduct() async {
    HapticUtils.light();
    final picked = await ProductSearchSheet.show(context);
    if (picked != null) _addCatalogPick(picked);
  }

  void _addCatalogPick(Map<String, dynamic> picked) {
    ref.read(createInvoicePod.notifier).addOrMergeCatalogItem(
      productId: picked['id'].toString(),
      variantId: null, // resolved server-side from catalogPriceHint when absent
      name: picked['name'] as String? ?? 'Product',
      catalogPrice: _numOf(picked['price']).toDouble(),
    );
  }

  Future<void> _addCustomItem({String? prefillBarcode}) async {
    final item = await CustomItemSheet.show(context, prefillBarcode: prefillBarcode);
    if (item != null) ref.read(createInvoicePod.notifier).addItem(item);
  }

  Future<void> _scanBarcode() async {
    HapticUtils.light();
    final codes = await BarcodeScannerScreen.show(context);
    if (codes == null || codes.isEmpty || !mounted) return;

    for (final code in codes) {
      final match = await ProductSearchSheet.show(context, initialQuery: code);
      if (!mounted) return;
      if (match != null) {
        _addCatalogPick(match);
      } else {
        // Seller dismissed without a pick — offer the custom-item fallback per code.
        await _addCustomItem(prefillBarcode: code);
        if (!mounted) return;
      }
    }
  }

  Future<void> _editPrice(int index, InvoiceDraftItem item) async {
    final ctrl = TextEditingController(text: item.unitPrice.toStringAsFixed(2));
    final newPrice = await showDialog<double>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Price — ${item.name}', style: const TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.white, fontSize: 16),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: AppColors.surface2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(double.tryParse(ctrl.text.trim())),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (newPrice == null || newPrice <= 0 || !mounted) return;

    bool overrideConfirmed = false;
    if (item.catalogPrice != null && item.catalogPrice! > 0) {
      final absDiff = (newPrice - item.catalogPrice!).abs();
      final pctDiff = (absDiff / item.catalogPrice!) * 100.0;
      if (pctDiff >= 50.0 && absDiff >= 100.0) {
        final proceed = await showPriceWarningDialog(context, catalogPrice: item.catalogPrice!, enteredPrice: newPrice);
        if (!proceed) return;
        overrideConfirmed = true;
      }
    }
    ref.read(createInvoicePod.notifier).updateItem(index, unitPrice: newPrice, priceOverrideConfirmed: overrideConfirmed);
  }

  Future<void> _generate() async {
    final notifier = ref.read(createInvoicePod.notifier);
    HapticUtils.medium();
    final ok = await notifier.generate();
    if (!mounted) return;

    final pending = ref.read(createInvoicePod).pendingOverride;
    if (pending != null) {
      final proceed = await showPriceWarningDialog(
        context, catalogPrice: pending.catalogPrice, enteredPrice: pending.enteredPrice,
      );
      if (!mounted) return;
      if (proceed) {
        final retried = await notifier.confirmOverrideAndRetry();
        if (!mounted) return;
        if (retried) _goToResult();
      } else {
        notifier.clearPendingOverride();
      }
      return;
    }

    if (ok) {
      _goToResult();
    } else {
      final err = ref.read(createInvoicePod).error;
      if (err != null) AppToast.show(context, message: err, type: ToastType.error);
    }
  }

  void _goToResult() {
    final invoice = ref.read(createInvoicePod).generatedInvoice;
    if (invoice == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => InvoiceResultScreen(invoice: invoice)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createInvoicePod);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Create Invoice', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Row(children: [
                    _SectionHeader('Customer'),
                    SizedBox(width: 4),
                    Text('*', style: TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickCustomer,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: state.customer == null ? AppColors.warning : AppColors.border),
                      ),
                      child: state.customer == null
                          ? const Row(children: [
                              Icon(Icons.person_add_alt_rounded, color: AppColors.grey, size: 20),
                              SizedBox(width: 10),
                              Text('Add customer details (required)', style: TextStyle(color: AppColors.grey, fontSize: 13.5)),
                            ])
                          : Row(children: [
                              const Icon(Icons.person_rounded, color: AppColors.white, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(state.customer!.name, style: const TextStyle(color: AppColors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                                    if (state.customer!.phone != null)
                                      Text(state.customer!.phone!, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.greyDark, size: 18),
                            ]),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader('Items'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _ActionChip(icon: Icons.qr_code_scanner_rounded, label: 'Scan Barcode', onTap: _scanBarcode)),
                      const SizedBox(width: 8),
                      Expanded(child: _ActionChip(icon: Icons.search_rounded, label: 'Search Product', onTap: _searchProduct)),
                      const SizedBox(width: 8),
                      Expanded(child: _ActionChip(icon: Icons.edit_note_rounded, label: 'Custom Item', onTap: () => _addCustomItem())),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (state.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No items yet', style: TextStyle(color: AppColors.greyDark, fontSize: 13)),
                      ),
                    )
                  else
                    ...state.items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return _ItemCard(
                        item: item,
                        onEditPrice: () => _editPrice(i, item),
                        onQtyChanged: (v) => ref.read(createInvoicePod.notifier).updateItem(i, quantity: v),
                        onRemove: () => ref.read(createInvoicePod.notifier).removeItem(item.id),
                      );
                    }),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _totalsRow('Subtotal', state.subtotal),
                  if (state.totalDiscount > 0) _totalsRow('Discount', -state.totalDiscount),
                  if (state.tax > 0) _totalsRow('Tax', state.tax),
                  const Divider(color: AppColors.border, height: 16),
                  Row(
                    children: [
                      const Text('Total', style: TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text('₹${state.total.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.generating || state.items.isEmpty || state.customer == null ? null : _generate,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: state.generating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Generate Invoice', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalsRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
          const Spacer(),
          Text('${value < 0 ? '-' : ''}₹${value.abs().toStringAsFixed(2)}', style: const TextStyle(color: AppColors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

num _numOf(dynamic v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? 0;
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title.toUpperCase(), style: const TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2));
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.white, size: 20),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey, fontSize: 10.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final InvoiceDraftItem item;
  final VoidCallback onEditPrice;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;

  const _ItemCard({required this.item, required this.onEditPrice, required this.onQtyChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.hasPriceDeviation ? AppColors.warning : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(children: [
                  if (item.type == 'CUSTOM')
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.info.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                      child: const Text('CUSTOM', style: TextStyle(color: AppColors.info, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  Expanded(
                    child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              GestureDetector(onTap: onRemove, child: const Icon(Icons.close_rounded, color: AppColors.greyDark, size: 18)),
            ],
          ),
          if (item.sku != null && item.sku!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('SKU: ${item.sku}', style: const TextStyle(color: AppColors.greyDark, fontSize: 11)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QtyStepperSmall(qty: item.quantity, onChanged: onQtyChanged),
              const Spacer(),
              GestureDetector(
                onTap: onEditPrice,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.hasPriceDeviation) const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 14),
                    if (item.hasPriceDeviation) const SizedBox(width: 4),
                    Text('₹${item.unitPrice.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_rounded, color: AppColors.greyDark, size: 14),
                  ],
                ),
              ),
            ],
          ),
          if (item.catalogPrice != null && item.catalogPrice != item.unitPrice)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Catalog price: ₹${item.catalogPrice!.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.greyDark, fontSize: 11)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Text('₹${item.unitPrice.toStringAsFixed(2)} × ${item.quantity}',
                    style: const TextStyle(color: AppColors.greyDark, fontSize: 11.5)),
                const Spacer(),
                Text('Total ₹${item.lineTotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyStepperSmall extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  const _QtyStepperSmall({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove_rounded, () => onChanged((qty - 1).clamp(1, 9999))),
        SizedBox(width: 30, child: Center(child: Text('$qty', style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)))),
        _btn(Icons.add_rounded, () => onChanged((qty + 1).clamp(1, 9999))),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 14, color: AppColors.white),
      ),
    );
  }
}
