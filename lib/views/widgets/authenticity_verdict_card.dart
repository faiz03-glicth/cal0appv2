import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart';

/// The single "Results of AI" card for the deterministic, rule-based
/// nitrogen-compound check. Used both on the live scan confirm sheet
/// (after a manual ingredient edit) and in food history (whenever a log
/// has ingredient text saved) — one visual component, one behavior,
/// everywhere in the app.
class AuthenticityVerdictCard extends StatelessWidget {
  final AuthenticityCheck? check;
  final String? unavailableTitle;
  final String? unavailableReason;

  const AuthenticityVerdictCard({
    super.key,
    required this.check,
    this.unavailableTitle,
    this.unavailableReason,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final cfg = _config(c);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cfg.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: cfg.border.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: cfg.accent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl - 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cfg.badgeIcon, color: Colors.white, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  cfg.badge,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cfg.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cfg.accent.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(cfg.icon, color: cfg.accent, size: 36),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  cfg.headline,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(
                    color: cfg.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  cfg.subLabel,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyCompact.copyWith(
                    color: cfg.accent.withValues(alpha: 0.75),
                  ),
                ),
                if (check != null && check!.nitrogenFlags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _FlaggedCompounds(agents: check!.nitrogenFlags, color: cfg.accent),
                ],
                const SizedBox(height: AppSpacing.md),
                _WhatThisMeans(explanation: cfg.explanation, color: cfg.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _Cfg _config(C0Colors c) {
    if (check == null) {
      return _Cfg(
        bg: c.card,
        border: c.divider,
        accent: c.textSecondary,
        badgeIcon: Icons.info_outline,
        icon: Icons.image_not_supported_outlined,
        badge: 'COULD NOT ANALYSE',
        headline: 'No Result',
        subLabel: unavailableTitle ?? 'No ingredient text available',
        explanation: unavailableReason ??
            'No ingredient text was found for this entry, so a nitrogen-compound '
                'check could not be run. Edit the entry and add the ingredient '
                'list to get an Authentic / Non-Authentic result.',
      );
    }
    if (check!.isNonAuthentic) {
      return _Cfg(
        bg: const Color(0xFFFEF2F2),
        border: const Color(0xFFEF4444),
        accent: const Color(0xFFDC2626),
        badgeIcon: Icons.warning_rounded,
        icon: Icons.dangerous_rounded,
        badge: 'NON-AUTHENTIC',
        headline: 'Non-Authentic',
        subLabel: 'Suspicious nitrogen compound found in the ingredients',
        explanation:
            'The ingredient list contains one or more nitrogen-based compounds '
            '(e.g. free-form amino acids or creatine) that are commonly used to '
            'artificially inflate protein readings without providing real whey '
            'protein.',
      );
    }
    return _Cfg(
      bg: const Color(0xFFECFDF5),
      border: const Color(0xFF22C55E),
      accent: const Color(0xFF16A34A),
      badgeIcon: Icons.verified,
      icon: Icons.shield_rounded,
      badge: 'AUTHENTIC',
      headline: 'Authentic',
      subLabel: 'No suspicious nitrogen compound found in the ingredients',
      explanation:
          'We checked the ingredient list for nitrogen-based compounds commonly '
          'used to inflate protein readings (e.g. free-form amino acids, '
          'creatine) and found none. This product appears to be genuine.',
    );
  }
}

class _Cfg {
  final Color bg, border, accent;
  final IconData badgeIcon, icon;
  final String badge, headline, subLabel, explanation;
  const _Cfg({
    required this.bg,
    required this.border,
    required this.accent,
    required this.badgeIcon,
    required this.icon,
    required this.badge,
    required this.headline,
    required this.subLabel,
    required this.explanation,
  });
}

class _FlaggedCompounds extends StatelessWidget {
  final List<DetectedIngredient> agents;
  final Color color;
  const _FlaggedCompounds({required this.agents, required this.color});

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
            'Flagged nitrogen compounds:',
            style: AppTextStyles.caption.copyWith(
              color: color,
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
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      a.name,
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

class _WhatThisMeans extends StatelessWidget {
  final String explanation;
  final Color color;
  const _WhatThisMeans({required this.explanation, required this.color});

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
            'This is a rule-based check, not a laboratory test. Always verify '
            'with official certification if purchasing in bulk.',
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