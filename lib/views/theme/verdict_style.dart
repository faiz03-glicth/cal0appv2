import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/scan/scan_viewmodel.dart';

/// Single shared source of truth for how each [AuthenticityVerdict] is
/// presented across the app — colors, icons, badge text, headline,
/// sub-label, and explanation copy all live here exactly once.
///
/// Previously this logic was independently duplicated in
/// `AuthenticityVerdictCard._config()`, `WheyVerdictCard._verdictConfig()`,
/// and `food_detail_view.dart`'s `_LegacyStyle _style()` — three separate
/// copies of the same hex colors and near-identical copy. Any visual tweak
/// (e.g. changing the "spiked" red) previously had to be made in three
/// places; now it's made here once.
class VerdictStyle {
  final Color bg;
  final Color border;
  final Color accent;
  final Color whatItMeansColor;
  final IconData badgeIcon;
  final IconData mainIcon;
  final String badgeText;
  final String headline;
  final String subLabel;
  final String explanation;

  const VerdictStyle({
    required this.bg,
    required this.border,
    required this.accent,
    this.whatItMeansColor = Colors.transparent, // overridden below when unused
    required this.badgeIcon,
    required this.mainIcon,
    required this.badgeText,
    required this.headline,
    required this.subLabel,
    required this.explanation,
  });

  /// Style for a manual, deterministic rule-based re-check (used after the
  /// user edits the ingredient list by hand — no AI confidence score).
  factory VerdictStyle.manual({required bool isNonAuthentic}) {
    if (isNonAuthentic) {
      return VerdictStyle(
        bg: const Color(0xFFFEF2F2),
        border: const Color(0xFFEF4444),
        accent: const Color(0xFFDC2626),
        whatItMeansColor: const Color(0xFFB91C1C),
        badgeIcon: Icons.warning_rounded,
        mainIcon: Icons.dangerous_rounded,
        badgeText: 'NON-AUTHENTIC',
        headline: 'Non-Authentic',
        subLabel: 'Suspicious nitrogen compound found in the ingredients',
        explanation:
            'The ingredient list contains one or more nitrogen-based compounds '
            '(e.g. free-form amino acids or creatine) that are commonly used to '
            'artificially inflate protein readings without providing real whey '
            'protein.',
      );
    }
    return VerdictStyle(
      bg: const Color(0xFFECFDF5),
      border: const Color(0xFF22C55E),
      accent: const Color(0xFF16A34A),
      whatItMeansColor: const Color(0xFF15803D),
      badgeIcon: Icons.verified,
      mainIcon: Icons.shield_rounded,
      badgeText: 'AUTHENTIC',
      headline: 'Authentic',
      subLabel: 'No suspicious nitrogen compound found in the ingredients',
      explanation:
          'We checked the ingredient list for nitrogen-based compounds commonly '
          'used to inflate protein readings (e.g. free-form amino acids, '
          'creatine) and found none. This product appears to be genuine.',
    );
  }

  /// Style for the original AI-scored verdict (confidence-based, from the
  /// ONNX model) — used on the live scan result before any manual edit.
  factory VerdictStyle.forAiVerdict(
    AuthenticityVerdict verdict,
    C0Colors c, {
    required double confidence,
    required bool lowOcrQuality,
  }) {
    final pct = '${(confidence * 100).toStringAsFixed(0)}%';

    switch (verdict) {
      case AuthenticityVerdict.authentic:
        return VerdictStyle(
          bg: const Color(0xFFECFDF5),
          border: const Color(0xFF22C55E),
          accent: const Color(0xFF16A34A),
          whatItMeansColor: const Color(0xFF15803D),
          badgeIcon: Icons.verified,
          mainIcon: Icons.shield_rounded,
          badgeText: 'AUTHENTIC PRODUCT',
          headline: 'Looks Authentic ✓',
          subLabel: '$pct confidence — no amino spiking detected',
          explanation:
              'Our AI found no suspicious nitrogen-inflating amino acids '
              'in the ingredient list. This product appears to be genuine whey.',
        );

      case AuthenticityVerdict.spiked:
        return VerdictStyle(
          bg: const Color(0xFFFEF2F2),
          border: const Color(0xFFEF4444),
          accent: const Color(0xFFDC2626),
          whatItMeansColor: const Color(0xFFB91C1C),
          badgeIcon: Icons.warning_rounded,
          mainIcon: Icons.dangerous_rounded,
          badgeText: 'AMINO SPIKING DETECTED',
          headline: '⚠ Spiking Detected',
          subLabel: '$pct confidence — suspicious ingredients found',
          explanation:
              'The AI detected one or more cheap amino acids commonly used to '
              'inflate protein readings on lab tests without delivering real '
              'muscle-building benefit.',
        );

      case AuthenticityVerdict.plantBased:
        return VerdictStyle(
          bg: const Color(0xFFF0FDF4),
          border: const Color(0xFF4ADE80),
          accent: const Color(0xFF15803D),
          whatItMeansColor: const Color(0xFF15803D),
          badgeIcon: Icons.eco,
          mainIcon: Icons.eco_rounded,
          badgeText: 'PLANT-BASED PROTEIN',
          headline: '🌱 Plant-Based',
          subLabel: '$pct confidence — not whey protein',
          explanation:
              'This product appears to contain plant-based protein (pea, rice, '
              'soy, etc.) rather than whey. There is no amino spiking concern '
              'specific to whey, but verify the label matches your goals.',
        );

      case AuthenticityVerdict.lowConf:
        return VerdictStyle(
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFF59E0B),
          accent: const Color(0xFFD97706),
          whatItMeansColor: const Color(0xFFB45309),
          badgeIcon: Icons.help_outline,
          mainIcon: Icons.help_center_rounded,
          badgeText: 'LOW CONFIDENCE — VERIFY MANUALLY',
          headline: 'Uncertain',
          subLabel: '$pct confidence — below reliable threshold',
          explanation:
              'The AI processed the ingredient text but its confidence is too '
              'low to make a reliable call. The ingredient list may be unclear '
              'or in an unusual format. Check the flagged ingredients below '
              'and verify with the physical label.',
        );

      case AuthenticityVerdict.unknown:
        return VerdictStyle(
          bg: c.card,
          border: c.divider,
          accent: c.textSecondary,
          whatItMeansColor: c.textSecondary,
          badgeIcon: Icons.info_outline,
          mainIcon: Icons.image_not_supported_outlined,
          badgeText: 'COULD NOT ANALYSE',
          headline: 'No Result',
          subLabel: lowOcrQuality
              ? 'Image quality too low for analysis'
              : 'Ingredient text not found',
          explanation: lowOcrQuality
              ? 'The scan quality was too low. Retake the photo in good '
                    'lighting, hold the camera steady, and keep the label flat.'
              : 'No ingredient section was detected. Make sure the '
                    'Ingredients panel is clearly visible in one of your photos.',
        );
    }
  }

  /// Style for when there's no check result at all (e.g. no ingredient
  /// text was ever saved for this entry).
  factory VerdictStyle.unavailable(
    C0Colors c, {
    String? subLabel,
    String? explanation,
  }) {
    return VerdictStyle(
      bg: c.card,
      border: c.divider,
      accent: c.textSecondary,
      whatItMeansColor: c.textSecondary,
      badgeIcon: Icons.info_outline,
      mainIcon: Icons.image_not_supported_outlined,
      badgeText: 'COULD NOT ANALYSE',
      headline: 'No Result',
      subLabel: subLabel ?? 'No ingredient text available',
      explanation:
          explanation ??
          'No ingredient text was found for this entry, so a nitrogen-compound '
              'check could not be run. Edit the entry and add the ingredient '
              'list to get an Authentic / Non-Authentic result.',
    );
  }
}
