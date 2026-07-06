import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
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
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
                  if (_log.fiber > 0)
                    MacroProgressBar(
                      label: 'Fiber',
                      value: _log.fiber,
                      max: 30,
                      color: C0Theme.macroCarbs,
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

            // Extended nutrition (only shown if any value present, so a
            // manual entry with just the basics doesn't show an empty card)
            if (_hasExtendedData) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'EXTENDED NUTRITION',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    if (_log.saturatedFat > 0)
                      _InfoRow(
                        label: 'Saturated Fat',
                        value: Text('${_log.saturatedFat.toStringAsFixed(1)}g'),
                      ),
                    if (_log.transFat > 0)
                      _InfoRow(
                        label: 'Trans Fat',
                        value: Text('${_log.transFat.toStringAsFixed(1)}g'),
                      ),
                    if (_log.cholesterol > 0)
                      _InfoRow(
                        label: 'Cholesterol',
                        value: Text('${_log.cholesterol.toStringAsFixed(0)}mg'),
                      ),
                    if (_log.potassium > 0)
                      _InfoRow(
                        label: 'Potassium',
                        value: Text('${_log.potassium.toStringAsFixed(0)}mg'),
                      ),
                    if (_log.calcium > 0)
                      _InfoRow(
                        label: 'Calcium',
                        value: Text('${_log.calcium.toStringAsFixed(0)}mg'),
                      ),
                    if (_log.iron > 0)
                      _InfoRow(
                        label: 'Iron',
                        value: Text('${_log.iron.toStringAsFixed(1)}mg'),
                      ),
                    if (_log.magnesium > 0)
                      _InfoRow(
                        label: 'Magnesium',
                        value: Text('${_log.magnesium.toStringAsFixed(0)}mg'),
                      ),
                    if (_log.zinc > 0)
                      _InfoRow(
                        label: 'Zinc',
                        value: Text('${_log.zinc.toStringAsFixed(1)}mg'),
                      ),
                    if (_log.vitaminC > 0)
                      _InfoRow(
                        label: 'Vitamin C',
                        value: Text('${_log.vitaminC.toStringAsFixed(0)}mg'),
                      ),
                    if (_log.vitaminD > 0)
                      _InfoRow(
                        label: 'Vitamin D',
                        value: Text('${_log.vitaminD.toStringAsFixed(1)}µg'),
                      ),
                    if (_log.caffeine > 0)
                      _InfoRow(
                        label: 'Caffeine',
                        value: Text('${_log.caffeine.toStringAsFixed(0)}mg'),
                      ),
                  ],
                ),
              ),
            ],

            // Supplement compounds (whey/creatine-style products)
            if (_hasSupplementData) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'SUPPLEMENT COMPOUNDS',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    if (_log.creatineMonohydrate > 0)
                      _InfoRow(
                        label: 'Creatine Monohydrate',
                        value: Text(
                          '${_log.creatineMonohydrate.toStringAsFixed(1)}g',
                        ),
                      ),
                    if (_log.bcaa > 0)
                      _InfoRow(
                        label: 'BCAA',
                        value: Text('${_log.bcaa.toStringAsFixed(1)}g'),
                      ),
                    if (_log.leucine > 0)
                      _InfoRow(
                        label: 'Leucine',
                        value: Text('${_log.leucine.toStringAsFixed(1)}g'),
                      ),
                    if (_log.isoleucine > 0)
                      _InfoRow(
                        label: 'Isoleucine',
                        value: Text('${_log.isoleucine.toStringAsFixed(1)}g'),
                      ),
                    if (_log.valine > 0)
                      _InfoRow(
                        label: 'Valine',
                        value: Text('${_log.valine.toStringAsFixed(1)}g'),
                      ),
                    if (_log.glutamine > 0)
                      _InfoRow(
                        label: 'Glutamine',
                        value: Text('${_log.glutamine.toStringAsFixed(1)}g'),
                      ),
                    if (_log.taurine > 0)
                      _InfoRow(
                        label: 'Taurine',
                        value: Text('${_log.taurine.toStringAsFixed(1)}g'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasExtendedData =>
      _log.saturatedFat > 0 ||
      _log.transFat > 0 ||
      _log.cholesterol > 0 ||
      _log.potassium > 0 ||
      _log.calcium > 0 ||
      _log.iron > 0 ||
      _log.magnesium > 0 ||
      _log.zinc > 0 ||
      _log.vitaminC > 0 ||
      _log.vitaminD > 0 ||
      _log.caffeine > 0;

  bool get _hasSupplementData =>
      _log.creatineMonohydrate > 0 ||
      _log.bcaa > 0 ||
      _log.leucine > 0 ||
      _log.isoleucine > 0 ||
      _log.valine > 0 ||
      _log.glutamine > 0 ||
      _log.taurine > 0;

  // ── Edit sheet ──────────────────────────────────────────────────────────
  //
  // FIX: previously this only exposed 5 fields (Name, Calories, Protein,
  // Carbs, Fat) even though FoodLogModel stores 30+ nutrition fields.
  // Now organised into the same sections shown in the detail view above,
  // so anything the scan pipeline (or a manual entry) fills in can
  // actually be reviewed and corrected here.

  void _openEdit(BuildContext context) {
    final c = C0Theme.of(context);

    // Core
    final nameCtrl = TextEditingController(text: _log.foodLogName);
    final calCtrl = TextEditingController(text: '${_log.calorieIntake}');
    final proCtrl = TextEditingController(text: '${_log.protein}');
    final carbCtrl = TextEditingController(text: '${_log.carbs}');
    final fatCtrl = TextEditingController(text: '${_log.fats}');
    final fiberCtrl = TextEditingController(text: '${_log.fiber}');
    final sugarCtrl = TextEditingController(text: '${_log.sugar}');
    final sodiumCtrl = TextEditingController(text: '${_log.sodium}');

    // Extended
    final satFatCtrl = TextEditingController(text: '${_log.saturatedFat}');
    final transFatCtrl = TextEditingController(text: '${_log.transFat}');
    final cholCtrl = TextEditingController(text: '${_log.cholesterol}');
    final potassiumCtrl = TextEditingController(text: '${_log.potassium}');
    final calciumCtrl = TextEditingController(text: '${_log.calcium}');
    final ironCtrl = TextEditingController(text: '${_log.iron}');
    final magnesiumCtrl = TextEditingController(text: '${_log.magnesium}');
    final zincCtrl = TextEditingController(text: '${_log.zinc}');
    final vitCCtrl = TextEditingController(text: '${_log.vitaminC}');
    final vitDCtrl = TextEditingController(text: '${_log.vitaminD}');
    final caffeineCtrl = TextEditingController(text: '${_log.caffeine}');

    // Supplement compounds
    final creatineCtrl = TextEditingController(
      text: '${_log.creatineMonohydrate}',
    );
    final bcaaCtrl = TextEditingController(text: '${_log.bcaa}');
    final leucineCtrl = TextEditingController(text: '${_log.leucine}');
    final isoleucineCtrl = TextEditingController(text: '${_log.isoleucine}');
    final valineCtrl = TextEditingController(text: '${_log.valine}');
    final glutamineCtrl = TextEditingController(text: '${_log.glutamine}');
    final taurineCtrl = TextEditingController(text: '${_log.taurine}');

    double parse(TextEditingController ctrl, double fallback) =>
        double.tryParse(ctrl.text) ?? fallback;

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
          const SizedBox(height: AppSpacing.md),

          Text(
            'MACROS',
            style: AppTextStyles.sectionTitle.copyWith(color: c.textSecondary),
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: fiberCtrl,
                  hint: 'Fiber g',
                  icon: Icons.eco,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: sugarCtrl,
                  hint: 'Sugar g',
                  icon: Icons.icecream,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: sodiumCtrl,
                  hint: 'Sodium mg',
                  icon: Icons.grain,
                  isNumber: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          Text(
            'EXTENDED NUTRITION',
            style: AppTextStyles.sectionTitle.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: satFatCtrl,
                  hint: 'Sat. Fat g',
                  icon: Icons.opacity,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: transFatCtrl,
                  hint: 'Trans Fat g',
                  icon: Icons.opacity,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: cholCtrl,
                  hint: 'Cholesterol mg',
                  icon: Icons.opacity,
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
                  controller: potassiumCtrl,
                  hint: 'Potassium mg',
                  icon: Icons.bolt,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: calciumCtrl,
                  hint: 'Calcium mg',
                  icon: Icons.bolt,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: ironCtrl,
                  hint: 'Iron mg',
                  icon: Icons.bolt,
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
                  controller: magnesiumCtrl,
                  hint: 'Magnesium mg',
                  icon: Icons.bolt,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: zincCtrl,
                  hint: 'Zinc mg',
                  icon: Icons.bolt,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: caffeineCtrl,
                  hint: 'Caffeine mg',
                  icon: Icons.coffee,
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
                  controller: vitCCtrl,
                  hint: 'Vitamin C mg',
                  icon: Icons.local_florist,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: vitDCtrl,
                  hint: 'Vitamin D µg',
                  icon: Icons.local_florist,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          Text(
            'SUPPLEMENT COMPOUNDS',
            style: AppTextStyles.sectionTitle.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: creatineCtrl,
                  hint: 'Creatine g',
                  icon: Icons.science_outlined,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: bcaaCtrl,
                  hint: 'BCAA g',
                  icon: Icons.science_outlined,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: taurineCtrl,
                  hint: 'Taurine g',
                  icon: Icons.science_outlined,
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
                  controller: leucineCtrl,
                  hint: 'Leucine g',
                  icon: Icons.science_outlined,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: isoleucineCtrl,
                  hint: 'Isoleucine g',
                  icon: Icons.science_outlined,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  controller: valineCtrl,
                  hint: 'Valine g',
                  icon: Icons.science_outlined,
                  isNumber: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: glutamineCtrl,
            hint: 'Glutamine g',
            icon: Icons.science_outlined,
            isNumber: true,
          ),

          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Save Changes',
            onPressed: () async {
              final uid = context.read<AuthViewModel>().currentUid ?? '';
              _log.foodLogName = nameCtrl.text.trim();
              _log.calorieIntake =
                  int.tryParse(calCtrl.text) ?? _log.calorieIntake;
              _log.protein = parse(proCtrl, _log.protein);
              _log.carbs = parse(carbCtrl, _log.carbs);
              _log.fats = parse(fatCtrl, _log.fats);
              _log.fiber = parse(fiberCtrl, _log.fiber);
              _log.sugar = parse(sugarCtrl, _log.sugar);
              _log.sodium = parse(sodiumCtrl, _log.sodium);
              _log.saturatedFat = parse(satFatCtrl, _log.saturatedFat);
              _log.transFat = parse(transFatCtrl, _log.transFat);
              _log.cholesterol = parse(cholCtrl, _log.cholesterol);
              _log.potassium = parse(potassiumCtrl, _log.potassium);
              _log.calcium = parse(calciumCtrl, _log.calcium);
              _log.iron = parse(ironCtrl, _log.iron);
              _log.magnesium = parse(magnesiumCtrl, _log.magnesium);
              _log.zinc = parse(zincCtrl, _log.zinc);
              _log.vitaminC = parse(vitCCtrl, _log.vitaminC);
              _log.vitaminD = parse(vitDCtrl, _log.vitaminD);
              _log.caffeine = parse(caffeineCtrl, _log.caffeine);
              _log.creatineMonohydrate = parse(
                creatineCtrl,
                _log.creatineMonohydrate,
              );
              _log.bcaa = parse(bcaaCtrl, _log.bcaa);
              _log.leucine = parse(leucineCtrl, _log.leucine);
              _log.isoleucine = parse(isoleucineCtrl, _log.isoleucine);
              _log.valine = parse(valineCtrl, _log.valine);
              _log.glutamine = parse(glutamineCtrl, _log.glutamine);
              _log.taurine = parse(taurineCtrl, _log.taurine);

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
