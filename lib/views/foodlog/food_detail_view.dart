import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/viewModels/foodlog/food_history_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/viewModels/mixins/authenticity_reanalysis_mixin.dart';
import 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/macro_progress_bar.dart';
import 'package:cal0appv2/views/widgets/source_badge.dart';
import 'package:cal0appv2/views/widgets/authenticity_verdict_card.dart';
import 'package:cal0appv2/views/widgets/supplement_mode_section.dart';

// ── Legacy verdict parsing ──────────────────────────────────────────────────
// Older logs (saved before ingredientText existed, or saved from the ML
// model rather than a manual edit) only have a summary string like
// "SPIKED (82%)" in scanAnalysisResult. We keep this parser around purely
// to show that original AI verdict as a fallback when there's no
// ingredientText to run the real (shared) rule-based check against.

enum _LegacyVerdict { authentic, spiked, plantBased, unknown }

class _ParsedLegacyVerdict {
  final _LegacyVerdict verdict;
  final double confidence; // 0–1, 0 if not stored
  const _ParsedLegacyVerdict(this.verdict, this.confidence);

  static _ParsedLegacyVerdict from(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const _ParsedLegacyVerdict(_LegacyVerdict.unknown, 0);
    }
    final upper = raw.toUpperCase();
    final confMatch = RegExp(r'(\d+)%').firstMatch(raw);
    final conf = confMatch != null
        ? (int.tryParse(confMatch.group(1) ?? '0') ?? 0) / 100.0
        : 0.0;

    if (upper.contains('NON-AUTHENTIC') || upper.contains('SPIKED')) {
      return _ParsedLegacyVerdict(_LegacyVerdict.spiked, conf);
    }
    if (upper.contains('PLANT')) {
      return _ParsedLegacyVerdict(_LegacyVerdict.plantBased, conf);
    }
    if (upper.contains('AUTHENTIC')) {
      return _ParsedLegacyVerdict(_LegacyVerdict.authentic, conf);
    }
    return _ParsedLegacyVerdict(_LegacyVerdict.unknown, conf);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FoodDetailView
// ══════════════════════════════════════════════════════════════════════════════

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

    // If this log has ingredient text saved (either from the scan flow or
    // a manual edit), run the SAME shared nitrogen-compound check the live
    // scan uses — this is what makes history behave identically to the
    // live scan instead of drifting with its own logic.
    final hasIngredientText = _log.ingredientText.trim().isNotEmpty;
    final authenticityCheck = hasIngredientText
        ? IngredientAuthenticityService.check(_log.ingredientText)
        : null;
    final legacy = _ParsedLegacyVerdict.from(_log.scanAnalysisResult);

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
          // The one shared edit-button entry point — identical icon/action
          // to what a user would tap on the live scan confirm sheet.
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

            // ── Meta card ─────────────────────────────────────────
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

            // ── AI verdict card ────────────────────────────────────
            // Uses the exact same AuthenticityVerdictCard as the live scan
            // confirm sheet whenever we have ingredient text to check.
            // Falls back to the legacy parsed-string display only for old
            // logs that never had ingredientText saved.
            if (authenticityCheck != null) ...[
              AuthenticityVerdictCard(check: authenticityCheck),
              const SizedBox(height: AppSpacing.md),
            ] else if (_log.isScanned && _log.scanAnalysisResult != null) ...[
              _LegacyVerdictCard(legacy: legacy),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Nutrition ─────────────────────────────────────────
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
                    label: 'Carbs',
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
                  if (_log.fiber > 0)
                    MacroProgressBar(
                      label: 'Fiber',
                      value: _log.fiber,
                      max: 28,
                      color: const Color(0xFF10B981),
                    ),
                  if (_log.saturatedFat > 0)
                    MacroProgressBar(
                      label: 'Saturated Fat',
                      value: _log.saturatedFat,
                      max: 20,
                      color: const Color(0xFFEF4444),
                    ),
                  if (_log.sodium > 0)
                    MacroProgressBar(
                      label: 'Sodium',
                      value: _log.sodium,
                      max: 2300,
                      unit: 'mg',
                      color: C0Theme.macroSodium,
                    ),
                  if (_log.potassium > 0)
                    MacroProgressBar(
                      label: 'Potassium',
                      value: _log.potassium,
                      max: 4700,
                      unit: 'mg',
                      color: const Color(0xFF8B5CF6),
                    ),
                  if (_log.calcium > 0)
                    MacroProgressBar(
                      label: 'Calcium',
                      value: _log.calcium,
                      max: 1000,
                      unit: 'mg',
                      color: const Color(0xFF14B8A6),
                    ),
                  if (_log.iron > 0)
                    MacroProgressBar(
                      label: 'Iron',
                      value: _log.iron,
                      max: 18,
                      unit: 'mg',
                      color: const Color(0xFFF87171),
                    ),
                  if (_log.magnesium > 0)
                    MacroProgressBar(
                      label: 'Magnesium',
                      value: _log.magnesium,
                      max: 420,
                      unit: 'mg',
                      color: const Color(0xFF34D399),
                    ),
                  if (_log.zinc > 0)
                    MacroProgressBar(
                      label: 'Zinc',
                      value: _log.zinc,
                      max: 11,
                      unit: 'mg',
                      color: const Color(0xFFFBBF24),
                    ),
                  if (_log.vitaminC > 0)
                    MacroProgressBar(
                      label: 'Vitamin C',
                      value: _log.vitaminC,
                      max: 90,
                      unit: 'mg',
                      color: const Color(0xFFF97316),
                    ),
                  if (_log.vitaminD > 0)
                    MacroProgressBar(
                      label: 'Vitamin D',
                      value: _log.vitaminD,
                      max: 20,
                      unit: 'µg',
                      color: const Color(0xFFEAB308),
                    ),
                  if (_log.caffeine > 0)
                    MacroProgressBar(
                      label: 'Caffeine',
                      value: _log.caffeine,
                      max: 400,
                      unit: 'mg',
                      color: const Color(0xFF78716C),
                    ),
                  if (_log.creatineMonohydrate > 0)
                    MacroProgressBar(
                      label: 'Creatine Mono.',
                      value: _log.creatineMonohydrate,
                      max: 5,
                      unit: 'g',
                      color: const Color(0xFF7C3AED),
                    ),
                  if (_log.bcaa > 0)
                    MacroProgressBar(
                      label: 'Total BCAAs',
                      value: _log.bcaa,
                      max: 10,
                      unit: 'g',
                      color: const Color(0xFF0284C7),
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

// ── Legacy verdict card (only shown when there's no ingredientText) ────────

class _LegacyVerdictCard extends StatelessWidget {
  final _ParsedLegacyVerdict legacy;
  const _LegacyVerdictCard({required this.legacy});

  _LegacyStyle _style(C0Colors c) {
    switch (legacy.verdict) {
      case _LegacyVerdict.authentic:
        return _LegacyStyle(
          bg: const Color(0xFFECFDF5),
          border: const Color(0xFF22C55E),
          accent: const Color(0xFF16A34A),
          icon: Icons.shield_rounded,
          headline: 'Looks Authentic ✓',
          sub: 'No amino spiking detected',
        );
      case _LegacyVerdict.spiked:
        return _LegacyStyle(
          bg: const Color(0xFFFEF2F2),
          border: const Color(0xFFEF4444),
          accent: const Color(0xFFDC2626),
          icon: Icons.dangerous_rounded,
          headline: '⚠ Spiking Detected',
          sub: 'Suspicious ingredients found',
        );
      case _LegacyVerdict.plantBased:
        return _LegacyStyle(
          bg: const Color(0xFFF0FDF4),
          border: const Color(0xFF4ADE80),
          accent: const Color(0xFF15803D),
          icon: Icons.eco_rounded,
          headline: '🌱 Plant-Based',
          sub: 'Not whey protein',
        );
      case _LegacyVerdict.unknown:
        return _LegacyStyle(
          bg: c.card,
          border: c.divider,
          accent: c.textSecondary,
          icon: Icons.help_center_outlined,
          headline: 'No AI Result',
          sub: 'Analysis was not recorded',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final s = _style(c);
    final pct = legacy.confidence > 0
        ? '${(legacy.confidence * 100).toStringAsFixed(0)}%'
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: s.border, width: 2),
      ),
      child: Column(
        children: [
          Icon(s.icon, color: s.accent, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(
            s.headline,
            style: AppTextStyles.title.copyWith(
              color: s.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            pct != null ? '${s.sub} · $pct confidence' : s.sub,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyCompact.copyWith(
              color: s.accent.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This entry has no saved ingredient text, so it shows the '
            'original AI result instead of a re-checkable verdict. Edit the '
            'entry and add ingredients to enable Authentic / Non-Authentic '
            're-checks.',
            textAlign: TextAlign.center,
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

class _LegacyStyle {
  final Color bg, border, accent;
  final IconData icon;
  final String headline, sub;
  const _LegacyStyle({
    required this.bg,
    required this.border,
    required this.accent,
    required this.icon,
    required this.headline,
    required this.sub,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// Edit sheet — now uses the SAME shared edit-button + re-check behavior as
// the live scan confirm sheet, and the SAME nutrient field set (core
// macros, extended macros, minerals, vitamins, supplement compounds,
// ingredients, other).
// ══════════════════════════════════════════════════════════════════════════════

class _EditSheet extends StatefulWidget {
  final FoodLogModel log;
  final Future<void> Function(FoodLogModel updated) onSaved;
  const _EditSheet({required this.log, required this.onSaved});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet>
    with AuthenticityReanalysisMixin {
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fats;
  late final TextEditingController _sodium;
  late final TextEditingController _fiber;
  late final TextEditingController _sugar;
  late final TextEditingController _addedSugar;
  late final TextEditingController _saturatedFat;
  late final TextEditingController _transFat;
  late final TextEditingController _unsaturatedFat;
  late final TextEditingController _omega3;
  late final TextEditingController _omega6;
  late final TextEditingController _cholesterol;
  late final TextEditingController _potassium;
  late final TextEditingController _calcium;
  late final TextEditingController _iron;
  late final TextEditingController _magnesium;
  late final TextEditingController _zinc;
  late final TextEditingController _phosphorus;
  late final TextEditingController _selenium;
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
  late final TextEditingController _waterMl;
  late final TextEditingController _caffeine;
  late final TextEditingController _servingSize;
  // Supplement compounds — same fields the scan confirm sheet exposes.
  late final TextEditingController _creatineMonohydrate;
  late final TextEditingController _bcaa;
  late final TextEditingController _leucine;
  late final TextEditingController _isoleucine;
  late final TextEditingController _valine;
  late final TextEditingController _glutamine;
  late final TextEditingController _taurine;
  // Ingredients — drives the Authentic / Non-Authentic re-check, same as
  // the scan confirm sheet.
  late final TextEditingController _ingredientText;

  bool _isSaving = false;
  bool _showExtMacros = false;
  bool _showMinerals = false;
  bool _showVitamins = false;
  bool _showOther = false;
  // Off = Normal Food Logging, On = Whey Supplement — same contract as
  // FoodLogViewModel.isSupplementMode used by the diary quick-edit sheet.
  // This was the missing piece: without a toggle here, ingredients were
  // always shown/saved regardless of intent, and there was no way to know
  // whether a re-check should even run.
  bool _isSupplementMode = false;

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
    _creatineMonohydrate = _c(l.creatineMonohydrate);
    _bcaa = _c(l.bcaa);
    _leucine = _c(l.leucine);
    _isoleucine = _c(l.isoleucine);
    _valine = _c(l.valine);
    _glutamine = _c(l.glutamine);
    _taurine = _c(l.taurine);
    _ingredientText = TextEditingController(text: l.ingredientText);

    // Restore Supplements state from the saved log, same contract as
    // FoodLogViewModel.prefillForEdit — a log only counts as a supplement
    // if it actually has ingredient text or compound amounts saved.
    _isSupplementMode =
        l.ingredientText.trim().isNotEmpty ||
        l.creatineMonohydrate > 0 ||
        l.bcaa > 0 ||
        l.leucine > 0 ||
        l.isoleucine > 0 ||
        l.valine > 0 ||
        l.glutamine > 0 ||
        l.taurine > 0;

    // Same shared behavior as the scan confirm sheet: editing ANY field
    // here (macros, supplements, or ingredients) debounces then re-runs
    // the Authentic / Non-Authentic check.
    watchFieldsForReanalysis([
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
      _creatineMonohydrate,
      _bcaa,
      _leucine,
      _isoleucine,
      _valine,
      _glutamine,
      _taurine,
      _ingredientText,
    ]);

    // Show a result immediately if there's already ingredient text, rather
    // than waiting for an edit.
    WidgetsBinding.instance.addPostFrameCallback((_) => runReanalysisNow());
  }

  // ── AuthenticityReanalysisMixin wiring ──────────────────────────────────
  // Local state instead of a ScanViewModel — history has no live scan
  // session — but it's the exact same mixin, same debounce, same service.

  AuthenticityCheck? _liveCheck;

  @override
  String get ingredientTextForReanalysis =>
      _isSupplementMode ? _ingredientText.text : '';

  void _onSupplementModeChanged(bool v) {
    setState(() => _isSupplementMode = v);
    if (v) {
      runReanalysisNow();
    } else {
      setState(() => _liveCheck = null);
    }
  }

  @override
  void onAuthenticityChecked(AuthenticityCheck result) {
    if (!mounted) return;
    setState(() => _liveCheck = result);
  }

  @override
  void dispose() {
    disposeAuthenticityReanalysis();
    for (final ctrl in [
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
      _creatineMonohydrate,
      _bcaa,
      _leucine,
      _isoleucine,
      _valine,
      _glutamine,
      _taurine,
      _ingredientText,
    ])
      ctrl.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController ctrl, {
    required String label,
    required String hint,
  }) =>
      AppTextField(controller: ctrl, label: label, hint: hint, isNumber: true);

  Widget _row2(
    TextEditingController c1,
    String l1,
    String h1,
    TextEditingController c2,
    String l2,
    String h2,
  ) => Row(
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

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The one shared Supplements block — same widget used on
                  // the diary quick-edit sheet. Toggle, live verdict
                  // preview, ingredient field, and compound fields all in
                  // one place; nothing duplicated here anymore.
                  SupplementModeSection(
                    isSupplementMode: _isSupplementMode,
                    onToggle: _onSupplementModeChanged,
                    ingredientCtrl: _ingredientText,
                    creatineCtrl: _creatineMonohydrate,
                    bcaaCtrl: _bcaa,
                    leucineCtrl: _leucine,
                    isoleucineCtrl: _isoleucine,
                    valineCtrl: _valine,
                    glutamineCtrl: _glutamine,
                    taurineCtrl: _taurine,
                    liveCheck: _liveCheck,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _SLabel(
                    title: 'Required',
                    subtitle: 'Fill in any fields you have',
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

                  _CSection(
                    title: 'Extended Macros',
                    subtitle: '9 optional fields',
                    expanded: _showExtMacros,
                    onToggle: () =>
                        setState(() => _showExtMacros = !_showExtMacros),
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
                  _CSection(
                    title: 'Minerals',
                    subtitle: '7 optional fields',
                    expanded: _showMinerals,
                    onToggle: () =>
                        setState(() => _showMinerals = !_showMinerals),
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
                  _CSection(
                    title: 'Vitamins',
                    subtitle: '11 optional fields',
                    expanded: _showVitamins,
                    onToggle: () =>
                        setState(() => _showVitamins = !_showVitamins),
                    children: [
                      _row2(
                        _vitaminA,
                        'Vitamin A',
                        'µg RAE',
                        _vitaminB1,
                        'Vitamin B1',
                        'mg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _vitaminB2,
                        'Vitamin B2',
                        'mg',
                        _vitaminB3,
                        'Vitamin B3',
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
                  _CSection(
                    title: 'Other',
                    subtitle: 'Water, caffeine & serving size',
                    expanded: _showOther,
                    onToggle: () => setState(() => _showOther = !_showOther),
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

    // Off = Normal Food Logging: nothing supplement-related gets saved,
    // even if there's leftover text in the field from before toggling off.
    // On = Whey Supplement: persist whatever's there and the live check.
    final ingredientText = _isSupplementMode ? _ingredientText.text.trim() : '';
    final analysisResult = !_isSupplementMode
        ? null
        : (_liveCheck != null
              ? (_liveCheck!.isNonAuthentic ? 'NON-AUTHENTIC' : 'AUTHENTIC')
              : null);

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
      scanAnalysisResult: analysisResult,
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
      creatineMonohydrate: _isSupplementMode
          ? _d(_creatineMonohydrate, l.creatineMonohydrate)
          : 0,
      bcaa: _isSupplementMode ? _d(_bcaa, l.bcaa) : 0,
      leucine: _isSupplementMode ? _d(_leucine, l.leucine) : 0,
      isoleucine: _isSupplementMode ? _d(_isoleucine, l.isoleucine) : 0,
      valine: _isSupplementMode ? _d(_valine, l.valine) : 0,
      glutamine: _isSupplementMode ? _d(_glutamine, l.glutamine) : 0,
      taurine: _isSupplementMode ? _d(_taurine, l.taurine) : 0,
      waterMl: _d(_waterMl, l.waterMl),
      caffeine: _d(_caffeine, l.caffeine),
      ingredientText: ingredientText,
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

// ── Shared small widgets ───────────────────────────────────────────────────

class _SLabel extends StatelessWidget {
  final String title, subtitle;
  const _SLabel({required this.title, required this.subtitle});
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

class _CSection extends StatelessWidget {
  final String title, subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  const _CSection({
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

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
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
