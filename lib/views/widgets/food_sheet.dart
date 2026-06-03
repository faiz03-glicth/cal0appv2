import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/models/off_food_result.dart';
import 'package:cal0appv2/services/cache/recent_food_cache.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/viewModels/health/health_warning_viewmodel.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/app_message_banner.dart';
import 'package:cal0appv2/views/widgets/app_bottom_sheet.dart';
import 'package:cal0appv2/views/widgets/app_pill_chip.dart';
import 'package:cal0appv2/views/widgets/health_warning_dialog.dart';

class FoodSheet extends StatefulWidget {
  final bool isEdit;
  final FoodLogModel? existing;
  const FoodSheet({super.key, required this.isEdit, this.existing});

  @override
  State<FoodSheet> createState() => _FoodSheetState();
}

class _FoodSheetState extends State<FoodSheet> {
  late final TextEditingController _searchCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _servingCtrl;
  late FoodLogViewModel _foodLogVm;

  @override
  void initState() {
    super.initState();

    _foodLogVm = context.read<FoodLogViewModel>();

    _searchCtrl = TextEditingController();
    _nameCtrl = TextEditingController(text: _foodLogVm.foodName);
    _calCtrl = TextEditingController(text: _foodLogVm.calories);
    _proteinCtrl = TextEditingController(
      text: _foodLogVm.protein > 0 ? _foodLogVm.protein.toStringAsFixed(1) : '',
    );
    _carbsCtrl = TextEditingController(
      text: _foodLogVm.carbs > 0 ? _foodLogVm.carbs.toStringAsFixed(1) : '',
    );
    _fatCtrl = TextEditingController(
      text: _foodLogVm.fat > 0 ? _foodLogVm.fat.toStringAsFixed(1) : '',
    );
    _servingCtrl = TextEditingController(
      text: _foodLogVm.servingGrams.toStringAsFixed(0),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _foodLogVm.loadRecentFoods();
    });
  }

  @override
  void dispose() {
    _foodLogVm.cancelSearch();

    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _servingCtrl.dispose();
    super.dispose();
  }

  void _syncFormFromVM() {
    if (!mounted) return;
    _nameCtrl.text = _foodLogVm.foodName;
    _calCtrl.text = _foodLogVm.calories;
    _proteinCtrl.text = _foodLogVm.protein > 0
        ? _foodLogVm.protein.toStringAsFixed(1)
        : '';
    _carbsCtrl.text = _foodLogVm.carbs > 0
        ? _foodLogVm.carbs.toStringAsFixed(1)
        : '';
    _fatCtrl.text = _foodLogVm.fat > 0 ? _foodLogVm.fat.toStringAsFixed(1) : '';
    _servingCtrl.text = _foodLogVm.servingGrams.toStringAsFixed(0);
  }

  Future<void> _trySave(BuildContext context, FoodLogViewModel vm) async {
    if (!vm.isFormValid) return;
    if (!mounted) return;

    final uid = context.read<AuthViewModel>().currentUid ?? '';
    if (uid.isEmpty) return;

    HealthWarningViewModel? healthVm;
    try {
      healthVm = context.read<HealthWarningViewModel>();
    } catch (_) {}

    if (healthVm != null) {
      final warnings = healthVm.analyzeValues(
        foodName: vm.foodName,
        calories: int.tryParse(vm.calories) ?? 0,
        protein: vm.protein,
        carbs: vm.carbs,
        fat: vm.fat,
        sugar: vm.sugar,
        sodium: vm.sodium,
      );
      if (warnings.isNotEmpty) {
        if (!mounted) return;
        final proceed = await showHealthWarningDialog(context, warnings);
        if (!mounted) return;
        if (!proceed) return;
      }
    }

    if (!mounted) return;

    bool ok;
    if (widget.isEdit && widget.existing != null) {
      ok = await vm.updateFoodLog(uid: uid, existing: widget.existing!);
    } else {
      ok = await vm.addFoodLog(uid: uid);
    }

    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FoodLogViewModel>();
    return AppBottomSheet(
      title: widget.isEdit ? 'Edit Food' : 'Log Food',
      children: [
        // ── Mode toggle ────────────────────────────────────────────────
        if (!widget.isEdit) ...[
          Row(
            children: [
              AppPillChip(
                label: 'Search',
                selected: !vm.manualMode,
                onTap: () => vm.setManualMode(false),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppPillChip(
                label: 'Manual',
                selected: vm.manualMode,
                onTap: () => vm.setManualMode(true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── Recent foods ───────────────────────────────────────────────
        if (!widget.isEdit)
          _RecentFoodsRow(
            onSelect: (entry) {
              vm.selectRecent(entry);
              _syncFormFromVM();
            },
          ),

        // ── Search mode ────────────────────────────────────────────────
        if (!vm.manualMode)
          _SearchSection(
            vm: vm,
            searchCtrl: _searchCtrl,
            onSelect: (food) {
              vm.selectOFFFood(food);
              _syncFormFromVM();
            },
          ),

        // ── Manual / edit form ─────────────────────────────────────────
        if (vm.manualMode)
          _ManualForm(
            vm: vm,
            nameCtrl: _nameCtrl,
            calCtrl: _calCtrl,
            proteinCtrl: _proteinCtrl,
            carbsCtrl: _carbsCtrl,
            fatCtrl: _fatCtrl,
            servingCtrl: _servingCtrl,
            isEdit: widget.isEdit,
            selectedFood: vm.selectedFood,
            onServingChanged: (g) {
              vm.updateServingSize(g);
              _syncFormFromVM();
            },
            onSave: () => _trySave(context, vm),
          ),
      ],
    );
  }
}

// ── Recent foods row ───────────────────────────────────────────────────────

class _RecentFoodsRow extends StatelessWidget {
  final void Function(RecentFoodEntry) onSelect;
  const _RecentFoodsRow({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Selector<FoodLogViewModel, List<RecentFoodEntry>>(
      selector: (_, vm) => vm.recentFoods,
      builder: (context, recent, _) {
        if (recent.isEmpty) return const SizedBox.shrink();
        final c = C0Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: AppSizes.miniIconSize,
                  color: c.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Recent',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, i) => _RecentChip(
                  entry: recent[i],
                  onTap: () => onSelect(recent[i]),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

class _RecentChip extends StatelessWidget {
  final RecentFoodEntry entry;
  final VoidCallback onTap;
  const _RecentChip({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.formBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              entry.name,
              style: AppTextStyles.caption.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${entry.calories} kcal',
              style: AppTextStyles.micro.copyWith(color: c.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search section ─────────────────────────────────────────────────────────

class _SearchSection extends StatelessWidget {
  final FoodLogViewModel vm;
  final TextEditingController searchCtrl;
  final void Function(OFFFoodResult) onSelect;

  const _SearchSection({
    required this.vm,
    required this.searchCtrl,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search input
        TextField(
          controller: searchCtrl,
          onChanged: vm.searchFood,
          style: AppTextStyles.fieldText.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search food, brand, or product…',
            hintStyle: AppTextStyles.fieldHint.copyWith(color: c.textSecondary),
            prefixIcon: const Icon(Icons.search, size: 20),
            prefixIconColor: c.primary,
            suffixIcon: searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      searchCtrl.clear();
                      vm.searchFood('');
                    },
                  )
                : null,
            filled: true,
            fillColor: c.fieldFill,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.formBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Loading indicator
        if (vm.isSearching)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: c.primary,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Searching....',
                  style: AppTextStyles.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),

        // Empty state
        if (!vm.isSearching &&
            vm.searchResults.isEmpty &&
            searchCtrl.text.length > 2)
          _SearchEmptyState(query: searchCtrl.text),

        // Results list
        if (!vm.isSearching && vm.searchResults.isNotEmpty) ...[
          Text(
            '${vm.searchResults.length} results',
            style: AppTextStyles.micro.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...vm.searchResults.map(
            (food) => _FoodResultCard(food: food, onTap: () => onSelect(food)),
          ),
        ],
      ],
    );
  }
}

// ── Search empty state ─────────────────────────────────────────────────────

class _SearchEmptyState extends StatelessWidget {
  final String query;
  const _SearchEmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: c.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No results for "$query"',
            style: AppTextStyles.bodyCompact.copyWith(
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            'Try different keywords, or switch to Manual mode\nto enter nutrition values directly.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Food result card ───────────────────────────────────────────────────────

class _FoodResultCard extends StatelessWidget {
  final OFFFoodResult food;
  final VoidCallback onTap;
  const _FoodResultCard({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product image or placeholder icon
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: food.imageUrl != null
                  ? Image.network(
                      food.imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _FoodIcon(c: c),
                    )
                  : _FoodIcon(c: c),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name + grade badge row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          food.displayName,
                          style: AppTextStyles.bodyCompact.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (food.nutritionGrade != null) ...[
                        const SizedBox(width: 4),
                        _GradeBadge(grade: food.nutritionGrade!),
                      ],
                    ],
                  ),
                  // Brand
                  if (food.hasBrand) ...[
                    const SizedBox(height: 2),
                    Text(
                      food.displayBrand,
                      style: AppTextStyles.tiny.copyWith(
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  // Macro chips — Wrap prevents overflow
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _MacroChip(
                        '${food.caloriesForServing(food.servingSize)} kcal',
                        c.primary,
                      ),
                      _MacroChip(
                        'P ${food.proteinPer100.toStringAsFixed(0)}g',
                        const Color(0xFF3B82F6),
                      ),
                      _MacroChip(
                        'C ${food.carbsPer100.toStringAsFixed(0)}g',
                        const Color(0xFFF59E0B),
                      ),
                      _MacroChip(
                        'F ${food.fatPer100.toStringAsFixed(0)}g',
                        const Color(0xFF6B7280),
                      ),
                      if (food.isIncomplete) _IncompleteBadge(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.add_circle_outline, color: c.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _FoodIcon extends StatelessWidget {
  final C0Colors c;
  const _FoodIcon({required this.c});
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: c.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Icon(Icons.restaurant, color: c.primary, size: 22),
  );
}

class _MacroChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MacroChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: AppTextStyles.micro.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 9,
      ),
    ),
  );
}

class _GradeBadge extends StatelessWidget {
  final String grade;
  const _GradeBadge({required this.grade});

  Color _color() {
    switch (grade.toUpperCase()) {
      case 'A':
        return const Color(0xFF22C55E);
      case 'B':
        return const Color(0xFF84CC16);
      case 'C':
        return const Color(0xFFF59E0B);
      case 'D':
        return const Color(0xFFF97316);
      case 'E':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        grade.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IncompleteBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B).withOpacity(0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      'partial',
      style: TextStyle(
        color: Color(0xFFB45309),
        fontSize: 8,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ── Manual form ────────────────────────────────────────────────────────────

class _ManualForm extends StatelessWidget {
  final FoodLogViewModel vm;
  final TextEditingController nameCtrl;
  final TextEditingController calCtrl;
  final TextEditingController proteinCtrl;
  final TextEditingController carbsCtrl;
  final TextEditingController fatCtrl;
  final TextEditingController servingCtrl;
  final bool isEdit;
  final OFFFoodResult? selectedFood;
  final ValueChanged<double> onServingChanged;
  final VoidCallback onSave;

  const _ManualForm({
    required this.vm,
    required this.nameCtrl,
    required this.calCtrl,
    required this.proteinCtrl,
    required this.carbsCtrl,
    required this.fatCtrl,
    required this.servingCtrl,
    required this.isEdit,
    required this.selectedFood,
    required this.onServingChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);

    HealthWarningViewModel? healthVm;
    try {
      healthVm = context
          .read<HealthWarningViewModel>(); // was .watch — caused extra rebuilds
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product banner if selected from search
        if (selectedFood != null)
          _SelectedFoodBanner(food: selectedFood!, c: c),
        if (selectedFood != null) const SizedBox(height: AppSpacing.md),

        if (selectedFood != null && selectedFood!.hasNutrition) ...[
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: servingCtrl,
                  label: 'Serving Size',
                  hint: 'e.g. 100',
                  icon: Icons.straighten,
                  isNumber: true,
                  onChanged: (v) {
                    final g = double.tryParse(v);
                    if (g != null && g > 0) onServingChanged(g);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Unit label box
              Padding(
                padding: const EdgeInsets.only(top: 22), // align with field
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: c.primary.withOpacity(0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    selectedFood!.servingUnit.isNotEmpty
                        ? selectedFood!.servingUnit
                        : 'g',
                    style: AppTextStyles.bodyCompact.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Default serving: ${selectedFood!.servingSize.toStringAsFixed(0)} ${selectedFood!.servingUnit.isNotEmpty ? selectedFood!.servingUnit : 'g'} — nutrition values scale automatically',
              style: AppTextStyles.micro.copyWith(
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Core fields
        AppTextField(
          controller: nameCtrl,
          hint: 'Food name',
          icon: Icons.fastfood,
          onChanged: vm.updateFoodName,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: calCtrl,
          hint: 'Calories (kcal)',
          icon: Icons.local_fire_department,
          isNumber: true,
          onChanged: vm.updateCalories,
        ),
        const SizedBox(height: AppSpacing.xs),

        Text(
          'Macros (optional)',
          style: AppTextStyles.fieldLabel.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: proteinCtrl,
                hint: 'Protein g',
                icon: Icons.fitness_center,
                isNumber: true,
                onChanged: vm.updateProtein,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppTextField(
                controller: carbsCtrl,
                hint: 'Carbs g',
                icon: Icons.grain,
                isNumber: true,
                onChanged: vm.updateCarbs,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppTextField(
                controller: fatCtrl,
                hint: 'Fat g',
                icon: Icons.water_drop,
                isNumber: true,
                onChanged: vm.updateFat,
              ),
            ),
          ],
        ),

        // Incomplete data warning
        if (selectedFood != null && selectedFood!.isIncomplete) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFFB45309),
                  size: 15,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Nutrition data for this product is incomplete. '
                    'Please verify and edit values before saving.',
                    style: AppTextStyles.micro.copyWith(
                      color: const Color(0xFFB45309),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Health conditions active badge
        if (healthVm != null && healthVm.hasConditions) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: c.primary.withOpacity(0.2)),
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
                  'Health check active',
                  style: AppTextStyles.micro.copyWith(color: c.primary),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        if (vm.errorMessage != null) ...[
          AppMessageBanner.error(message: vm.errorMessage!),
          const SizedBox(height: AppSpacing.md),
        ],
        AppPrimaryButton(
          label: isEdit ? 'Save Changes' : 'Add to Diary',
          isLoading: vm.isSaving,
          onPressed: vm.isFormValid ? onSave : null,
        ),
      ],
    );
  }
}

class _SelectedFoodBanner extends StatelessWidget {
  final OFFFoodResult food;
  final C0Colors c;
  const _SelectedFoodBanner({required this.food, required this.c});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: c.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: c.primary.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Icon(Icons.check_circle_outline, color: c.primary, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                food.displayName,
                style: AppTextStyles.caption.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (food.hasBrand)
                Text(
                  food.displayBrand,
                  style: AppTextStyles.micro.copyWith(color: c.textSecondary),
                ),
            ],
          ),
        ),
        if (food.nutritionGrade != null)
          _GradeBadge(grade: food.nutritionGrade!),
      ],
    ),
  );
}
