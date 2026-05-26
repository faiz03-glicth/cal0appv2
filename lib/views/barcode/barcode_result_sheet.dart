import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/scan/barcode_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/sheet_handle.dart';

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

  @override
  void initState() {
    super.initState();
    final vm = context.read<BarcodeViewModel>();
    final food = vm.foundFood;

    final defaultServing = food?.servingSize ?? 100.0;
    final scaled = food?.toFoodLogMap(defaultServing);

    _nameCtrl = TextEditingController(text: food?.displayName ?? '');
    _calCtrl = TextEditingController(
      text: scaled?['calories']?.toString() ?? '',
    );
    _proteinCtrl = TextEditingController(text: _fmt(scaled?['protein']));
    _carbsCtrl = TextEditingController(text: _fmt(scaled?['carbs']));
    _fatCtrl = TextEditingController(text: _fmt(scaled?['fat']));
    _servingCtrl = TextEditingController(
      text: defaultServing.toStringAsFixed(0),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    if (v is double) return v == 0 ? '' : v.toStringAsFixed(1);
    return v.toString();
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

    final grams = double.tryParse(value);
    if (grams == null || grams <= 0) return;

    final scaled = food.toFoodLogMap(grams);
    setState(() {
      final cal = scaled['calories'];
      if (cal != null) _calCtrl.text = cal.toString();
      _proteinCtrl.text = _fmt(scaled['protein']);
      _carbsCtrl.text = _fmt(scaled['carbs']);
      _fatCtrl.text = _fmt(scaled['fat']);
    });
  }

  Future<void> _save() async {
    final vm = context.read<BarcodeViewModel>();
    final uid = context.read<AuthViewModel>().currentUid ?? '';

    final ok = await vm.saveToFoodLog(
      uid: uid,
      foodName: _nameCtrl.text,
      calories: int.tryParse(_calCtrl.text) ?? 0,
      protein: double.tryParse(_proteinCtrl.text) ?? 0,
      carbs: double.tryParse(_carbsCtrl.text) ?? 0,
      fat: double.tryParse(_fatCtrl.text) ?? 0,
      servingSize: double.tryParse(_servingCtrl.text),
    );

    if (ok && mounted) Navigator.pop(context);
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: AppSpacing.lg),

              if (isNotFound)
                _NotFoundBanner(barcode: vm.lastBarcode ?? '')
              else if (food != null)
                _ProductBanner(food: food),

              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _servingCtrl,
                label: 'Serving Size',
                hint: 'grams (g)',
                icon: Icons.straighten,
                isNumber: true,
                onChanged: _onServingChanged,
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
}

class _ProductBanner extends StatelessWidget {
  final food;
  const _ProductBanner({required this.food});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: c.success.withOpacity(0.1),
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
              if (food.displayBrand.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  food.displayBrand,
                  style: AppTextStyles.caption.copyWith(color: c.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: food.isVerified
                      ? c.success.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
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
}

class _NotFoundBanner extends StatelessWidget {
  final String barcode;
  const _NotFoundBanner({required this.barcode});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.search_off,
                color: Colors.orange,
                size: 26,
              ),
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
            'This product isn\'t in the database yet. '
            'Enter the nutrition details manually from the product label.',
            style: AppTextStyles.caption.copyWith(
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
