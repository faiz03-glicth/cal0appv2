import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/views/theme/verdict_style.dart';
import 'package:cal0appv2/views/widgets/verdict_shared_widgets.dart';
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
    final style = check == null
        ? VerdictStyle.unavailable(
            c,
            subLabel: unavailableTitle,
            explanation: unavailableReason,
          )
        : VerdictStyle.manual(isNonAuthentic: check!.isNonAuthentic);

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
                if (check != null && check!.nitrogenFlags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  FlaggedCompoundChips(
                    names: check!.nitrogenFlags.map((a) => a.name).toList(),
                    color: style.accent,
                    label: 'Flagged nitrogen compounds:',
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                WhatThisMeansBox(
                  explanation: style.explanation,
                  color: style.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
