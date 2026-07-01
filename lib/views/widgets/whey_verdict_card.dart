import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/scan/scan_viewmodel.dart';

class WheyVerdictCard extends StatelessWidget {
  final ScanViewModel vm;
  const WheyVerdictCard({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final verdict = vm.authenticityVerdict;

    final config = _verdictConfig(verdict, c, vm);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: config.borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: config.borderColor.withValues(alpha: 0.25),
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
              color: config.accentColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl - 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(config.badgeIcon, color: Colors.white, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  config.badgeText,
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
                // Big verdict icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: config.accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: config.accentColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    config.mainIcon,
                    color: config.accentColor,
                    size: 36,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Verdict headline
                Text(
                  config.headline,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(
                    color: config.accentColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Sub-label
                Text(
                  config.subLabel,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyCompact.copyWith(
                    color: config.accentColor.withValues(alpha: 0.75),
                  ),
                ),

                // Confidence bar (only when AI ran)
                if (verdict != AuthenticityVerdict.unknown) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _ConfidenceBar(
                    confidence: vm.aiConfidence,
                    color: config.accentColor,
                  ),
                ],

                // Detected spiking agents summary (only for spiked verdict)
                if (verdict == AuthenticityVerdict.spiked &&
                    vm.detectedIngredients.any((d) => d.isAmSpiking)) ...[
                  const SizedBox(height: AppSpacing.md),
                  _SpikingAgentsSummary(
                    agents: vm.detectedIngredients
                        .where((d) => d.isAmSpiking)
                        .toList(),
                  ),
                ],

                // What this means section
                const SizedBox(height: AppSpacing.md),
                _WhatThisMeans(verdict: verdict, config: config),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _VerdictConfig _verdictConfig(
    AuthenticityVerdict verdict,
    C0Colors c,
    ScanViewModel vm,
  ) {
    final pct = '${(vm.aiConfidence * 100).toStringAsFixed(0)}%';

    switch (verdict) {
      case AuthenticityVerdict.authentic:
        return _VerdictConfig(
          bgColor: const Color(0xFFECFDF5),
          borderColor: const Color(0xFF22C55E),
          accentColor: const Color(0xFF16A34A),
          badgeIcon: Icons.verified,
          badgeText: 'AUTHENTIC PRODUCT',
          mainIcon: Icons.shield_rounded,
          headline: 'Looks Authentic ✓',
          subLabel: '$pct confidence — no amino spiking detected',
          explanation:
              'Our AI found no suspicious nitrogen-inflating amino acids '
              'in the ingredient list. This product appears to be genuine whey.',
          whatItMeansColor: const Color(0xFF15803D),
        );

      case AuthenticityVerdict.spiked:
        return _VerdictConfig(
          bgColor: const Color(0xFFFEF2F2),
          borderColor: const Color(0xFFEF4444),
          accentColor: const Color(0xFFDC2626),
          badgeIcon: Icons.warning_rounded,
          badgeText: 'AMINO SPIKING DETECTED',
          mainIcon: Icons.dangerous_rounded,
          headline: '⚠ Spiking Detected',
          subLabel: '$pct confidence — suspicious ingredients found',
          explanation:
              'The AI detected one or more cheap amino acids commonly used to '
              'inflate protein readings on lab tests without delivering real '
              'muscle-building benefit.',
          whatItMeansColor: const Color(0xFFB91C1C),
        );

      case AuthenticityVerdict.plantBased:
        return _VerdictConfig(
          bgColor: const Color(0xFFF0FDF4),
          borderColor: const Color(0xFF4ADE80),
          accentColor: const Color(0xFF15803D),
          badgeIcon: Icons.eco,
          badgeText: 'PLANT-BASED PROTEIN',
          mainIcon: Icons.eco_rounded,
          headline: '🌱 Plant-Based',
          subLabel: '$pct confidence — not whey protein',
          explanation:
              'This product appears to contain plant-based protein (pea, rice, '
              'soy, etc.) rather than whey. There is no amino spiking concern '
              'specific to whey, but verify the label matches your goals.',
          whatItMeansColor: const Color(0xFF15803D),
        );

      case AuthenticityVerdict.lowConf:
        return _VerdictConfig(
          bgColor: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFF59E0B),
          accentColor: const Color(0xFFD97706),
          badgeIcon: Icons.help_outline,
          badgeText: 'LOW CONFIDENCE — VERIFY MANUALLY',
          mainIcon: Icons.help_center_rounded,
          headline: 'Uncertain',
          subLabel: '$pct confidence — below reliable threshold',
          explanation:
              'The AI processed the ingredient text but its confidence is too '
              'low to make a reliable call. The ingredient list may be unclear '
              'or in an unusual format. Check the flagged ingredients below '
              'and verify with the physical label.',
          whatItMeansColor: const Color(0xFFB45309),
        );

      case AuthenticityVerdict.unknown:
        return _VerdictConfig(
          bgColor: c.card,
          borderColor: c.divider,
          accentColor: c.textSecondary,
          badgeIcon: Icons.info_outline,
          badgeText: 'COULD NOT ANALYSE',
          mainIcon: Icons.image_not_supported_outlined,
          headline: 'No Result',
          subLabel: vm.lowOcrQuality
              ? 'Image quality too low for analysis'
              : 'Ingredient text not found',
          explanation: vm.lowOcrQuality
              ? 'The scan quality was too low. Retake the photo in good '
                    'lighting, hold the camera steady, and keep the label flat.'
              : 'No ingredient section was detected. Make sure the '
                    'Ingredients panel is clearly visible in one of your photos.',
          whatItMeansColor: c.textSecondary,
        );
    }
  }
}

// ── Supporting data class ─────────────────────────────────────────────────

class _VerdictConfig {
  final Color bgColor;
  final Color borderColor;
  final Color accentColor;
  final IconData badgeIcon;
  final String badgeText;
  final IconData mainIcon;
  final String headline;
  final String subLabel;
  final String explanation;
  final Color whatItMeansColor;

  const _VerdictConfig({
    required this.bgColor,
    required this.borderColor,
    required this.accentColor,
    required this.badgeIcon,
    required this.badgeText,
    required this.mainIcon,
    required this.headline,
    required this.subLabel,
    required this.explanation,
    required this.whatItMeansColor,
  });
}

// ── Confidence bar sub-widget ─────────────────────────────────────────────

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

// ── Spiking agents summary ────────────────────────────────────────────────

class _SpikingAgentsSummary extends StatelessWidget {
  final List<DetectedIngredient> agents;
  const _SpikingAgentsSummary({required this.agents});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: const Color(0xFFDC2626).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Flagged spiking agents:',
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFFB91C1C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: agents
                .map(
                  (a) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      a.name,
                      style: AppTextStyles.micro.copyWith(
                        color: const Color(0xFFB91C1C),
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

// ── What this means section ───────────────────────────────────────────────

class _WhatThisMeans extends StatelessWidget {
  final AuthenticityVerdict verdict;
  final _VerdictConfig config;
  const _WhatThisMeans({required this.verdict, required this.config});

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
              Icon(
                Icons.lightbulb_outline,
                size: 14,
                color: config.whatItMeansColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'What this means',
                style: AppTextStyles.caption.copyWith(
                  color: config.whatItMeansColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            config.explanation,
            style: AppTextStyles.caption.copyWith(
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
          if (verdict != AuthenticityVerdict.unknown) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'This is an AI-based estimate, not a laboratory test. '
              'Always verify with official certification if purchasing in bulk.',
              style: AppTextStyles.micro.copyWith(
                color: c.textSecondary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
