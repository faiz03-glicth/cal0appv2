import 'package:flutter/material.dart';
import 'package:cal0appv2/theme/app_theme.dart';

class MacroRow extends StatelessWidget {
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final Map<String, double> targets;

  const MacroRow({
    super.key,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.targets,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildMacroCard(
            c,
            'Protein',
            totalProtein,
            targets['protein'] ?? 150,
            c.primary,
          ),
          const SizedBox(width: 10),
          _buildMacroCard(
            c,
            'Carbs',
            totalCarbs,
            targets['carbs'] ?? 250,
            c.success,
          ),
          const SizedBox(width: 10),
          _buildMacroCard(c, 'Fat', totalFat, targets['fat'] ?? 65, c.slate),
        ],
      ),
    );
  }

  Widget _buildMacroCard(
    C0Colors c,
    String label,
    int current,
    int target,
    Color color,
  ) {
    final pct = (current / target).clamp(0.0, 1.0);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${current.toStringAsFixed(1)}g',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: color.withOpacity(0.15),
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '/ ${target}g',
              style: TextStyle(fontSize: 10, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
