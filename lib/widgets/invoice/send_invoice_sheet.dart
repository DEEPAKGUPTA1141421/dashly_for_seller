import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/app_toast.dart';
import '../../providers/invoices_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

/// Bottom sheet to pick a delivery channel (+ optional destination override)
/// and queue the invoice for sending. Returns true via Navigator.pop if the
/// send request was accepted, so the caller can refresh.
class SendInvoiceSheet extends ConsumerStatefulWidget {
  final String invoiceId;
  final Map<String, dynamic> invoice;
  const SendInvoiceSheet({super.key, required this.invoiceId, required this.invoice});

  static Future<bool?> show(BuildContext context, String invoiceId, Map<String, dynamic> invoice) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendInvoiceSheet(invoiceId: invoiceId, invoice: invoice),
    );
  }

  @override
  ConsumerState<SendInvoiceSheet> createState() => _SendInvoiceSheetState();
}

class _SendInvoiceSheetState extends ConsumerState<SendInvoiceSheet> {
  String? _sendingChannel;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final customer = widget.invoice['customer'] as Map?;
    _phoneCtrl = TextEditingController(text: customer?['phone']?.toString() ?? '');
    _emailCtrl = TextEditingController(text: customer?['email']?.toString() ?? '');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String channel, String destination) async {
    if (destination.trim().isEmpty) {
      AppToast.show(context, message: 'Enter a ${channel == 'WHATSAPP' ? 'phone number' : 'email address'}', type: ToastType.error);
      return;
    }
    HapticUtils.medium();
    setState(() => _sendingChannel = channel);
    try {
      final ok = await ref.read(invoicesPod.notifier).sendInvoice(widget.invoiceId, channel, destination: destination.trim());
      if (!mounted) return;
      if (ok) {
        AppToast.show(context, message: 'Invoice queued for delivery', type: ToastType.success);
        Navigator.of(context).pop(true);
      } else {
        AppToast.show(context, message: 'Could not send invoice', type: ToastType.error);
      }
    } on AppException catch (e) {
      if (mounted) AppToast.show(context, message: e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _sendingChannel = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Send Invoice', style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          const Text('WHATSAPP', style: TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppColors.white, fontSize: 14),
            decoration: _fieldDecoration('Phone number'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sendingChannel != null ? null : () => _send('WHATSAPP', _phoneCtrl.text),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _sendingChannel == 'WHATSAPP'
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.chat_rounded, size: 18),
              label: const Text('Send via WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),

          const SizedBox(height: 20),
          const Text('EMAIL', style: TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.white, fontSize: 14),
            decoration: _fieldDecoration('Email address'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sendingChannel != null ? null : () => _send('EMAIL', _emailCtrl.text),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _sendingChannel == 'EMAIL'
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                  : const Icon(Icons.email_rounded, size: 18),
              label: const Text('Send via Email', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );
}
