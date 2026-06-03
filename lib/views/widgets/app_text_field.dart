import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final bool isNumber;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final String? label;

  const AppTextField({
    super.key,
    this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.isNumber = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.fieldLabel.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType:
              keyboardType ??
              (isNumber ? TextInputType.number : TextInputType.text),
          validator: validator,
          onChanged: onChanged,
          style: AppTextStyles.fieldText.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.fieldHint.copyWith(color: c.textSecondary),
            prefixIcon: icon == null
                ? null
                : Icon(icon, color: c.primary, size: AppSizes.fieldIconSize),
            filled: true,
            fillColor: c.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.formBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.warning, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.warning, width: 1.5),
            ),
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }
}
