import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';

class AppSectionTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const AppSectionTitle({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.only(
      top: AppSpacing.sm,
      bottom: AppSpacing.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: AppTextStyles.sectionTitle.copyWith(color: c.primary),
      ),
    );
  }
}
