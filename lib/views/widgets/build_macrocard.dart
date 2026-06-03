import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';

/// Macro summary card used in the dashboard MacroRow.
/// Displays label, current value, a progress bar, and the target.
class BuildMacroCard extends StatelessWidget {
  final C0Colors c;
  final String label;
  final double current;
  final double target;
  final Color color;

  const BuildMacroCard({
    super.key,
    required this.c,
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (current / target).clamp(0.0, 1.0);
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.tiny.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              '${current.toStringAsFixed(1)}g',
              style: AppTextStyles.statValue.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '/ ${target.toStringAsFixed(0)}g',
              style: AppTextStyles.micro.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
