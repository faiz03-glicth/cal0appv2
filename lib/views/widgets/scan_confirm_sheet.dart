import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/scan_result_model.dart';
import 'package:cal0appv2/viewModels/scan/scan_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/viewModels/health/health_warning_viewmodel.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/app_message_banner.dart';
import 'package:cal0appv2/views/widgets/app_bottom_sheet.dart';
import 'package:cal0appv2/views/widgets/health_warning_dialog.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';

class ScanConfirmSheet extends StatefulWidget {
  final ScanResultModel initial;
  const ScanConfirmSheet({super.key, required this.initial});

  @override
  State<ScanConfirmSheet> createState() => _ScanConfirmSheetState();
}

class _ScanConfirmSheetState extends State<ScanConfirmSheet> {
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _serving;
  bool _addToFoodLog = true;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _name = TextEditingController(text: r.productName);
    _calories = TextEditingController(
      text: r.calories > 0 ? '${r.calories}' : '',
    );
    _protein = TextEditingController(text: r.protein > 0 ? '${r.protein}' : '');
    _carbs = TextEditingController(text: r.carbs > 0 ? '${r.carbs}' : '');
    _fat = TextEditingController(text: r.fat > 0 ? '${r.fat}' : '');
    _serving = TextEditingController(
      text: r.servingSize != null ? '${r.servingSize}' : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _serving.dispose();
    super.dispose();
  }

  Color _confidenceColor(double conf, C0Colors c) {
    if (conf >= 0.7) return c.success;
    if (conf >= 0.4) return Colors.orange;
    return c.warning;
  }

  Future<void> _save(BuildContext context, ScanViewModel vm) async {
    final uid = context.read<AuthViewModel>().currentUid ?? '';
    if (uid.isEmpty) return;

    final foodLogVm = context.read<FoodLogViewModel>();
    final targetDate = foodLogVm.selectedDate;

    final confirmed = widget.initial.copyWith(
      productName: _name.text.trim(),
      calories: int.tryParse(_calories.text) ?? widget.initial.calories,
      protein: double.tryParse(_protein.text) ?? widget.initial.protein,
      carbs: double.tryParse(_carbs.text) ?? widget.initial.carbs,
      fat: double.tryParse(_fat.text) ?? widget.initial.fat,
      servingSize: double.tryParse(_serving.text),
    );

    // Health warning check
    final healthVm = context.read<HealthWarningViewModel>();
    final warnings = healthVm.analyzeValues(
      foodName: confirmed.productName.isNotEmpty
          ? confirmed.productName
          : 'Scanned Product',
      calories: confirmed.calories,
      protein: confirmed.protein,
      carbs: confirmed.carbs,
      fat: confirmed.fat,
      sugar: widget.initial.sugar,
      sodium: widget.initial.sodium,
    );

    if (warnings.isNotEmpty && context.mounted) {
      final proceed = await showHealthWarningDialog(context, warnings);
      if (!proceed || !context.mounted) return;
    }

    final ok = await vm.saveScanResult(
      uid: uid,
      confirmed: confirmed,
      targetDate: targetDate, // ← ADD
    );
    if (ok && context.mounted) {
      await foodLogVm.loadFoodLogs(uid: uid); // ← Reload diary
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = context.watch<ScanViewModel>();
    final healthVm = context.watch<HealthWarningViewModel>();
    final confColor = _confidenceColor(widget.initial.extractionConfidence, c);

    return AppBottomSheet(
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_scanner, color: c.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Confirm Scan Results',
                  style: AppTextStyles.title.copyWith(color: c.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: confColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '${(widget.initial.extractionConfidence * 100).toStringAsFixed(0)}% match',
                  style: AppTextStyles.micro.copyWith(
                    color: confColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Review and edit before saving.',
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ),
      children: [
        AppTextField(
          controller: _name,
          hint: 'Product / Supplement Name',
          icon: Icons.label,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _serving,
          hint: 'Serving Size (g)',
          icon: Icons.straighten,
          isNumber: true,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Macros per serving',
          style: AppTextStyles.fieldLabel.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _calories,
                hint: 'Calories',
                icon: Icons.local_fire_department,
                isNumber: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppTextField(
                controller: _protein,
                hint: 'Protein (g)',
                icon: Icons.fitness_center,
                isNumber: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _carbs,
                hint: 'Carbs (g)',
                icon: Icons.grain,
                isNumber: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppTextField(
                controller: _fat,
                hint: 'Fat (g)',
                icon: Icons.water_drop,
                isNumber: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Food diary toggle
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.divider),
          ),
          child: Row(
            children: [
              Icon(Icons.book, size: AppSizes.smallIconSize, color: c.primary),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  "Add to today's food diary",
                  style: AppTextStyles.bodyCompact.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: _addToFoodLog,
                onChanged: (v) => setState(() => _addToFoodLog = v),
                activeThumbColor: c.primary, // fixed: was activeColor
                activeTrackColor: c.track,
              ),
            ],
          ),
        ),

        // Health conditions badge
        if (healthVm.hasConditions) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: c.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: AppSizes.miniIconSize,
                  color: c.primary,
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Text(
                  'Health check will run on save',
                  style: AppTextStyles.micro.copyWith(color: c.primary),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),

        if (vm.errorMessage != null) ...[
          AppMessageBanner.error(message: vm.errorMessage!),
          const SizedBox(height: AppSpacing.sm + 2),
        ],

        AppPrimaryButton(
          label: vm.isSaving ? 'Saving...' : 'Save Result',
          isLoading: vm.isSaving,
          icon: Icons.save,
          onPressed: () => _save(context, vm),
        ),
      ],
    );
  }
}
