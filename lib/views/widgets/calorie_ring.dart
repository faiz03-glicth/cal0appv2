import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';

class CalorieRing extends StatelessWidget {
  final int totalCalories;
  final int target;
  final int burned;

  const CalorieRing({
    super.key,
    required this.totalCalories,
    this.target = 2000,
    this.burned = 350,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final consumed = totalCalories.toDouble();
    final remaining = (target - consumed + burned).clamp(0, target);
    final progress = (consumed / target).clamp(0.0, 1.0);

    return AppCard(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadius.xxl,
      child: Column(
        children: [
          Text(
            'Calories',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.bold,
              color: c.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 0,
                    centerSpaceRadius: 65,
                    sections: [
                      PieChartSectionData(
                        value: progress > 0 ? progress : 0.001,
                        color: progress > 0 ? c.primary : c.track,
                        radius: 18,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 1 - (progress > 0 ? progress : 0.001),
                        color: c.track,
                        radius: 18,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${remaining.toInt()}',
                      style: AppTextStyles.ringValue.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      consumed > 0 ? 'kcal left' : 'kcal goal',
                      style: AppTextStyles.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat('Eaten', '${consumed.toInt()}', c.primary),
              _Stat('Burned', '${burned.toInt()}', c.warning),
              _Stat('Goal', '${target.toInt()}', c.slate),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.statValue.copyWith(color: color)),
        Text(
          label,
          style: AppTextStyles.statLabel.copyWith(color: C0Theme.slateGrey),
        ),
      ],
    );
  }
}
