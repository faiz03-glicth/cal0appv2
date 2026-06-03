import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/models/health/health_condition.dart';

/// Shows the health-warning dialog and returns true if the user
/// confirms they want to log the food anyway, false if they cancel.
///
/// Call this before any food log save:
/// ```dart
/// final proceed = await showHealthWarningDialog(context, warnings);
/// if (proceed) { /* save */ }
/// ```
Future<bool> showHealthWarningDialog(
  BuildContext context,
  List<HealthWarning> warnings,
) async {
  if (warnings.isEmpty) return true; // nothing to show
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false, // user must explicitly choose
    builder: (_) => HealthWarningSheet(warnings: warnings),
  );
  return result ?? false; // null means dismissed with back button → cancel
}

// ── Bottom sheet ───────────────────────────────────────────────────────────

class HealthWarningSheet extends StatelessWidget {
  final List<HealthWarning> warnings;

  const HealthWarningSheet({super.key, required this.warnings});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final hasHigh = warnings.any((w) => w.riskLevel == RiskLevel.high);
    final accentColor = hasHigh ? c.warning : C0Theme.riskModerate;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxl + 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ─────────────────────────────────────────────────
            Center(
              child: Container(
                width: AppSizes.sheetHandleW,
                height: AppSizes.sheetHandleH,
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Header ─────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasHigh ? Icons.health_and_safety : Icons.info_outline,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Health Notice',
                        style: AppTextStyles.title.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        'Based on your health profile',
                        style: AppTextStyles.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Warning cards ───────────────────────────────────────────
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: warnings
                      .map((w) => _WarningCard(warning: w))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Friendly note ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: AppSizes.smallIconSize,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'This is a gentle reminder, not medical advice. '
                      'Always consult your doctor or dietitian for guidance '
                      'specific to your health needs.',
                      style: AppTextStyles.micro.copyWith(
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Action buttons ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.divider),
                      foregroundColor: c.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md + 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Go Back',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasHigh
                          ? c.warning.withValues(alpha: 0.15)
                          : c.primary,
                      foregroundColor: hasHigh ? c.warning : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md + 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        side: hasHigh
                            ? BorderSide(
                                color: c.warning.withValues(alpha: 0.5),
                              )
                            : BorderSide.none,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check, size: AppSizes.smallIconSize),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Text(
                          'Log Anyway',
                          style: AppTextStyles.buttonMedium.copyWith(
                            color: hasHigh ? c.warning : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual warning card ────────────────────────────────────────────────

class _WarningCard extends StatefulWidget {
  final HealthWarning warning;
  const _WarningCard({required this.warning});

  @override
  State<_WarningCard> createState() => _WarningCardState();
}

class _WarningCardState extends State<_WarningCard> {
  bool _expanded = false;

  Color _accentColor(C0Colors c) {
    return widget.warning.riskLevel == RiskLevel.high
        ? c.warning
        : C0Theme.riskModerate;
  }

  IconData _conditionIcon() {
    switch (widget.warning.condition) {
      case HealthCondition.diabetes:
        return Icons.water_drop_outlined;
      case HealthCondition.hypertension:
        return Icons.favorite_outline;
      case HealthCondition.heartDisease:
        return Icons.monitor_heart_outlined;
      case HealthCondition.kidneyDisease:
        return Icons.biotech_outlined;
      case HealthCondition.highCholesterol:
        return Icons.bloodtype_outlined;
      case HealthCondition.obesity:
        return Icons.scale_outlined;
      case HealthCondition.celiacDisease:
        return Icons.no_food_outlined;
      case HealthCondition.lactoseIntolerance:
        return Icons.local_drink_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final accent = _accentColor(c);
    final isHigh = widget.warning.riskLevel == RiskLevel.high;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: accent.withValues(alpha: isHigh ? 0.5 : 0.3),
          width: isHigh ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Card header (always visible) ──────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Condition icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.sm + 2),
                    ),
                    child: Icon(
                      _conditionIcon(),
                      size: AppSizes.smallIconSize,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Headline + condition label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.warning.headline,
                          style: AppTextStyles.bodyCompact.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _RiskBadge(level: widget.warning.riskLevel),
                            const SizedBox(width: AppSpacing.xs + 2),
                            Text(
                              widget.warning.condition.shortLabel,
                              style: AppTextStyles.micro.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Expand chevron
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: c.textSecondary,
                    size: AppSizes.smallIconSize,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body ─────────────────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: accent.withValues(alpha: 0.25), height: 1),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    widget.warning.message,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textPrimary,
                      height: 1.55,
                    ),
                  ),
                  if (widget.warning.nutritionDetail != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs + 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        widget.warning.nutritionDetail!,
                        style: AppTextStyles.micro.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Risk badge ─────────────────────────────────────────────────────────────

class _RiskBadge extends StatelessWidget {
  final RiskLevel level;
  const _RiskBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final isHigh = level == RiskLevel.high;
    final color = isHigh ? c.warning : C0Theme.riskModerate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        isHigh ? '⚠ High Risk' : '! Moderate',
        style: AppTextStyles.micro.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
