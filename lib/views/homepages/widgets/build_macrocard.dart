import 'package:flutter/material.dart';
import 'package:cal0appv2/theme/app_theme.dart';

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
              '/ ${target.toStringAsFixed(0)}g',
              style: TextStyle(fontSize: 10, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
