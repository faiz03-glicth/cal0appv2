import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/models/scan_result_model.dart';
import 'package:cal0appv2/viewModels/scan/scan_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/viewModels/health/health_warning_viewmodel.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/app_message_banner.dart';
import 'package:cal0appv2/views/widgets/app_bottom_sheet.dart';
import 'package:cal0appv2/views/widgets/health_warning_dialog.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';
import 'package:cal0appv2/views/widgets/whey_verdict_card.dart';

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
  late final TextEditingController _sugar;
  late final TextEditingController _sodium;
  late final TextEditingController _serving;
  late final TextEditingController _brand;

  bool _addToFoodLog = true;

  // FIX #1 — track whether we have applied real VM data yet.
  // This is now reset-able so a second notifyListeners() can re-fill.
  bool _filledFromVm = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.productName);
    _calories = TextEditingController(text: _fmt(widget.initial.calories));
    _protein = TextEditingController(text: _fmt(widget.initial.protein));
    _carbs = TextEditingController(text: _fmt(widget.initial.carbs));
    _fat = TextEditingController(text: _fmt(widget.initial.fat));
    _sugar = TextEditingController(text: _fmt(widget.initial.sugar));
    _sodium = TextEditingController(text: _fmt(widget.initial.sodium));
    _serving = TextEditingController(text: _fmt(widget.initial.servingSize));
    _brand = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _sugar.dispose();
    _sodium.dispose();
    _serving.dispose();
    _brand.dispose();
    super.dispose();
  }

  // ── FIX #1: fill controllers from VM result ───────────────────────────
  // Called from build() whenever vm.extractedResult first becomes non-null.
  // Safe to call from build() because it only runs once (guard flag).

  void _tryFillFromVm(ScanViewModel vm) {
    if (_filledFromVm) return;
    final r = vm.extractedResult;
    if (r == null) return;

    _filledFromVm = true;

    void fill(TextEditingController c, String val) {
      if (val.isNotEmpty) c.text = val;
    }

    fill(_name, r.productName);
    fill(_calories, _fmt(r.calories));
    fill(_protein, _fmt(r.protein));
    fill(_carbs, _fmt(r.carbs));
    fill(_fat, _fmt(r.fat));
    fill(_sugar, _fmt(r.sugar));
    fill(_sodium, _fmt(r.sodium));
    fill(_serving, _fmt(r.servingSize));
    // No setState needed — the Consumer that calls this already triggers rebuild.
  }

  // ── Formatting helpers ────────────────────────────────────────────────

  static String _fmt(num? v) {
    if (v == null || v == 0) return '';
    if (v is int) return '$v';
    final d = v.toDouble();
    return d == d.truncateToDouble()
        ? d.toInt().toString()
        : d.toStringAsFixed(1);
  }

  // ── Save ──────────────────────────────────────────────────────────────

  Future<void> _save(BuildContext ctx, ScanViewModel vm) async {
    final uid = ctx.read<AuthViewModel>().currentUid ?? '';
    if (uid.isEmpty) return;

    final foodLogVm = ctx.read<FoodLogViewModel>();
    final targetDate = foodLogVm.selectedDate;

    final confirmed = widget.initial.copyWith(
      productName: _name.text.trim(),
      calories: int.tryParse(_calories.text) ?? widget.initial.calories,
      protein: double.tryParse(_protein.text) ?? widget.initial.protein,
      carbs: double.tryParse(_carbs.text) ?? widget.initial.carbs,
      fat: double.tryParse(_fat.text) ?? widget.initial.fat,
      sugar: double.tryParse(_sugar.text) ?? widget.initial.sugar,
      sodium: double.tryParse(_sodium.text) ?? widget.initial.sodium,
      servingSize: double.tryParse(_serving.text),
    );

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
      targetDate: targetDate,
    );
    if (ok && ctx.mounted) {
      await foodLogVm.loadFoodLogs(uid: uid);
      Navigator.pop(ctx);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // FIX #1 — use Consumer so we react every time vm notifies.
    // _tryFillFromVm() is called here, inside the build, which is safe because
    // it only mutates controllers (not widget state) and only runs once.
    return Consumer<ScanViewModel>(
      builder: (context, vm, _) {
        _tryFillFromVm(vm); // fills controllers the moment result arrives

        final c = C0Theme.of(context);
        final healthVm = context.watch<HealthWarningViewModel>();
        final conf = vm.ocrConfidence > 0.0
            ? vm.ocrConfidence
            : widget.initial.extractionConfidence;

        return AppBottomSheet(
          subtitle: _SheetHeader(confidence: conf),
          children: [
            // FIX #2 — WheyVerdictCard is first — impossible to miss
            WheyVerdictCard(vm: vm),
            const SizedBox(height: AppSpacing.md),

            // ── Flagged ingredients ───────────────────────────────
            if (vm.detectedIngredients.isNotEmpty) ...[
              _FlaggedIngredientsPanel(ingredients: vm.detectedIngredients),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── OCR quality warning ───────────────────────────────
            if (vm.lowOcrQuality || conf < 0.40) ...[
              _QualityWarning(isLowQuality: vm.lowOcrQuality, confidence: conf),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Ingredient list ───────────────────────────────────
            if (_ingredientText(vm).isNotEmpty) ...[
              _IngredientListSection(text: _ingredientText(vm)),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Editable fields ───────────────────────────────────
            _Field(
              controller: _name,
              label: 'Product Name',
              hint: 'e.g. Gold Standard Whey',
              icon: Icons.label_outline,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              controller: _brand,
              label: 'Brand Name',
              hint: 'e.g. Optimum Nutrition',
              icon: Icons.storefront_outlined,
              keyboardType: TextInputType.text,
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
            _SectionLabel('Macros per serving'),
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
                    controller: _sodium,
                    label: 'Sodium',
                    hint: '0',
                    icon: Icons.water_outlined,
                    unit: 'mg',
                    accent: const Color(0xFF06B6D4),
                  ),
                ),
              ],
            ),

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

  String _ingredientText(ScanViewModel vm) {
    if (vm.extractedResult?.ingredientText.isNotEmpty == true) {
      return vm.extractedResult!.ingredientText;
    }
    return vm.cleanedOcr?.ingredientSection ?? '';
  }
}

// ── Sheet header ───────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final double confidence;
  const _SheetHeader({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    Color col;
    if (confidence >= 0.65)
      col = c.success;
    else if (confidence >= 0.40)
      col = Colors.orange;
    else
      col = c.warning;

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

// ── Section label ──────────────────────────────────────────────────────────

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

// ── Editable field ─────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? unit;
  final Color? accent;
  final TextInputType keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.unit,
    this.accent,
    this.keyboardType = TextInputType.number,
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
        keyboardType: keyboardType == TextInputType.number
            ? const TextInputType.numberWithOptions(decimal: true)
            : keyboardType,
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
          hintStyle: TextStyle(
            color: c.textSecondary.withValues(alpha: 0.4),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 10, right: 6),
            child: Icon(
              icon,
              size: 16,
              color: c.textSecondary.withValues(alpha: 0.6),
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

// ── Flagged ingredients panel ──────────────────────────────────────────────

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
  bool _showExp = false;

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
            onTap: () => setState(() => _showExp = !_showExp),
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
                    _showExp
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: c.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 160),
            crossFadeState: _showExp
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

// ── Ingredient list section ────────────────────────────────────────────────

class _IngredientListSection extends StatefulWidget {
  final String text;
  const _IngredientListSection({required this.text});
  @override
  State<_IngredientListSection> createState() => _IngredientListSectionState();
}

class _IngredientListSectionState extends State<_IngredientListSection> {
  bool _expanded = false;

  static const _flagged = [
    'creatine',
    'taurine',
    'glycine',
    'glutamine',
    'arginine',
    'alanine',
    'leucine',
    'beta-alanine',
    'maltodextrin',
    'sucralose',
    'aspartame',
    'acesulfame',
  ];

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final items = widget.text
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.length > 1)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.list_alt_rounded, color: c.primary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ingredient List',
                          style: AppTextStyles.bodyCompact.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          '${items.isEmpty ? '?' : items.length} ingredients — tap to view',
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
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: items.map((ing) {
                  final isFlagged = _flagged.any(
                    (k) => ing.toLowerCase().contains(k),
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isFlagged
                          ? c.warning.withValues(alpha: 0.10)
                          : c.card,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: isFlagged
                            ? c.warning.withValues(alpha: 0.4)
                            : c.divider,
                      ),
                    ),
                    child: Text(
                      ing,
                      style: AppTextStyles.micro.copyWith(
                        color: isFlagged ? c.warning : c.textPrimary,
                        fontWeight: isFlagged
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Quality warning ────────────────────────────────────────────────────────

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
                      : 'Partial extraction '
                            '(${(confidence * 100).toStringAsFixed(0)}%)',
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

// ── Diary toggle ───────────────────────────────────────────────────────────

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

// ── Health badge ───────────────────────────────────────────────────────────

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
