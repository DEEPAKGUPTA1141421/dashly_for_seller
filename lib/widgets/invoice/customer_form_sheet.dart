import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/invoice_draft.dart';
import '../../providers/invoices_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

class CustomerFormSheet extends ConsumerStatefulWidget {
  final InvoiceDraftCustomer? initial;
  const CustomerFormSheet({super.key, this.initial});

  static Future<InvoiceDraftCustomer?> show(BuildContext context, {InvoiceDraftCustomer? initial}) {
    return showModalBottomSheet<InvoiceDraftCustomer?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerFormSheet(initial: initial),
    );
  }

  @override
  ConsumerState<CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends ConsumerState<CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _gstinCtrl;

  static final _phoneRegex = RegExp(r'^[6-9]\d{9}$');
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _gstinRegex = RegExp(r'^[0-9A-Z]{15}$');

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.initial?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.initial?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.initial?.email ?? '');
    _gstinCtrl = TextEditingController(text: widget.initial?.gstin ?? '');
    Future.microtask(() => ref.read(invoicesPod.notifier).fetchCustomers());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _gstinCtrl.dispose();
    super.dispose();
  }

  void _pick(Map c) {
    setState(() {
      _nameCtrl.text  = c['name']?.toString() ?? '';
      _phoneCtrl.text = c['phone']?.toString() ?? '';
      _emailCtrl.text = c['email']?.toString() ?? '';
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    HapticUtils.medium();
    Navigator.of(context).pop(InvoiceDraftCustomer(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      gstin: _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final recentCustomers = ref.watch(invoicesPod).customers;
    final bottom = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Customer Details', style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),

            if (recentCustomers.isNotEmpty) ...[
              const Text('RECENT', style: TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recentCustomers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = recentCustomers[i] as Map;
                    return GestureDetector(
                      onTap: () => _pick(c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(18)),
                        child: Text(c['name']?.toString() ?? '', style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            _field('Name *', _nameCtrl, validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Customer name is required';
              return null;
            }),
            const SizedBox(height: 12),
            _field('Mobile', _phoneCtrl, keyboard: TextInputType.phone, validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return null;
              if (!_phoneRegex.hasMatch(value)) return 'Enter a valid 10-digit mobile number';
              return null;
            }),
            const SizedBox(height: 12),
            _field('Email', _emailCtrl, keyboard: TextInputType.emailAddress, validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return null;
              if (!_emailRegex.hasMatch(value)) return 'Enter a valid email address';
              return null;
            }),
            const SizedBox(height: 12),
            _field('GSTIN (optional)', _gstinCtrl, validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return null;
              if (!_gstinRegex.hasMatch(value.toUpperCase())) return 'Enter a valid 15-character GSTIN';
              return null;
            }),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Customer', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboard, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          validator: validator,
          style: const TextStyle(color: AppColors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.warning)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.warning)),
          ),
        ),
      ],
    );
  }
}
