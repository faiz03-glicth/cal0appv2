import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/dashboard/dashboard_viewmodel.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';

class TdeeInfoCard extends StatelessWidget {
  const TdeeInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = context.watch<DashboardViewModel>();

    if (vm.isLoading || vm.bmr == 0) return const SizedBox.shrink();

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.calculate_outlined, size: 15, color: c.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Energy Calculation',
                style: AppTextStyles.bodyCompact.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  vm.tdeeFormula,
                  style: AppTextStyles.micro.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // BMR → TDEE → Target flow
          Row(
            children: [
              _EnergyStep(
                label: 'BMR',
                value: '${vm.bmr}',
                sub: 'base metabolic rate',
                color: c.slate,
              ),
              _Arrow(color: c.divider),
              _EnergyStep(
                label: 'TDEE',
                value: '${vm.tdee}',
                sub: '×${vm.activityMult.toStringAsFixed(3)} activity',
                color: c.primary.withOpacity(0.8),
              ),
              _Arrow(color: c.divider),
              _EnergyStep(
                label: 'Target',
                value: '${vm.calorieTarget}',
                sub: '${vm.user?.goal ?? 'maintain'} goal',
                color: c.primary,
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Sanity note
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: c.textSecondary),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                  child: Text(
                    'Update your profile (age, weight, height, activity) for the most accurate targets.',
                    style: AppTextStyles.micro.copyWith(
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyStep extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final bool highlight;

  const _EnergyStep({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: 6,
        ),
        decoration: highlight
            ? BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: color.withOpacity(0.3)),
              )
            : null,
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.statValue.copyWith(
                color: color,
                fontSize: highlight ? 20 : 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'kcal',
              style: AppTextStyles.micro.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.tiny.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: AppTextStyles.micro.copyWith(
                color: c.textSecondary,
                fontSize: 9,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final Color color;
  const _Arrow({required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Icon(Icons.arrow_forward, size: 14, color: color),
  );
}
