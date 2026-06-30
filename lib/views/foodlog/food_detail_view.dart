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

            // Nutrition section
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(
        log: _log,
        onSaved: (updated) async {
          final uid = context.read<AuthViewModel>().currentUid ?? '';
          await context.read<FoodHistoryViewModel>().update(uid, updated);
          setState(() => _log = updated);
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Edit sheet — stateful, owns all controllers
// ══════════════════════════════════════════════════════════════════════════════

class _EditSheet extends StatefulWidget {
  final FoodLogModel log;
  final Future<void> Function(FoodLogModel updated) onSaved;

  const _EditSheet({required this.log, required this.onSaved});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  // ── Required ───────────────────────────────────────────────────────────
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fats;
  late final TextEditingController _sodium;

  // ── Extended macros ────────────────────────────────────────────────────
  late final TextEditingController _fiber;
  late final TextEditingController _sugar;
  late final TextEditingController _addedSugar;
  late final TextEditingController _saturatedFat;
  late final TextEditingController _transFat;
  late final TextEditingController _unsaturatedFat;
  late final TextEditingController _omega3;
  late final TextEditingController _omega6;
  late final TextEditingController _cholesterol;

  // ── Minerals ───────────────────────────────────────────────────────────
  late final TextEditingController _potassium;
  late final TextEditingController _calcium;
  late final TextEditingController _iron;
  late final TextEditingController _magnesium;
  late final TextEditingController _zinc;
  late final TextEditingController _phosphorus;
  late final TextEditingController _selenium;

  // ── Vitamins ───────────────────────────────────────────────────────────
  late final TextEditingController _vitaminA;
  late final TextEditingController _vitaminB1;
  late final TextEditingController _vitaminB2;
  late final TextEditingController _vitaminB3;
  late final TextEditingController _vitaminB6;
  late final TextEditingController _vitaminB12;
  late final TextEditingController _vitaminC;
  late final TextEditingController _vitaminD;
  late final TextEditingController _vitaminE;
  late final TextEditingController _vitaminK;
  late final TextEditingController _folate;

  // ── Other ──────────────────────────────────────────────────────────────
  late final TextEditingController _waterMl;
  late final TextEditingController _caffeine;
  late final TextEditingController _servingSize;

  bool _isSaving = false;
  bool _showExtendedMacros = false;
  bool _showMinerals = false;
  bool _showVitamins = false;
  bool _showOther = false;

  // Show 0 as empty so the placeholder hint is visible
  TextEditingController _c(double v) =>
      TextEditingController(text: v == 0 ? '' : v.toString());

  double _d(TextEditingController ctrl, double fallback) =>
      double.tryParse(ctrl.text.trim()) ?? fallback;

  @override
  void initState() {
    super.initState();
    final l = widget.log;
    _name = TextEditingController(text: l.foodLogName);
    _calories = TextEditingController(
      text: l.calorieIntake == 0 ? '' : l.calorieIntake.toString(),
    );
    _protein = _c(l.protein);
    _carbs = _c(l.carbs);
    _fats = _c(l.fats);
    _sodium = _c(l.sodium);
    _fiber = _c(l.fiber);
    _sugar = _c(l.sugar);
    _addedSugar = _c(l.addedSugar);
    _saturatedFat = _c(l.saturatedFat);
    _transFat = _c(l.transFat);
    _unsaturatedFat = _c(l.unsaturatedFat);
    _omega3 = _c(l.omega3);
    _omega6 = _c(l.omega6);
    _cholesterol = _c(l.cholesterol);
    _potassium = _c(l.potassium);
    _calcium = _c(l.calcium);
    _iron = _c(l.iron);
    _magnesium = _c(l.magnesium);
    _zinc = _c(l.zinc);
    _phosphorus = _c(l.phosphorus);
    _selenium = _c(l.selenium);
    _vitaminA = _c(l.vitaminA);
    _vitaminB1 = _c(l.vitaminB1);
    _vitaminB2 = _c(l.vitaminB2);
    _vitaminB3 = _c(l.vitaminB3);
    _vitaminB6 = _c(l.vitaminB6);
    _vitaminB12 = _c(l.vitaminB12);
    _vitaminC = _c(l.vitaminC);
    _vitaminD = _c(l.vitaminD);
    _vitaminE = _c(l.vitaminE);
    _vitaminK = _c(l.vitaminK);
    _folate = _c(l.folate);
    _waterMl = _c(l.waterMl);
    _caffeine = _c(l.caffeine);
    _servingSize = TextEditingController(
      text: (l.servingSize != null && l.servingSize! > 0)
          ? l.servingSize.toString()
          : '',
    );
  }

  @override
  void dispose() {
    for (final ctrl in _allControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _allControllers => [
    _name,
    _calories,
    _protein,
    _carbs,
    _fats,
    _sodium,
    _fiber,
    _sugar,
    _addedSugar,
    _saturatedFat,
    _transFat,
    _unsaturatedFat,
    _omega3,
    _omega6,
    _cholesterol,
    _potassium,
    _calcium,
    _iron,
    _magnesium,
    _zinc,
    _phosphorus,
    _selenium,
    _vitaminA,
    _vitaminB1,
    _vitaminB2,
    _vitaminB3,
    _vitaminB6,
    _vitaminB12,
    _vitaminC,
    _vitaminD,
    _vitaminE,
    _vitaminK,
    _folate,
    _waterMl,
    _caffeine,
    _servingSize,
  ];

  // ── Field helpers (no icon, label + unit hint only) ────────────────────

  /// Full-width field
  Widget _field(
    TextEditingController ctrl, {
    required String label,
    required String hint,
  }) {
    return AppTextField(
      controller: ctrl,
      label: label,
      hint: hint,
      isNumber: true,
    );
  }

  /// Two side-by-side fields
  Widget _row2(
    TextEditingController c1,
    String l1,
    String h1,
    TextEditingController c2,
    String l2,
    String h2,
  ) {
    return Row(
      children: [
        Expanded(
          child: _field(c1, label: l1, hint: h1),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _field(c2, label: l2, hint: h2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final mq = MediaQuery.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: mq.viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Title + close
          Row(
            children: [
              Text(
                'Edit Food Entry',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textPrimary,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: c.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Scrollable fields
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── REQUIRED ─────────────────────────────────────────
                  _SectionLabel(
                    title: 'Required',
                    subtitle:
                        'Fill in any fields you have — you can still log without all of them',
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  AppTextField(
                    controller: _name,
                    label: 'Food Name',
                    hint: 'e.g. Chicken Rice',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _field(_calories, label: 'Calories', hint: 'kcal'),
                  const SizedBox(height: AppSpacing.sm),
                  _row2(_protein, 'Protein', 'g', _carbs, 'Carbs', 'g'),
                  const SizedBox(height: AppSpacing.sm),
                  _row2(_fats, 'Fat', 'g', _sodium, 'Sodium', 'mg'),

                  const SizedBox(height: AppSpacing.lg),

                  // ── EXTENDED MACROS ───────────────────────────────────
                  _CollapsibleSection(
                    title: 'Extended Macros',
                    subtitle: '9 optional fields',
                    expanded: _showExtendedMacros,
                    onToggle: () {
                      setState(() {
                        _showExtendedMacros = !_showExtendedMacros;
                      });
                    },
                    children: [
                      _row2(_fiber, 'Fiber', 'g', _sugar, 'Sugar', 'g'),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _addedSugar,
                        'Added Sugar',
                        'g',
                        _saturatedFat,
                        'Saturated Fat',
                        'g',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _transFat,
                        'Trans Fat',
                        'g',
                        _unsaturatedFat,
                        'Unsaturated Fat',
                        'g',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(_omega3, 'Omega-3', 'g', _omega6, 'Omega-6', 'g'),
                      const SizedBox(height: AppSpacing.sm),
                      _field(_cholesterol, label: 'Cholesterol', hint: 'mg'),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ── MINERALS ──────────────────────────────────────────
                  _CollapsibleSection(
                    title: 'Minerals',
                    subtitle: '7 optional fields',
                    expanded: _showMinerals,
                    onToggle: () {
                      setState(() {
                        _showMinerals = !_showMinerals;
                      });
                    },
                    children: [
                      _row2(
                        _potassium,
                        'Potassium',
                        'mg',
                        _calcium,
                        'Calcium',
                        'mg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(_iron, 'Iron', 'mg', _magnesium, 'Magnesium', 'mg'),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _zinc,
                        'Zinc',
                        'mg',
                        _phosphorus,
                        'Phosphorus',
                        'mg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _field(_selenium, label: 'Selenium', hint: 'µg'),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ── VITAMINS ──────────────────────────────────────────
                  _CollapsibleSection(
                    title: 'Vitamins',
                    subtitle: '11 optional fields',
                    expanded: _showVitamins,
                    onToggle: () {
                      setState(() {
                        _showVitamins = !_showVitamins;
                      });
                    },
                    children: [
                      _row2(
                        _vitaminA,
                        'Vitamin A',
                        'µg RAE',
                        _vitaminB1,
                        'Vitamin B1 (Thiamine)',
                        'mg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _vitaminB2,
                        'Vitamin B2 (Riboflavin)',
                        'mg',
                        _vitaminB3,
                        'Vitamin B3 (Niacin)',
                        'mg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _vitaminB6,
                        'Vitamin B6',
                        'mg',
                        _vitaminB12,
                        'Vitamin B12',
                        'µg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _vitaminC,
                        'Vitamin C',
                        'mg',
                        _vitaminD,
                        'Vitamin D',
                        'µg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _vitaminE,
                        'Vitamin E',
                        'mg',
                        _vitaminK,
                        'Vitamin K',
                        'µg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _field(_folate, label: 'Folate', hint: 'µg DFE'),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ── OTHER ─────────────────────────────────────────────
                  _CollapsibleSection(
                    title: 'Other',
                    subtitle: 'Water, caffeine & serving size',
                    expanded: _showOther,
                    onToggle: () {
                      setState(() {
                        _showOther = !_showOther;
                      });
                    },
                    children: [
                      _row2(
                        _waterMl,
                        'Water',
                        'ml',
                        _caffeine,
                        'Caffeine',
                        'mg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _field(
                        _servingSize,
                        label: 'Serving Size',
                        hint: 'g / ml',
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Save ──────────────────────────────────────────────
                  AppPrimaryButton(
                    label: _isSaving ? 'Saving…' : 'Save Changes',
                    onPressed: _isSaving ? null : () => _save(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final l = widget.log;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a food name.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final updated = FoodLogModel(
      foodLogID: l.foodLogID,
      userId: l.userId,
      foodLogName: name,
      calorieIntake: int.tryParse(_calories.text.trim()) ?? 0,
      foodLogDate: l.foodLogDate,
      loggedAt: l.loggedAt,
      source: l.source,
      imagePath: l.imagePath,
      scanConfidence: l.scanConfidence,
      scanAnalysisResult: l.scanAnalysisResult,
      protein: _d(_protein, l.protein),
      carbs: _d(_carbs, l.carbs),
      fats: _d(_fats, l.fats),
      sodium: _d(_sodium, l.sodium),
      fiber: _d(_fiber, l.fiber),
      sugar: _d(_sugar, l.sugar),
      addedSugar: _d(_addedSugar, l.addedSugar),
      saturatedFat: _d(_saturatedFat, l.saturatedFat),
      transFat: _d(_transFat, l.transFat),
      unsaturatedFat: _d(_unsaturatedFat, l.unsaturatedFat),
      omega3: _d(_omega3, l.omega3),
      omega6: _d(_omega6, l.omega6),
      cholesterol: _d(_cholesterol, l.cholesterol),
      potassium: _d(_potassium, l.potassium),
      calcium: _d(_calcium, l.calcium),
      iron: _d(_iron, l.iron),
      magnesium: _d(_magnesium, l.magnesium),
      zinc: _d(_zinc, l.zinc),
      phosphorus: _d(_phosphorus, l.phosphorus),
      selenium: _d(_selenium, l.selenium),
      vitaminA: _d(_vitaminA, l.vitaminA),
      vitaminB1: _d(_vitaminB1, l.vitaminB1),
      vitaminB2: _d(_vitaminB2, l.vitaminB2),
      vitaminB3: _d(_vitaminB3, l.vitaminB3),
      vitaminB6: _d(_vitaminB6, l.vitaminB6),
      vitaminB12: _d(_vitaminB12, l.vitaminB12),
      vitaminC: _d(_vitaminC, l.vitaminC),
      vitaminD: _d(_vitaminD, l.vitaminD),
      vitaminE: _d(_vitaminE, l.vitaminE),
      vitaminK: _d(_vitaminK, l.vitaminK),
      folate: _d(_folate, l.folate),
      waterMl: _d(_waterMl, l.waterMl),
      caffeine: _d(_caffeine, l.caffeine),
      servingSize: _servingSize.text.trim().isEmpty
          ? l.servingSize
          : double.tryParse(_servingSize.text.trim()),
      servingUnit: l.servingUnit,
    );

    await widget.onSaved(updated);
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section label for the Required block
// ══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTextStyles.sectionTitle.copyWith(color: c.primary),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTextStyles.tiny.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Collapsible section for optional nutrient groups
// ══════════════════════════════════════════════════════════════════════════════

class _CollapsibleSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _CollapsibleSection({
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.formBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.bodyCompact.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: AppTextStyles.tiny.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: c.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
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
                  Divider(color: c.formBorder, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  ...children,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Info row (detail view)
// ══════════════════════════════════════════════════════════════════════════════

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
