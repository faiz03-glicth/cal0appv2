import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
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
import 'package:cal0appv2/models/health/health_condition.dart';

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

  @override
  void initState() {
    super.initState();
    final vm = Provider.of<FoodLogViewModel>(context, listen: false);
    _searchCtrl = TextEditingController();
    _nameCtrl = TextEditingController(text: vm.foodName);
    _calCtrl = TextEditingController(text: vm.calories);
    _proteinCtrl = TextEditingController(
      text: vm.protein > 0 ? vm.protein.toString() : '',
    );
    _carbsCtrl = TextEditingController(
      text: vm.carbs > 0 ? vm.carbs.toString() : '',
    );
    _fatCtrl = TextEditingController(text: vm.fat > 0 ? vm.fat.toString() : '');

    // Lazy-load recent foods (no-op if already loaded this session)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FoodLogViewModel>().loadRecentFoods();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  // ── Save with health warning check ────────────────────────────────────

  Future<void> _trySave(BuildContext context, FoodLogViewModel vm) async {
    if (!vm.isFormValid) return;
    final uid = context.read<AuthViewModel>().currentUid ?? '';
    if (uid.isEmpty) return;

    // Health warning analysis
    try {
      final healthVm = context.read<HealthWarningViewModel>();
      final warnings = healthVm.analyzeValues(
        foodName: vm.foodName,
        calories: int.tryParse(vm.calories) ?? 0,
        protein: vm.protein,
        carbs: vm.carbs,
        fat: vm.fat,
      );
      if (warnings.isNotEmpty && context.mounted) {
        final proceed = await showHealthWarningDialog(context, warnings);
        if (!proceed || !context.mounted) return;
      }
    } catch (_) {
      // Health warning VM may not be present in all contexts — skip
    }

    bool ok;
    if (widget.isEdit && widget.existing != null) {
      ok = await vm.updateFoodLog(uid: uid, existing: widget.existing!);
    } else {
      ok = await vm.addFoodLog(uid: uid);
    }
    if (ok && context.mounted) Navigator.pop(context);
  }

  void _onSelectFood(FoodLogViewModel vm) {
    _nameCtrl.text = vm.foodName;
    _calCtrl.text = vm.calories;
    _proteinCtrl.text = vm.protein > 0 ? vm.protein.toString() : '';
    _carbsCtrl.text = vm.carbs > 0 ? vm.carbs.toString() : '';
    _fatCtrl.text = vm.fat > 0 ? vm.fat.toString() : '';
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<FoodLogViewModel>(context);
    return AppBottomSheet(
      title: widget.isEdit ? 'Edit Food' : 'Add Food',
      children: [
        // Mode toggle — only for new entries
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

        // Recent foods — shown in both modes when cache has entries
        if (!widget.isEdit)
          _RecentFoodsRow(
            onSelect: (entry) {
              vm.selectRecent(entry);
              _onSelectFood(vm);
            },
          ),

        if (!vm.manualMode)
          _SearchSection(
            vm: vm,
            searchCtrl: _searchCtrl,
            onSelectFood: _onSelectFood,
          ),

        if (vm.manualMode)
          _ManualForm(
            vm: vm,
            nameCtrl: _nameCtrl,
            calCtrl: _calCtrl,
            proteinCtrl: _proteinCtrl,
            carbsCtrl: _carbsCtrl,
            fatCtrl: _fatCtrl,
            isEdit: widget.isEdit,
            onSave: () => _trySave(context, vm),
          ),
      ],
    );
  }
}

// ── Recent foods horizontal row ────────────────────────────────────────────

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
                separatorBuilder: (_, __) =>
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
  final void Function(FoodLogViewModel) onSelectFood;

  const _SearchSection({
    required this.vm,
    required this.searchCtrl,
    required this.onSelectFood,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Column(
      children: [
        AppTextField(
          controller: searchCtrl,
          hint: 'Search food...',
          icon: Icons.search,
          onChanged: vm.searchFood,
        ),
        if (vm.isSearching)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
          ),
        ...vm.searchResults.map(
          (food) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              food['name'] ?? food['food_name'] ?? '',
              style: AppTextStyles.bodyCompact.copyWith(color: c.textPrimary),
            ),
            subtitle: Text(
              '${food['calories'] ?? food['energy'] ?? 0} kcal',
              style: AppTextStyles.caption.copyWith(color: c.textSecondary),
            ),
            trailing: Icon(
              Icons.add_circle_outline,
              color: c.primary,
              size: AppSizes.fieldIconSize,
            ),
            onTap: () {
              vm.selectFood(food);
              onSelectFood(vm);
            },
          ),
        ),
      ],
    );
  }
}

// ── Manual entry form ──────────────────────────────────────────────────────

class _ManualForm extends StatelessWidget {
  final FoodLogViewModel vm;
  final TextEditingController nameCtrl;
  final TextEditingController calCtrl;
  final TextEditingController proteinCtrl;
  final TextEditingController carbsCtrl;
  final TextEditingController fatCtrl;
  final bool isEdit;
  final VoidCallback onSave;

  const _ManualForm({
    required this.vm,
    required this.nameCtrl,
    required this.calCtrl,
    required this.proteinCtrl,
    required this.carbsCtrl,
    required this.fatCtrl,
    required this.isEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);

    // Try to get health VM — optional dependency
    HealthWarningViewModel? healthVm;
    try {
      healthVm = context.watch<HealthWarningViewModel>();
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

        // Health conditions active indicator
        if (healthVm != null && healthVm.hasConditions) ...[
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
