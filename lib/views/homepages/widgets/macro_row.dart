import 'package:flutter/material.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/views/homepages/widgets/build_macrocard.dart';

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
          BuildMacroCard(
            c: c,
            label: 'Protein',
            current: totalProtein,
            target: targets['protein'] ?? 150,
            color: c.primary,
          ),
          const SizedBox(width: 10),
          BuildMacroCard(
            c: c,
            label: 'Carbs',
            current: totalCarbs,
            target: targets['carbs'] ?? 250,
            color: c.success,
          ),
          const SizedBox(width: 10),
          BuildMacroCard(
            c: c,
            label: 'Fat',
            current: totalFat,
            target: targets['fat'] ?? 65,
            color: c.slate,
          ),
        ],
      ),
    );
  }
}
