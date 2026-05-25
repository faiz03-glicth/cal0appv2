import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';
import 'package:cal0appv2/models/nutrient_totals.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';
import 'package:cal0appv2/views/widgets/macro_progress_bar.dart';

class NutrientSection extends StatelessWidget {
  const NutrientSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Selector rebuilds ONLY when NutrientTotals changes.
    // NutrientTotals has value equality, so identical totals skip rebuilds.
    return Selector<FoodLogViewModel, NutrientTotals>(
      selector: (_, vm) => vm.totals,
      builder: (context, totals, _) {
        return _NutrientContent(totals: totals);
      },
    );
  }
}

class _NutrientContent extends StatelessWidget {
  final NutrientTotals totals;
  const _NutrientContent({required this.totals});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);

    return AppCard(
      margin: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Nutrients',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              if (totals.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.divider,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'No food logged',
                    style: AppTextStyles.micro.copyWith(color: c.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Sugar — from food log model
          MacroProgressBar(
            label: 'Sugar',
            value: totals.sugar,
            max: 50,
            unit: 'g',
            color: C0Theme.macroSugar,
          ),

          // Sodium — from food log model
          MacroProgressBar(
            label: 'Sodium',
            value: totals.sodium,
            max: 2300,
            unit: 'mg',
            color: C0Theme.macroSodium,
          ),

          // Fibre — not tracked in the food model yet; show placeholder
          _StaticNutrient(
            label: 'Fibre',
            note: 'Not tracked yet',
            color: c.success,
          ),

          // Calcium — not tracked in the food model yet; show placeholder
          _StaticNutrient(
            label: 'Calcium',
            note: 'Not tracked yet',
            color: c.primary,
          ),

          if (totals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Log food to see your nutrient breakdown',
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown for nutrients not yet tracked in FoodLogModel.
class _StaticNutrient extends StatelessWidget {
  final String label;
  final String note;
  final Color color;
  const _StaticNutrient({
    required this.label,
    required this.note,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
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
                note,
                style: AppTextStyles.micro.copyWith(
                  color: c.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.xs),
            child: LinearProgressIndicator(
              value: 0,
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
