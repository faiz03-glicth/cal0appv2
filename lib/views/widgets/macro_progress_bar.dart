import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';

class MacroProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final String unit;
  final Color color;

  const MacroProgressBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.unit = 'g',
  });

  String _formatValue() {
    if (value == value.truncate()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final pct = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(color: c.textPrimary),
              ),
              Text(
                '${_formatValue()} $unit',
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.xs),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
