import 'package:flutter/material.dart';
import 'package:cal0appv2/theme/app_theme.dart';

class AppPillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  const AppPillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? c.primary : c.divider, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppSizes.miniIconSize - 2,
                color: selected ? Colors.white : c.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: selected ? Colors.white : c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.3)
                      : c.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.micro.copyWith(
                    color: selected ? Colors.white : c.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
