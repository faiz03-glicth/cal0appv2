import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/viewModels/foodlog/food_history_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/app_bottom_sheet.dart';
import 'package:cal0appv2/views/widgets/macro_progress_bar.dart';
import 'package:cal0appv2/views/widgets/source_badge.dart';

class FoodDetailView extends StatefulWidget {
  final FoodLogModel log;
  const FoodDetailView({super.key, required this.log});

  @override
  State<FoodDetailView> createState() => _FoodDetailViewState();
}

class _FoodDetailViewState extends State<FoodDetailView> {
  late FoodLogModel _log;

  @override
  void initState() {
    super.initState();
    _log = widget.log;
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final isSpiked = _log.scanAnalysisResult?.contains('SPIKED') ?? false;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.header,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _log.foodLogName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit,
              color: Colors.white,
              size: AppSizes.fieldIconSize,
            ),
            onPressed: () => _openEdit(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scanned image
            if (_log.isScanned &&
                _log.imagePath != null &&
                _log.imagePath!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Image.file(
                  File(_log.imagePath!),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (_log.isScanned && _log.imagePath != null)
              const SizedBox(height: AppSpacing.lg),

            // Source + date card
            AppCard(
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Source',
                    value: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [SourceBadge(source: _log.source)],
                    ),
                  ),
                  _InfoRow(
                    label: 'Date',
                    value: Text(
                      DateFormat('d MMM yyyy, h:mm a').format(_log.loggedAt),
                      style: AppTextStyles.caption.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  if (_log.servingSize != null)
                    _InfoRow(
                      label: 'Serving',
                      value: Text(
                        '${_log.servingSize}${_log.servingUnit}',
                        style: AppTextStyles.caption.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  if (_log.isScanned && _log.scanConfidence != null)
                    _InfoRow(
                      label: 'OCR Confidence',
                      value: Text(
                        '${(_log.scanConfidence! * 100).toStringAsFixed(0)}%',
                        style: AppTextStyles.caption.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // AI result (scanned only)
            if (_log.isScanned && _log.scanAnalysisResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg - 2),
                decoration: BoxDecoration(
                  color: (isSpiked ? c.warning : c.success).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: (isSpiked ? c.warning : c.success).withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSpiked ? Icons.warning_rounded : Icons.shield,
                      color: isSpiked ? c.warning : c.success,
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Analysis',
                          style: AppTextStyles.tiny.copyWith(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _log.scanAnalysisResult!,
                          style: AppTextStyles.bodyCompact.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSpiked ? c.warning : c.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_log.isScanned) const SizedBox(height: AppSpacing.md),

            // Macros card
            Text(
              'NUTRITION',
              style: AppTextStyles.sectionTitle.copyWith(
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  MacroProgressBar(
                    label: 'Calories',
                    value: _log.calorieIntake.toDouble(),
                    max: 2000,
                    unit: 'kcal',
                    color: c.primary,
                  ),
                  MacroProgressBar(
                    label: 'Protein',
                    value: _log.protein,
                    max: 150,
                    color: c.success,
                  ),
                  MacroProgressBar(
                    label: 'Carbohydrates',
                    value: _log.carbs,
                    max: 250,
                    color: C0Theme.macroCarbs,
                  ),
                  MacroProgressBar(
                    label: 'Fat',
                    value: _log.fats,
                    max: 65,
                    color: c.slate,
                  ),
                  if (_log.sugar > 0)
                    MacroProgressBar(
                      label: 'Sugar',
                      value: _log.sugar,
                      max: 50,
                      color: C0Theme.macroSugar,
                    ),
                  if (_log.sodium > 0)
                    MacroProgressBar(
                      label: 'Sodium',
                      value: _log.sodium,
                      max: 2300,
                      unit: 'mg',
                      color: C0Theme.macroSodium,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEdit(BuildContext context) {
    final c = C0Theme.of(context);
    final nameCtrl = TextEditingController(text: _log.foodLogName);
    final calCtrl = TextEditingController(text: '${_log.calorieIntake}');
    final proCtrl = TextEditingController(text: '${_log.protein}');
    final carbCtrl = TextEditingController(text: '${_log.carbs}');
    final fatCtrl = TextEditingController(text: '${_log.fats}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppBottomSheet(
        title: 'Edit Entry',
        children: [
          AppTextField(controller: nameCtrl, hint: 'Name', icon: Icons.label),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: calCtrl,
            hint: 'Calories',
            icon: Icons.local_fire_department,
            isNumber: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: proCtrl,
                  hint: 'Protein g',
                  icon: Icons.fitness_center,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: carbCtrl,
                  hint: 'Carbs g',
                  icon: Icons.grain,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: fatCtrl,
                  hint: 'Fat g',
                  icon: Icons.water_drop,
                  isNumber: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Save Changes',
            onPressed: () async {
              final uid = context.read<AuthViewModel>().currentUid ?? '';
              _log.foodLogName = nameCtrl.text.trim();
              _log.calorieIntake =
                  int.tryParse(calCtrl.text) ?? _log.calorieIntake;
              _log.protein = double.tryParse(proCtrl.text) ?? _log.protein;
              _log.carbs = double.tryParse(carbCtrl.text) ?? _log.carbs;
              _log.fats = double.tryParse(fatCtrl.text) ?? _log.fats;
              await context.read<FoodHistoryViewModel>().update(uid, _log);
              setState(() {});
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: C0Theme.slateGrey),
          ),
          value,
        ],
      ),
    );
  }
}
