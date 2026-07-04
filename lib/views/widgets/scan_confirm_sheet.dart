import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/models/scan_result_model.dart';
import 'package:cal0appv2/viewModels/scan/scan_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/viewModels/health/health_warning_viewmodel.dart';
import 'package:cal0appv2/viewModels/mixins/authenticity_reanalysis_mixin.dart';
import 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/app_message_banner.dart';
import 'package:cal0appv2/views/widgets/app_bottom_sheet.dart';
import 'package:cal0appv2/views/widgets/health_warning_dialog.dart';
import 'package:cal0appv2/views/widgets/editable_ingredient_field.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';
import 'package:cal0appv2/views/widgets/whey_verdict_card.dart';

class ScanConfirmSheet extends StatefulWidget {
  final ScanResultModel initial;
  const ScanConfirmSheet({super.key, required this.initial});

  @override
  State<ScanConfirmSheet> createState() => _ScanConfirmSheetState();
}

class _ScanConfirmSheetState extends State<ScanConfirmSheet>
    with AuthenticityReanalysisMixin {
  // Core
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _serving;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  // Extended macros
  late final TextEditingController _sugar;
  late final TextEditingController _fiber;
  late final TextEditingController _saturatedFat;
  late final TextEditingController _transFat;
  late final TextEditingController _unsaturatedFat;
  late final TextEditingController _cholesterol;
  late final TextEditingController _sodium;
  late final TextEditingController _potassium;
  // Supplement compounds
  late final TextEditingController _creatine;
  late final TextEditingController _bcaa;
  late final TextEditingController _leucine;
  late final TextEditingController _isoleucine;
  late final TextEditingController _valine;
  late final TextEditingController _glutamine;
  late final TextEditingController _taurine;
  late final TextEditingController _caffeine;
  // Vitamins & minerals
  late final TextEditingController _vitaminC;
  late final TextEditingController _vitaminD;
  late final TextEditingController _calcium;
  late final TextEditingController _iron;
  late final TextEditingController _magnesium;
  late final TextEditingController _zinc;
  // Ingredients — the field that drives the Authentic / Non-Authentic check
  late final TextEditingController _ingredientText;

  bool _addToFoodLog = true;
  bool _showOptional = false;
  bool _filledFromVm = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _name = TextEditingController(text: r.productName);
    _brand = TextEditingController(text: r.brandName);
    _serving = TextEditingController(text: _fmt(r.servingSize));
    _calories = TextEditingController(text: _fmtI(r.calories));
    _protein = TextEditingController(text: _fmt(r.protein));
    _carbs = TextEditingController(text: _fmt(r.carbs));
    _fat = TextEditingController(text: _fmt(r.fat));
    _sugar = TextEditingController(text: _fmt(r.sugar));
    _fiber = TextEditingController(text: _fmt(r.fiber));
    _saturatedFat = TextEditingController(text: _fmt(r.saturatedFat));
    _transFat = TextEditingController(text: _fmt(r.transFat));
    _unsaturatedFat = TextEditingController(text: _fmt(r.unsaturatedFat));
    _cholesterol = TextEditingController(text: _fmt(r.cholesterol));
    _sodium = TextEditingController(text: _fmt(r.sodium));
    _potassium = TextEditingController(text: _fmt(r.potassium));
    _creatine = TextEditingController(text: _fmt(r.creatineMonohydrate));
    _bcaa = TextEditingController(text: _fmt(r.bcaa));
    _leucine = TextEditingController(text: _fmt(r.leucine));
    _isoleucine = TextEditingController(text: _fmt(r.isoleucine));
    _valine = TextEditingController(text: _fmt(r.valine));
    _glutamine = TextEditingController(text: _fmt(r.glutamine));
    _taurine = TextEditingController(text: _fmt(r.taurine));
    _caffeine = TextEditingController(text: _fmt(r.caffeine));
    _vitaminC = TextEditingController(text: _fmt(r.vitaminC));
    _vitaminD = TextEditingController(text: _fmt(r.vitaminD));
    _calcium = TextEditingController(text: _fmt(r.calcium));
    _iron = TextEditingController(text: _fmt(r.iron));
    _magnesium = TextEditingController(text: _fmt(r.magnesium));
    _zinc = TextEditingController(text: _fmt(r.zinc));
    _ingredientText = TextEditingController(text: r.ingredientText);

    // Every field on this sheet — nutrients, supplement compounds, and the
    // ingredient list itself — is watched by the shared mixin. Editing any
    // of them debounces then re-runs the Authentic / Non-Authentic check.
    // This is the single reusable behavior; it's not re-implemented here.
    watchFieldsForReanalysis([
      _calories,
      _protein,
      _carbs,
      _fat,
      _sugar,
      _fiber,
      _saturatedFat,
      _transFat,
      _unsaturatedFat,
      _cholesterol,
      _sodium,
      _potassium,
      _creatine,
      _bcaa,
      _leucine,
      _isoleucine,
      _valine,
      _glutamine,
      _taurine,
      _caffeine,
      _vitaminC,
      _vitaminD,
      _calcium,
      _iron,
      _magnesium,
      _zinc,
      _ingredientText,
    ]);

    // Run an initial check right away if we already have ingredient text,
    // so the card never sits on "Unknown" waiting for an edit.
    WidgetsBinding.instance.addPostFrameCallback((_) => runReanalysisNow());
  }

  // ── AuthenticityReanalysisMixin wiring ──────────────────────────────────

  @override
  String get ingredientTextForReanalysis => _ingredientText.text;

  @override
  void onAuthenticityChecked(AuthenticityCheck result) {
    if (!mounted) return;
    context.read<ScanViewModel>().updateIngredientsAndReanalyze(
      result.ingredientText,
    );
  }

  // ── Auto-fill from VM ─────────────────────────────────────────────────────

  void _tryFillFromVm(ScanViewModel vm) {
    if (_filledFromVm) return;
    final r = vm.extractedResult;
    if (r == null) return;
    _filledFromVm = true;

    void fill(TextEditingController c, String val) {
      if (val.isNotEmpty) c.text = val;
    }

    fill(_name, r.productName);
    fill(_brand, r.brandName);
    fill(_serving, _fmt(r.servingSize));
    fill(_calories, _fmtI(r.calories));
    fill(_protein, _fmt(r.protein));
    fill(_carbs, _fmt(r.carbs));
    fill(_fat, _fmt(r.fat));
    fill(_sugar, _fmt(r.sugar));
    fill(_fiber, _fmt(r.fiber));
    fill(_saturatedFat, _fmt(r.saturatedFat));
    fill(_transFat, _fmt(r.transFat));
    fill(_unsaturatedFat, _fmt(r.unsaturatedFat));
    fill(_cholesterol, _fmt(r.cholesterol));
    fill(_sodium, _fmt(r.sodium));
    fill(_potassium, _fmt(r.potassium));
    fill(_creatine, _fmt(r.creatineMonohydrate));
    fill(_bcaa, _fmt(r.bcaa));
    fill(_leucine, _fmt(r.leucine));
    fill(_isoleucine, _fmt(r.isoleucine));
    fill(_valine, _fmt(r.valine));
    fill(_glutamine, _fmt(r.glutamine));
    fill(_taurine, _fmt(r.taurine));
    fill(_caffeine, _fmt(r.caffeine));
    fill(_vitaminC, _fmt(r.vitaminC));
    fill(_vitaminD, _fmt(r.vitaminD));
    fill(_calcium, _fmt(r.calcium));
    fill(_iron, _fmt(r.iron));
    fill(_magnesium, _fmt(r.magnesium));
    fill(_zinc, _fmt(r.zinc));

    if (_ingredientText.text.trim().isEmpty && r.ingredientText.isNotEmpty) {
      _ingredientText.text = r.ingredientText;
    }

    // Auto-expand if optional fields were found
    if (r.filledOptionalFields > 0 && !_showOptional) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showOptional = true);
      });
    }

    // The OCR/Gemini result just arrived asynchronously — run the check
    // now if we haven't already got a result.
    WidgetsBinding.instance.addPostFrameCallback((_) => runReanalysisNow());
  }

  static String _fmt(num? v) {
    if (v == null || v == 0) return '';
    final d = v.toDouble();
    return d == d.truncateToDouble()
        ? d.toInt().toString()
        : d.toStringAsFixed(1);
  }

  static String _fmtI(int v) => v == 0 ? '' : '$v';

  // ── Build confirmed model ─────────────────────────────────────────────────

  ScanResultModel _buildConfirmed() => widget.initial.copyWith(
    productName: _name.text.trim(),
    brandName: _brand.text.trim(),
    ingredientText: _ingredientText.text.trim(),
    servingSize: double.tryParse(_serving.text),
    calories: int.tryParse(_calories.text) ?? widget.initial.calories,
    protein: double.tryParse(_protein.text) ?? widget.initial.protein,
    carbs: double.tryParse(_carbs.text) ?? widget.initial.carbs,
    fat: double.tryParse(_fat.text) ?? widget.initial.fat,
    sugar: double.tryParse(_sugar.text) ?? widget.initial.sugar,
    fiber: double.tryParse(_fiber.text) ?? widget.initial.fiber,
    saturatedFat:
        double.tryParse(_saturatedFat.text) ?? widget.initial.saturatedFat,
    transFat: double.tryParse(_transFat.text) ?? widget.initial.transFat,
    unsaturatedFat:
        double.tryParse(_unsaturatedFat.text) ?? widget.initial.unsaturatedFat,
    cholesterol:
        double.tryParse(_cholesterol.text) ?? widget.initial.cholesterol,
    sodium: double.tryParse(_sodium.text) ?? widget.initial.sodium,
    potassium: double.tryParse(_potassium.text) ?? widget.initial.potassium,
    creatineMonohydrate:
        double.tryParse(_creatine.text) ?? widget.initial.creatineMonohydrate,
    bcaa: double.tryParse(_bcaa.text) ?? widget.initial.bcaa,
    leucine: double.tryParse(_leucine.text) ?? widget.initial.leucine,
    isoleucine: double.tryParse(_isoleucine.text) ?? widget.initial.isoleucine,
    valine: double.tryParse(_valine.text) ?? widget.initial.valine,
    glutamine: double.tryParse(_glutamine.text) ?? widget.initial.glutamine,
    taurine: double.tryParse(_taurine.text) ?? widget.initial.taurine,
    caffeine: double.tryParse(_caffeine.text) ?? widget.initial.caffeine,
    vitaminC: double.tryParse(_vitaminC.text) ?? widget.initial.vitaminC,
    vitaminD: double.tryParse(_vitaminD.text) ?? widget.initial.vitaminD,
    calcium: double.tryParse(_calcium.text) ?? widget.initial.calcium,
    iron: double.tryParse(_iron.text) ?? widget.initial.iron,
    magnesium: double.tryParse(_magnesium.text) ?? widget.initial.magnesium,
    zinc: double.tryParse(_zinc.text) ?? widget.initial.zinc,
  );

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save(BuildContext ctx, ScanViewModel vm) async {
    final uid = ctx.read<AuthViewModel>().currentUid ?? '';
    if (uid.isEmpty) return;
    final foodLogVm = ctx.read<FoodLogViewModel>();
    final confirmed = _buildConfirmed();

    final healthVm = ctx.read<HealthWarningViewModel>();
    final warnings = healthVm.analyzeValues(
      foodName: confirmed.productName.isNotEmpty
          ? confirmed.productName
          : 'Scanned Product',
      calories: confirmed.calories,
      protein: confirmed.protein,
      carbs: confirmed.carbs,
      fat: confirmed.fat,
      sugar: confirmed.sugar,
      sodium: confirmed.sodium,
    );

    if (warnings.isNotEmpty && ctx.mounted) {
      final proceed = await showHealthWarningDialog(ctx, warnings);
      if (!proceed || !ctx.mounted) return;
    }

    final ok = await vm.saveScanResult(
      uid: uid,
      confirmed: confirmed,
      brandName: _brand.text.trim(),
      targetDate: foodLogVm.selectedDate,
    );
    if (ok && ctx.mounted) {
      await foodLogVm.loadFoodLogs(uid: uid);
      Navigator.pop(ctx);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<ScanViewModel>(
      builder: (context, vm, _) {
        _tryFillFromVm(vm);

        final c = C0Theme.of(context);
        final healthVm = context.watch<HealthWarningViewModel>();
        final conf = vm.ocrConfidence > 0.0
            ? vm.ocrConfidence
            : widget.initial.extractionConfidence;

        return AppBottomSheet(
          subtitle: _SheetHeader(confidence: conf),
          children: [
            // Verdict card — always first
            WheyVerdictCard(vm: vm),
            const SizedBox(height: AppSpacing.md),

            if (vm.detectedIngredients.isNotEmpty) ...[
              _FlaggedIngredientsPanel(ingredients: vm.detectedIngredients),
              const SizedBox(height: AppSpacing.md),
            ],

            if (vm.lowOcrQuality || conf < 0.40) ...[
              _QualityWarning(isLowQuality: vm.lowOcrQuality, confidence: conf),
              const SizedBox(height: AppSpacing.md),
            ],

            if (_ingredientText.text.isNotEmpty ||
                vm.ingredientManuallyEdited) ...[
              // The one shared editable-ingredient component, used the
              // same way in food history's edit sheet.
              EditableIngredientField(controller: _ingredientText),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── CORE FIELDS ───────────────────────────────────────
            _SectionLabel('Product'),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              controller: _name,
              label: 'Product Name',
              hint: 'e.g. Gold Standard Whey',
              icon: Icons.label_outline,
              kt: TextInputType.text,
            ),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              controller: _brand,
              label: 'Brand Name',
              hint: 'e.g. Optimum Nutrition',
              icon: Icons.storefront_outlined,
              kt: TextInputType.text,
            ),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              controller: _serving,
              label: 'Serving Size',
              hint: '0',
              icon: Icons.straighten,
              unit: 'g',
            ),
            const SizedBox(height: AppSpacing.md),

            _SectionLabel('Core Macros'),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _calories,
                    label: 'Calories',
                    hint: '0',
                    icon: Icons.local_fire_department_outlined,
                    unit: 'kcal',
                    accent: const Color(0xFFFF6B35),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Field(
                    controller: _protein,
                    label: 'Protein',
                    hint: '0',
                    icon: Icons.fitness_center,
                    unit: 'g',
                    accent: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _carbs,
                    label: 'Carbs',
                    hint: '0',
                    icon: Icons.grain,
                    unit: 'g',
                    accent: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Field(
                    controller: _fat,
                    label: 'Fat',
                    hint: '0',
                    icon: Icons.water_drop_outlined,
                    unit: 'g',
                    accent: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),

            // ── OPTIONAL TOGGLE ───────────────────────────────────
            const SizedBox(height: AppSpacing.md),
            _OptionalToggle(
              expanded: _showOptional,
              filledCount: vm.extractedResult?.filledOptionalFields ?? 0,
              onToggle: () => setState(() => _showOptional = !_showOptional),
            ),

            if (_showOptional) ...[
              const SizedBox(height: AppSpacing.md),

              _SectionLabel('Extended Macros'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _sugar,
                      label: 'Sugar',
                      hint: '0',
                      icon: Icons.cookie_outlined,
                      unit: 'g',
                      accent: const Color(0xFFEC4899),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Field(
                      controller: _fiber,
                      label: 'Fiber',
                      hint: '0',
                      icon: Icons.grass,
                      unit: 'g',
                      accent: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _saturatedFat,
                      label: 'Saturated Fat',
                      hint: '0',
                      icon: Icons.opacity,
                      unit: 'g',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Field(
                      controller: _transFat,
                      label: 'Trans Fat',
                      hint: '0',
                      icon: Icons.block,
                      unit: 'g',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _unsaturatedFat,
                      label: 'Unsaturated Fat',
                      hint: '0',
                      icon: Icons.eco_outlined,
                      unit: 'g',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Field(
                      controller: _cholesterol,
                      label: 'Cholesterol',
                      hint: '0',
                      icon: Icons.bloodtype_outlined,
                      unit: 'mg',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _sodium,
                      label: 'Sodium',
                      hint: '0',
                      icon: Icons.water_outlined,
                      unit: 'mg',
                      accent: const Color(0xFF06B6D4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Field(
                      controller: _potassium,
                      label: 'Potassium',
                      hint: '0',
                      icon: Icons.bolt_outlined,
                      unit: 'mg',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),
              _SectionLabel('Supplement Compounds'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _creatine,
                      label: 'Creatine Mono.',
                      hint: '0',
                      icon: Icons.science_outlined,
                      unit: 'g',
                      accent: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Field(
                      controller: _bcaa,
                      label: 'Total BCAAs',
                      hint: '0',
                      icon: Icons.fitness_center,
                      unit: 'g',
                      accent: const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _leucine,
                      label: 'Leucine',
                      hint: '0',
                      icon: Icons.arrow_right_alt,
                      unit: 'g',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Field(
                      controller: _isoleucine,
                      label: 'Isoleucine',
                      hint: '0',
                      icon: Icons.arrow_right_alt,
                      unit: 'g',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _valine,
                      label: 'Valine',
                      hint: '0',
                      icon: Icons.arrow_right_alt,
                      unit: 'g',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Field(
                      controller: _glutamine,
                      label: 'Glutamine',
                      hint: '0',
                      icon: Icons.arrow_right_alt,
                      unit: 'g',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _taurine,
                      label: 'Taurine',
                      hint: '0',
                      icon: Icons.arrow_right_alt,
                      unit: 'g',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Field(
                      controller: _caffeine,
                      label: 'Caffeine',
                      hint: '0',
                      icon: Icons.coffee_outlined,
                      unit: 'mg',
                      accent: const Color(0xFF78716C),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),
              _SectionLabel('Vitamins & Minerals'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _vitaminC,
                      label: 'Vitamin C',
                      hint: '0',
                      icon: Icons.local_florist,
                      unit: 'mg',
                      accent: const Color(0xFFF97316),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Field(
                      controller: _vitaminD,
                      label: 'Vitamin D',
                      hint: '0',
                      icon: Icons.wb_sunny_outlined,
                      unit: 'µg',
                      accent: const Color(0xFFEAB308),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _calcium,
                      label: 'Calcium',
                      hint: '0',
                      icon: Icons.circle_outlined,
                      unit: 'mg',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Field(
                      controller: _iron,
                      label: 'Iron',
                      hint: '0',
                      icon: Icons.circle_outlined,
                      unit: 'mg',
                      accent: const Color(0xFFF87171),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _magnesium,
                      label: 'Magnesium',
                      hint: '0',
                      icon: Icons.circle_outlined,
                      unit: 'mg',
                      accent: const Color(0xFF34D399),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Field(
                      controller: _zinc,
                      label: 'Zinc',
                      hint: '0',
                      icon: Icons.circle_outlined,
                      unit: 'mg',
                      accent: const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            _DiaryToggle(
              value: _addToFoodLog,
              onChanged: (v) => setState(() => _addToFoodLog = v),
            ),

            if (healthVm.hasConditions) ...[
              const SizedBox(height: AppSpacing.sm),
              _HealthBadge(),
            ],

            const SizedBox(height: AppSpacing.lg),

            if (vm.errorMessage != null) ...[
              AppMessageBanner.error(message: vm.errorMessage!),
              const SizedBox(height: AppSpacing.sm),
            ],

            AppPrimaryButton(
              label: vm.isSaving ? 'Saving...' : 'Save to Diary',
              isLoading: vm.isSaving,
              icon: Icons.save_outlined,
              onPressed: () => _save(context, vm),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    disposeAuthenticityReanalysis();
    for (final c in [
      _name,
      _brand,
      _serving,
      _calories,
      _protein,
      _carbs,
      _fat,
      _sugar,
      _fiber,
      _saturatedFat,
      _transFat,
      _unsaturatedFat,
      _cholesterol,
      _sodium,
      _potassium,
      _creatine,
      _bcaa,
      _leucine,
      _isoleucine,
      _valine,
      _glutamine,
      _taurine,
      _caffeine,
      _vitaminC,
      _vitaminD,
      _calcium,
      _iron,
      _magnesium,
      _zinc,
      _ingredientText,
    ]) {
      c.dispose();
    }
    super.dispose();
  }
}

// ── Optional section toggle ────────────────────────────────────────────────

class _OptionalToggle extends StatelessWidget {
  final bool expanded;
  final int filledCount;
  final VoidCallback onToggle;
  const _OptionalToggle({
    required this.expanded,
    required this.filledCount,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.divider),
        ),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: c.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expanded ? 'Hide optional fields' : 'Show more nutrients',
                    style: AppTextStyles.bodyCompact.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Sugar, fiber, creatine, BCAAs, vitamins, minerals (+24 fields)',
                    style: AppTextStyles.micro.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            if (filledCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$filledCount filled',
                  style: AppTextStyles.micro.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final double confidence;
  const _SheetHeader({required this.confidence});
  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final col = confidence >= 0.65
        ? c.success
        : confidence >= 0.40
        ? Colors.orange
        : c.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.document_scanner_outlined, color: c.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Scan Results',
                style: AppTextStyles.title.copyWith(color: c.textPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'OCR ${(confidence * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.micro.copyWith(
                  color: col,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Fields pre-filled from scan — tap any to correct',
          style: AppTextStyles.caption.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: c.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? unit;
  final Color? accent;
  final TextInputType kt;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.unit,
    this.accent,
    this.kt = TextInputType.number,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: TextField(
        controller: controller,
        keyboardType: kt == TextInputType.number
            ? const TextInputType.numberWithOptions(decimal: true)
            : kt,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: c.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.4)),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 10, right: 6),
            child: Icon(
              icon,
              size: 16,
              color: accent ?? c.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          suffixIcon: unit != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    unit!,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 36),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
          isDense: true,
        ),
      ),
    );
  }
}

class _FlaggedIngredientsPanel extends StatefulWidget {
  final List<DetectedIngredient> ingredients;
  const _FlaggedIngredientsPanel({required this.ingredients});
  @override
  State<_FlaggedIngredientsPanel> createState() =>
      _FlaggedIngredientsPanelState();
}

class _FlaggedIngredientsPanelState extends State<_FlaggedIngredientsPanel> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final hasAmSpiking = widget.ingredients.any((i) => i.isAmSpiking);
    final hColor = hasAmSpiking ? c.warning : Colors.orange;
    return Container(
      decoration: BoxDecoration(
        color: hColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: hColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    hasAmSpiking ? Icons.warning_rounded : Icons.info_outline,
                    color: hColor,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasAmSpiking
                              ? 'Suspicious Ingredients Detected'
                              : 'Notable Ingredients Found',
                          style: AppTextStyles.bodyCompact.copyWith(
                            fontWeight: FontWeight.w700,
                            color: hColor,
                          ),
                        ),
                        Text(
                          '${widget.ingredients.length} flagged — tap to expand',
                          style: AppTextStyles.micro.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: c.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: widget.ingredients
                    .map((i) => _IngredientCard(ingredient: i))
                    .toList(),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _IngredientCard extends StatefulWidget {
  final DetectedIngredient ingredient;
  const _IngredientCard({required this.ingredient});
  @override
  State<_IngredientCard> createState() => _IngredientCardState();
}

class _IngredientCardState extends State<_IngredientCard> {
  bool _show = false;
  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final ing = widget.ingredient;
    final bColor = ing.isAmSpiking ? c.warning : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _show = !_show),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: bColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      ing.isAmSpiking
                          ? '⚠ Spiking Agent'
                          : ing.category.split('/').first.trim(),
                      style: AppTextStyles.micro.copyWith(
                        color: bColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      ing.name,
                      style: AppTextStyles.bodyCompact.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _show ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: c.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 160),
            crossFadeState: _show
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm + 2,
                0,
                AppSpacing.sm + 2,
                AppSpacing.sm + 2,
              ),
              child: Text(
                ing.explanation,
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _QualityWarning extends StatelessWidget {
  final bool isLowQuality;
  final double confidence;
  const _QualityWarning({required this.isLowQuality, required this.confidence});
  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 15),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isLowQuality
                      ? 'Image quality too low for reliable scanning'
                      : 'Partial extraction (${(confidence * 100).toStringAsFixed(0)}%)',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tips: good lighting · hold steady · keep label flat · avoid glare.',
            style: AppTextStyles.micro.copyWith(
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _DiaryToggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Container(
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
          Icon(
            Icons.book_outlined,
            size: AppSizes.smallIconSize,
            color: c.primary,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              "Add to today's food diary",
              style: AppTextStyles.bodyCompact.copyWith(color: c.textPrimary),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: c.primary,
            activeTrackColor: c.track,
          ),
        ],
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Container(
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
    );
  }
}