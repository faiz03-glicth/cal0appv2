import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/scan/barcode_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/sheet_handle.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';

class BarcodeResultSheet extends StatefulWidget {
  const BarcodeResultSheet({super.key});

  @override
  State<BarcodeResultSheet> createState() => _BarcodeResultSheetState();
}

class _BarcodeResultSheetState extends State<BarcodeResultSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _servingCtrl;

  // Track current serving grams for rescaling
  double _servingGrams = 100;

  @override
  void initState() {
    super.initState();
    final vm = context.read<BarcodeViewModel>();
    final food = vm.foundFood;

    _servingGrams = food?.servingSize ?? 100;

    _nameCtrl = TextEditingController(text: food?.displayName ?? '');
    _calCtrl = TextEditingController(
      text: food != null ? '${food.caloriesForServing(_servingGrams)}' : '',
    );
    _proteinCtrl = TextEditingController(
      text: _fmt(food?.proteinForServing(_servingGrams)),
    );
    _carbsCtrl = TextEditingController(
      text: _fmt(food?.carbsForServing(_servingGrams)),
    );
    _fatCtrl = TextEditingController(
      text: _fmt(food?.fatForServing(_servingGrams)),
    );
    _servingCtrl = TextEditingController(
      text: _servingGrams.toStringAsFixed(0),
    );
  }

  String _fmt(double? v) {
    if (v == null || v == 0) return '';
    return v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _servingCtrl.dispose();
    super.dispose();
  }

  void _onServingChanged(String value) {
    final vm = context.read<BarcodeViewModel>();
    final food = vm.foundFood;
    if (food == null || !food.hasNutrition) return;
    final g = double.tryParse(value);
    if (g == null || g <= 0) return;
    setState(() {
      _servingGrams = g;
      _calCtrl.text = '${food.caloriesForServing(g)}';
      _proteinCtrl.text = _fmt(food.proteinForServing(g));
      _carbsCtrl.text = _fmt(food.carbsForServing(g));
      _fatCtrl.text = _fmt(food.fatForServing(g));
    });
  }

  Future<void> _save() async {
    final vm = context.read<BarcodeViewModel>();
    final uid = context.read<AuthViewModel>().currentUid ?? '';
    final foodLogVm = context.read<FoodLogViewModel>();
    final targetDate = foodLogVm.selectedDate;

    final ok = await vm.saveToFoodLog(
      uid: uid,
      foodName: _nameCtrl.text,
      calories: int.tryParse(_calCtrl.text) ?? 0,
      protein: double.tryParse(_proteinCtrl.text) ?? 0,
      carbs: double.tryParse(_carbsCtrl.text) ?? 0,
      fat: double.tryParse(_fatCtrl.text) ?? 0,
      servingSize: double.tryParse(_servingCtrl.text),
      targetDate: targetDate,
    );

    if (ok && mounted) {
      await foodLogVm.loadFoodLogs(uid: uid);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = context.watch<BarcodeViewModel>();
    final isNotFound = vm.state == BarcodeScanState.notFound;
    final food = vm.foundFood;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxl + MediaQuery.of(context).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: AppSpacing.lg),

              if (isNotFound)
                _NotFoundBanner(barcode: vm.lastBarcode ?? '', c: c)
              else if (food != null)
                _ProductBanner(food: food, c: c),

              const SizedBox(height: AppSpacing.lg),

              // Serving size
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _servingCtrl,
                      label: 'Serving Size',
                      hint: 'grams (g)',
                      icon: Icons.straighten,
                      isNumber: true,
                      onChanged: _onServingChanged,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      'g',
                      style: AppTextStyles.caption.copyWith(
                        color: c.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              AppTextField(
                controller: _nameCtrl,
                label: 'Product Name',
                hint: 'Enter product name',
                icon: Icons.label_outline,
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'Nutrition per serving',
                style: AppTextStyles.fieldLabel.copyWith(
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              AppTextField(
                controller: _calCtrl,
                hint: 'Calories (kcal)',
                icon: Icons.local_fire_department,
                isNumber: true,
              ),
              const SizedBox(height: AppSpacing.sm),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _proteinCtrl,
                      hint: 'Protein g',
                      icon: Icons.fitness_center,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      controller: _carbsCtrl,
                      hint: 'Carbs g',
                      icon: Icons.grain,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      controller: _fatCtrl,
                      hint: 'Fat g',
                      icon: Icons.water_drop,
                      isNumber: true,
                    ),
                  ),
                ],
              ),

              // Grade + completeness info
              if (food != null &&
                  (food.nutritionGrade != null || food.isIncomplete)) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    if (food.nutritionGrade != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _gradeColor(
                            food.nutritionGrade!,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Grade ',
                              style: AppTextStyles.micro.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                            Text(
                              food.nutritionGrade!.toUpperCase(),
                              style: AppTextStyles.caption.copyWith(
                                color: _gradeColor(food.nutritionGrade!),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    if (food.isIncomplete)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '⚠ Incomplete data',
                          style: AppTextStyles.micro.copyWith(
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.divider),
                        foregroundColor: c.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: AppPrimaryButton(
                      label: 'Add to Diary',
                      isLoading: vm.isSaving,
                      icon: Icons.add,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _gradeColor(String grade) {
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
}

class _ProductBanner extends StatelessWidget {
  final food;
  final C0Colors c;
  const _ProductBanner({required this.food, required this.c});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: c.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(Icons.check_circle_outline, color: c.success, size: 26),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              food.displayName,
              style: AppTextStyles.title.copyWith(color: c.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (food.hasBrand)
              Text(
                food.displayBrand,
                style: AppTextStyles.caption.copyWith(color: c.textSecondary),
              ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: (food.isVerified ? c.success : Colors.orange)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    food.isVerified ? Icons.verified : Icons.info_outline,
                    size: AppSizes.miniIconSize,
                    color: food.isVerified ? c.success : Colors.orange,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    food.isVerified
                        ? 'Verified nutrition data'
                        : 'Incomplete data — please verify',
                    style: AppTextStyles.micro.copyWith(
                      color: food.isVerified ? c.success : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _NotFoundBanner extends StatelessWidget {
  final String barcode;
  final C0Colors c;
  const _NotFoundBanner({required this.barcode, required this.c});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.search_off, color: Colors.orange, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product Not Found',
                  style: AppTextStyles.title.copyWith(color: c.textPrimary),
                ),
                Text(
                  barcode,
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          'This product isn\'t in OpenFoodFacts yet. '
          'Enter the nutrition details manually from the product label — '
          'your entry helps build the global database.',
          style: AppTextStyles.caption.copyWith(
            color: c.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    ],
  );
}
