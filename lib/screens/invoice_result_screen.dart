import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/errors/app_exception.dart';
import '../core/widgets/app_toast.dart';
import '../providers/invoices_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/invoice/send_invoice_sheet.dart';

/// Shown right after an invoice is finalized — "Invoice Generated ✓" plus
/// the WhatsApp / Email / Download actions. Pops back to the Invoices list
/// (not the Create Invoice form) when the seller is done here.
class InvoiceResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> invoice;
  const InvoiceResultScreen({super.key, required this.invoice});

  @override
  ConsumerState<InvoiceResultScreen> createState() => _InvoiceResultScreenState();
}

class _InvoiceResultScreenState extends ConsumerState<InvoiceResultScreen> {
  bool _downloading = false;

  String get _invoiceId => widget.invoice['id'].toString();
  String? get _invoiceNumber => widget.invoice['invoiceNumber'] as String?;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final download = await ref.read(invoicesPod.notifier).downloadPdf(_invoiceId, invoiceNumber: _invoiceNumber);
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/${download.filename}');
      await file.writeAsBytes(download.bytes, flush: true);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], subject: download.filename);
    } on AppException catch (e) {
      if (mounted) AppToast.show(context, message: e.message, type: ToastType.error);
    } catch (_) {
      if (mounted) AppToast.show(context, message: 'Could not download invoice', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _send() async {
    HapticUtils.light();
    await SendInvoiceSheet.show(context, _invoiceId, widget.invoice);
  }

  @override
  Widget build(BuildContext context) {
    final total = (widget.invoice['totalRupees'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 44),
              ),
              const SizedBox(height: 20),
              const Text('Invoice Generated', style: TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_invoiceNumber ?? '', style: const TextStyle(color: AppColors.grey, fontSize: 14)),
              const SizedBox(height: 4),
              Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send to Customer', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _downloading ? null : _download,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _downloading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(_downloading ? 'Preparing…' : 'Download PDF'),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Done', style: TextStyle(color: AppColors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
