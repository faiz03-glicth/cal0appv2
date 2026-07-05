import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';

/// Chip list of flagged ingredient/compound names, colored to match the
/// parent verdict card's accent color.
///
/// Replaces the previously duplicated `_FlaggedCompounds` (in
/// authenticity_verdict_card.dart) and `_SpikingAgentsSummary` (in
/// whey_verdict_card.dart), which rendered identical UI — one took a
/// dynamic color, the other hardcoded red.
class FlaggedCompoundChips extends StatelessWidget {
  final List<String> names;
  final Color color;
  final String label;

  const FlaggedCompoundChips({
    super.key,
    required this.names,
    required this.color,
    this.label = 'Flagged compounds:',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: names
                .map(
                  (name) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      name,
                      style: AppTextStyles.micro.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// The "What this means" explanation box shown at the bottom of every
/// verdict card. Replaces two separately-defined `_WhatThisMeans` widgets
/// (one per card) that rendered identical layout with slightly different
/// constructor shapes.
class WhatThisMeansBox extends StatelessWidget {
  final String explanation;
  final Color color;
  final String disclaimer;

  const WhatThisMeansBox({
    super.key,
    required this.explanation,
    required this.color,
    this.disclaimer =
        'This is a rule-based check, not a laboratory test. '
        'Always verify with official certification if purchasing in bulk.',
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 14, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'What this means',
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            explanation,
            style: AppTextStyles.caption.copyWith(
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            disclaimer,
            style: AppTextStyles.micro.copyWith(
              color: c.textSecondary.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
