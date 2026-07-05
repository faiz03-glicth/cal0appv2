import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/views/theme/verdict_style.dart';
import 'package:cal0appv2/views/widgets/verdict_shared_widgets.dart';
import 'package:cal0appv2/viewModels/scan/scan_viewmodel.dart';

class WheyVerdictCard extends StatelessWidget {
  final ScanViewModel vm;
  const WheyVerdictCard({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final verdict = vm.authenticityVerdict;

    final style = vm.ingredientManuallyEdited
        ? VerdictStyle.manual(
            isNonAuthentic: verdict == AuthenticityVerdict.spiked,
          )
        : VerdictStyle.forAiVerdict(
            verdict,
            c,
            confidence: vm.aiConfidence,
            lowOcrQuality: vm.lowOcrQuality,
          );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: style.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: style.border.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top badge bar ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: style.accent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl - 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(style.badgeIcon, color: Colors.white, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  style.badgeText,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // ── Main content ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: style.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: style.accent.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(style.mainIcon, color: style.accent, size: 36),
                ),
                const SizedBox(height: AppSpacing.md),

                Text(
                  style.headline,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(
                    color: style.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                Text(
                  style.subLabel,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyCompact.copyWith(
                    color: style.accent.withValues(alpha: 0.75),
                  ),
                ),

                // Confidence bar (only when AI ran, and not for a manual
                // rule-based re-check — that's deterministic, not a
                // confidence score).
                if (verdict != AuthenticityVerdict.unknown &&
                    !vm.ingredientManuallyEdited) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _ConfidenceBar(
                    confidence: vm.aiConfidence,
                    color: style.accent,
                  ),
                ],

                // Detected spiking agents (non-authentic / spiked verdict only)
                if (verdict == AuthenticityVerdict.spiked &&
                    vm.detectedIngredients.any((d) => d.isAmSpiking)) ...[
                  const SizedBox(height: AppSpacing.md),
                  FlaggedCompoundChips(
                    names: vm.detectedIngredients
                        .where((d) => d.isAmSpiking)
                        .map((d) => d.name)
                        .toList(),
                    color: style.accent,
                    label: 'Flagged spiking agents:',
                  ),
                ],

                const SizedBox(height: AppSpacing.md),
                WhatThisMeansBox(
                  explanation: style.explanation,
                  color: style.whatItMeansColor,
                  disclaimer: verdict == AuthenticityVerdict.unknown
                      ? '' // no disclaimer needed when there's no result at all
                      : vm.ingredientManuallyEdited
                      ? 'This result is based on a rule-based scan of the '
                            'ingredients you edited, not the original AI model. '
                            'Always verify with official certification if '
                            'purchasing in bulk.'
                      : 'This is an AI-based estimate, not a laboratory '
                            'test. Always verify with official certification '
                            'if purchasing in bulk.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confidence bar sub-widget (unique to this card, not duplicated elsewhere) ──

class _ConfidenceBar extends StatelessWidget {
  final double confidence;
  final Color color;
  const _ConfidenceBar({required this.confidence, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final pct = confidence.clamp(0.0, 1.0);
    final label = confidence >= 0.80
        ? 'High confidence'
        : confidence >= 0.50
        ? 'Moderate confidence'
        : 'Low confidence';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI Confidence',
              style: AppTextStyles.caption.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(pct * 100).toStringAsFixed(0)}% — $label',
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
