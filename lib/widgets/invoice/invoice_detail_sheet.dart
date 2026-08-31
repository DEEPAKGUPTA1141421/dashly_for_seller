import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/confirm_modal.dart';
import '../../providers/invoices_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';
import 'send_invoice_sheet.dart';

class InvoiceDetailSheet extends ConsumerStatefulWidget {
  final String invoiceId;
  const InvoiceDetailSheet({super.key, required this.invoiceId});

  static Future<void> show(BuildContext context, String invoiceId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvoiceDetailSheet(invoiceId: invoiceId),
    );
  }

  @override
  ConsumerState<InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends ConsumerState<InvoiceDetailSheet> {
  bool _loading = true;
  bool _downloading = false;
  bool _cancelling = false;
  bool _finalizing = false;
  Map<String, dynamic> _invoice = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final detail = await ref.read(invoicesPod.notifier).fetchDetail(widget.invoiceId);
    if (mounted) setState(() { _invoice = detail; _loading = false; });
  }

  String get _status => (_invoice['status'] as String? ?? 'DRAFT').toUpperCase();

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final invoiceNumber = _invoice['invoiceNumber'] as String?;
      final invoice = await ref.read(invoicesPod.notifier).downloadPdf(widget.invoiceId, invoiceNumber: invoiceNumber);
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/${invoice.filename}');
      await file.writeAsBytes(invoice.bytes, flush: true);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], subject: invoice.filename);
    } on AppException catch (e) {
      if (mounted) AppToast.show(context, message: e.message, type: ToastType.error);
    } catch (_) {
      if (mounted) AppToast.show(context, message: 'Could not download invoice', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showConfirmModal(
      context,
      title: 'Cancel Invoice',
      message: 'This invoice will be marked cancelled and can no longer be sent.',
      confirmLabel: 'Yes, Cancel',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    HapticUtils.medium();
    setState(() => _cancelling = true);
    final ok = await ref.read(invoicesPod.notifier).cancelInvoice(widget.invoiceId);
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      AppToast.show(context, message: 'Could not cancel invoice', type: ToastType.error);
    }
  }

  Future<void> _finalize() async {
    HapticUtils.medium();
    setState(() => _finalizing = true);
    final ok = await ref.read(invoicesPod.notifier).finalizeInvoice(widget.invoiceId);
    if (!mounted) return;
    setState(() => _finalizing = false);
    if (ok) {
      await _load();
      if (mounted) ref.read(invoicesPod.notifier).fetchInvoices(status: ref.read(invoicesPod).filterStatus);
    } else {
      final err = ref.read(invoicesPod).error;
      AppToast.show(context, message: err ?? 'Could not generate invoice', type: ToastType.error);
    }
  }

  Future<void> _send() async {
    HapticUtils.light();
    final sent = await SendInvoiceSheet.show(context, widget.invoiceId, _invoice);
    if (sent == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _loading
            ? const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey),
              ))
            : Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 4, decoration: BoxDecoration(
                      color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _invoice['invoiceNumber'] as String? ?? 'Draft Invoice',
                                  style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                              ),
                              _StatusPill(status: _status),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_invoice['customer'] != null) _Section(title: 'Customer', children: [
                            _Row('Name', (_invoice['customer'] as Map)['name']?.toString() ?? '-'),
                            if (((_invoice['customer'] as Map)['phone'] ?? '').toString().isNotEmpty)
                              _Row('Phone', (_invoice['customer'] as Map)['phone'].toString()),
                            if (((_invoice['customer'] as Map)['email'] ?? '').toString().isNotEmpty)
                              _Row('Email', (_invoice['customer'] as Map)['email'].toString()),
                          ]),
                          const SizedBox(height: 16),

                          _Section(
                            title: 'Items',
                            children: ((_invoice['items'] as List?) ?? []).map((raw) {
                              final item = raw as Map;
                              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                              final total = (item['totalRupees'] as num?)?.toDouble() ?? 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text('${item['name']}  ×$qty',
                                          style: const TextStyle(color: AppColors.white, fontSize: 12.5)),
                                    ),
                                    Text('₹${total.toStringAsFixed(2)}',
                                        style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Text('Total', style: TextStyle(color: AppColors.grey, fontSize: 14)),
                                const Spacer(),
                                Text('₹${((_invoice['totalRupees'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                    style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (_status == 'DRAFT')
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _finalizing ? null : _finalize,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: _finalizing
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.receipt_long_rounded, size: 18),
                                label: Text(_finalizing ? 'Generating…' : 'Generate Invoice',
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          if (_status != 'DRAFT')
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _downloading ? null : _download,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.white,
                                  side: const BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: _downloading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                                    : const Icon(Icons.download_rounded, size: 18),
                                label: Text(_downloading ? 'Preparing…' : 'Download PDF'),
                              ),
                            ),
                          if (_status != 'DRAFT' && _status != 'CANCELLED') ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _send,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.send_rounded, size: 18),
                                label: const Text('Send to Customer', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                          if (_status != 'CANCELLED' && _status != 'PAID') ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _cancelling ? null : _cancel,
                                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                child: Text(_cancelling ? 'Cancelling…' : 'Cancel Invoice'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  Color get _color => switch (status) {
        'DRAFT' => AppColors.greyDark,
        'PAID' => AppColors.success,
        'CANCELLED' || 'OVERDUE' => AppColors.error,
        'PARTIALLY_PAID' => AppColors.warning,
        _ => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
