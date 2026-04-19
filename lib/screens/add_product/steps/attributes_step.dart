import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../providers/add_product_provider.dart';
import '../../../utils/app_colors.dart';

class AttributesStep extends ConsumerStatefulWidget {
  const AttributesStep({super.key});

  @override
  ConsumerState<AttributesStep> createState() => _AttributesStepState();
}

class _AttributesStepState extends ConsumerState<AttributesStep> {
  // text/number attributes
  final Map<String, TextEditingController> _controllers = {};
  // enumeration attributes  — id → selected option(s)
  final Map<String, Set<String>> _selectedOptions = {};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final s = ref.read(addProductPod);
    for (final raw in s.attributes) {
      final attr      = raw as Map;
      final id        = _attrId(attr);
      if (id.isEmpty) continue;
      final fieldType = (attr['fieldType'] as String? ?? 'TEXT').toUpperCase();
      final saved     = s.attributeValues[id] ?? '';

      if (fieldType == 'ENUMERATION') {
        _selectedOptions[id] = saved.isNotEmpty
            ? saved.split(',').map((v) => v.trim()).toSet()
            : {};
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

  String _attrId(Map attr) =>
      attr['id']?.toString() ?? attr['attributeId']?.toString() ?? '';

  void _next() {
    final values = <String, String>{};

    for (final e in _controllers.entries) {
      final v = e.value.text.trim();
      if (v.isNotEmpty) values[e.key] = v;
    }
    for (final e in _selectedOptions.entries) {
      if (e.value.isNotEmpty) values[e.key] = e.value.join(',');
    }

    ref.read(addProductPod.notifier).saveAttributes(values);
  }

  @override
  Widget build(BuildContext context) {
    final attrs = ref.watch(addProductPod).attributes;

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
                    child: const Icon(Icons.tune_rounded, color: AppColors.grey, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No attributes for this category',
                    style: TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'You can skip this step.',
                    style: TextStyle(color: AppColors.grey, fontSize: 13),
                  ),
                ],
              ).animate().fadeIn(),
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fill in specifications for your product.',
                  style: TextStyle(color: AppColors.grey, fontSize: 14),
                ).animate().fadeIn(),
                const SizedBox(height: 20),
                ...attrs.asMap().entries.map((e) {
                  final attr      = e.value as Map;
                  final id        = _attrId(attr);
                  final name      = attr['name'] as String? ?? attr['attributeName'] as String? ?? 'Attribute';
                  final required  = attr['isRequired'] as bool? ?? attr['required'] as bool? ?? false;
                  final fieldType = (attr['fieldType'] as String? ?? 'TEXT').toUpperCase();
                  final isRadio   = attr['isRadio'] as bool? ?? true;
                  final options   = (attr['options'] as List<dynamic>?)?.cast<String>() ?? [];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: fieldType == 'ENUMERATION' && options.isNotEmpty
                        ? _EnumField(
                            id:       id,
                            label:    name,
                            required: required,
                            isRadio:  isRadio,
                            options:  options,
                            selected: _selectedOptions[id] ?? {},
                            onChanged: (updated) =>
                                setState(() => _selectedOptions[id] = updated),
                          ).animate().fadeIn(delay: Duration(milliseconds: e.key * 60))
                        : AppTextField(
                            hint:      'Enter $name',
                            label:     '${name.toUpperCase()}${required ? ' *' : ''}',
                            controller: _controllers[id] ?? TextEditingController(),
                            keyboardType: fieldType == 'NUMBER'
                                ? TextInputType.number
                                : TextInputType.text,
                            validator: required
                                ? (v) => (v == null || v.isEmpty) ? 'Required' : null
                                : null,
                          ).animate().fadeIn(delay: Duration(milliseconds: e.key * 60)),
                  );
                }),
              ],
            ),
          ),
        ),
        _BottomBar(onNext: _next),
      ],
    );
  }
}

// ── Enumeration field ──────────────────────────────────────────────────────────

class _EnumField extends StatelessWidget {
  final String       id;
  final String       label;
  final bool         required;
  final bool         isRadio;   // true → single select, false → multi-select
  final List<String> options;
  final Set<String>  selected;
  final ValueChanged<Set<String>> onChanged;

  const _EnumField({
    required this.id,
    required this.label,
    required this.required,
    required this.isRadio,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${label.toUpperCase()}${required ? ' *' : ''}',
          style: const TextStyle(
            color: AppColors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return GestureDetector(
              onTap: () {
                final updated = Set<String>.from(selected);
                if (isRadio) {
                  // Single select: replace
                  onChanged({opt});
                } else {
                  // Multi-select: toggle
                  if (isSelected) {
                    updated.remove(opt);
                  } else {
                    updated.add(opt);
                  }
                  onChanged(updated);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:        isSelected ? AppColors.white : AppColors.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.white : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isRadio)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          isSelected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 16,
                          color: isSelected ? AppColors.bg : AppColors.grey,
                        ),
                      ),
                    Text(
                      opt,
                      style: TextStyle(
                        color:      isSelected ? AppColors.bg : AppColors.white,
                        fontSize:   13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onNext;
  const _BottomBar({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: AppButton(
        label: 'Continue',
        onTap: onNext,
        icon: Icons.arrow_forward_rounded,
      ),
    );
  }
}
