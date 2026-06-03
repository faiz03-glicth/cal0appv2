import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/views/widgets/sheet_handle.dart';

class AppBottomSheet extends StatelessWidget {
  final String? title;
  final Widget? subtitle;
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  const AppBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxl + 4,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: AppSpacing.lg),
              if (title != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title!,
                    style: AppTextStyles.title.copyWith(color: c.textPrimary),
                  ),
                ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                subtitle!,
              ],
              if (title != null) const SizedBox(height: AppSpacing.lg),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
