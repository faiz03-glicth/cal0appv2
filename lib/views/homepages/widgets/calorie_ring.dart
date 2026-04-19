import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cal0appv2/theme/app_theme.dart';

class CalorieRing extends StatelessWidget {
  final int totalCalories;
  final int target;
  final int burned;

  const CalorieRing({
    super.key,
    required this.totalCalories,
    this.target = 2000, // swap with vm.calorieTarget later
    this.burned = 350, // swap with vm.caloriesBurned later
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final consumed = totalCalories.toDouble();
    final remaining = (target - consumed + burned).clamp(0, target);
    final progress = (consumed / target).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Calories',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: c.primary,
            ),
          ),
          const SizedBox(height: 16),
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
                        value: progress,
                        color: c.primary,
                        radius: 18,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 1 - progress,
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
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      'kcal left',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Eaten', '${consumed.toInt()}', c.primary),
              _buildStat('Burned', '${burned.toInt()}', c.warning),
              _buildStat('Goal', '${target.toInt()}', c.slate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: C0Theme.slateGrey),
        ),
      ],
    );
  }
}
