import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/editable_ingredient_field.dart';
import 'package:cal0appv2/views/widgets/authenticity_verdict_card.dart';
import 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart';

class SupplementModeSection extends StatelessWidget {
  final bool isSupplementMode;
  final ValueChanged<bool> onToggle;

  final TextEditingController ingredientCtrl;
  final TextEditingController creatineCtrl;
  final TextEditingController bcaaCtrl;
  final TextEditingController leucineCtrl;
  final TextEditingController isoleucineCtrl;
  final TextEditingController valineCtrl;
  final TextEditingController glutamineCtrl;
  final TextEditingController taurineCtrl;

  final AuthenticityCheck? liveCheck;
  final ValueChanged<String>? onCreatineChanged;
  final ValueChanged<String>? onBcaaChanged;
  final ValueChanged<String>? onLeucineChanged;
  final ValueChanged<String>? onIsoleucineChanged;
  final ValueChanged<String>? onValineChanged;
  final ValueChanged<String>? onGlutamineChanged;
  final ValueChanged<String>? onTaurineChanged;

  const SupplementModeSection({
    super.key,
    required this.isSupplementMode,
    required this.onToggle,
    required this.ingredientCtrl,
    required this.creatineCtrl,
    required this.bcaaCtrl,
    required this.leucineCtrl,
    required this.isoleucineCtrl,
    required this.valineCtrl,
    required this.glutamineCtrl,
    required this.taurineCtrl,
    this.liveCheck,
    this.onCreatineChanged,
    this.onBcaaChanged,
    this.onLeucineChanged,
    this.onIsoleucineChanged,
    this.onValineChanged,
    this.onGlutamineChanged,
    this.onTaurineChanged,
  });

  Widget _row2(
    C0Colors c,
    TextEditingController c1,
    String l1,
    ValueChanged<String>? on1,
    TextEditingController c2,
    String l2,
    ValueChanged<String>? on2,
  ) {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            controller: c1,
            label: l1,
            hint: 'g',
            isNumber: true,
            onChanged: on1,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppTextField(
            controller: c2,
            label: l2,
            hint: 'g',
            isNumber: true,
            onChanged: on2,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Toggle row — always shown ──────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: isSupplementMode
                ? c.primary.withValues(alpha: 0.06)
                : c.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSupplementMode
                  ? c.primary.withValues(alpha: 0.3)
                  : c.divider,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.science_outlined,
                size: AppSizes.smallIconSize,
                color: isSupplementMode ? c.primary : c.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supplements',
                      style: AppTextStyles.bodyCompact.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSupplementMode ? c.primary : c.textPrimary,
                      ),
                    ),
                    Text(
                      isSupplementMode
                          ? 'Whey supplement — checking authenticity'
                          : 'Normal food logging — no authenticity check',
                      style: AppTextStyles.micro.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isSupplementMode,
                onChanged: onToggle,
                activeThumbColor: c.primary,
                activeTrackColor: c.track,
              ),
            ],
          ),
        ),

        // ── Everything below only renders when Supplements is ON ───────
        if (isSupplementMode) ...[
          const SizedBox(height: AppSpacing.md),
          AuthenticityVerdictCard(
            check: liveCheck,
            unavailableTitle: 'Add ingredients to check',
            unavailableReason:
                'Type or paste the ingredient list below to run the '
                'Authentic / Non-Authentic nitrogen-compound check.',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Ingredients',
            style: AppTextStyles.fieldLabel.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          EditableIngredientField(
            controller: ingredientCtrl,
            title: 'Ingredient List',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Supplement Compounds (optional)',
            style: AppTextStyles.fieldLabel.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row2(
            c,
            creatineCtrl,
            'Creatine Mono.',
            onCreatineChanged,
            bcaaCtrl,
            'Total BCAAs',
            onBcaaChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          _row2(
            c,
            leucineCtrl,
            'Leucine',
            onLeucineChanged,
            isoleucineCtrl,
            'Isoleucine',
            onIsoleucineChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          _row2(
            c,
            valineCtrl,
            'Valine',
            onValineChanged,
            glutamineCtrl,
            'Glutamine',
            onGlutamineChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: taurineCtrl,
            label: 'Taurine',
            hint: 'g',
            isNumber: true,
            onChanged: onTaurineChanged,
          ),
        ],
      ],
    );
  }
}
