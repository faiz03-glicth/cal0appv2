import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';

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

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = Provider.of<FoodLogViewModel>(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                widget.isEdit ? 'Edit Food' : 'Add Food',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Mode toggle — only for new entry
              if (!widget.isEdit)
                Row(
                  children: [
                    _modeChip(
                      'Search',
                      !vm.manualMode,
                      c,
                      () => vm.setManualMode(false),
                    ),
                    const SizedBox(width: 8),
                    _modeChip(
                      'Manual entry',
                      vm.manualMode,
                      c,
                      () => vm.setManualMode(true),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // ── Search mode ───────────────────────────────────────────────
              if (!vm.manualMode) ...[
                _buildField(
                  _searchCtrl,
                  'Search food...',
                  Icons.search,
                  c,
                  onChanged: vm.searchFood,
                ),
                if (vm.isSearching)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: c.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ...vm.searchResults.map(
                  (food) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      food['name'] ?? food['food_name'] ?? '',
                      style: TextStyle(color: c.textPrimary, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${food['calories'] ?? food['energy'] ?? 0} kcal',
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.add_circle_outline,
                      color: c.primary,
                      size: 20,
                    ),
                    onTap: () {
                      vm.selectFood(food);
                      _nameCtrl.text = vm.foodName;
                      _calCtrl.text = vm.calories;
                      _proteinCtrl.text = vm.protein > 0
                          ? vm.protein.toString()
                          : '';
                      _carbsCtrl.text = vm.carbs > 0 ? vm.carbs.toString() : '';
                      _fatCtrl.text = vm.fat > 0 ? vm.fat.toString() : '';
                    },
                  ),
                ),
              ],

              // ── Manual entry ──────────────────────────────────────────────
              if (vm.manualMode) ...[
                _buildField(
                  _nameCtrl,
                  'Food name',
                  Icons.fastfood,
                  c,
                  onChanged: vm.updateFoodName,
                ),
                _buildField(
                  _calCtrl,
                  'Calories (kcal)',
                  Icons.local_fire_department,
                  c,
                  isNumber: true,
                  onChanged: vm.updateCalories,
                ),
                const SizedBox(height: 4),
                Text(
                  'Macros (optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        _proteinCtrl,
                        'Protein',
                        Icons.fitness_center,
                        c,
                        isNumber: true,
                        onChanged: vm.updateProtein,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildField(
                        _carbsCtrl,
                        'Carbs',
                        Icons.grain,
                        c,
                        isNumber: true,
                        onChanged: vm.updateCarbs,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildField(
                        _fatCtrl,
                        'Fat',
                        Icons.water_drop,
                        c,
                        isNumber: true,
                        onChanged: vm.updateFat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Error
                if (vm.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      vm.errorMessage!,
                      style: TextStyle(color: c.warning, fontSize: 13),
                    ),
                  ),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: vm.isSaving || !vm.isFormValid
                        ? null
                        : () async {
                            bool ok;
                            if (widget.isEdit && widget.existing != null) {
                              ok = await vm.updateFoodLog(widget.existing!);
                            } else {
                              ok = await vm.addFoodLog();
                            }
                            if (ok && context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                    child: vm.isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            widget.isEdit ? 'Save Changes' : 'Add to Diary',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool active, C0Colors c, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.primary : c.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? c.primary : c.divider, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

  Widget _buildField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    C0Colors c, {
    bool isNumber = false,
    void Function(String)? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: c.primary, size: 18),
        filled: true,
        fillColor: c.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
    ),
  );
}
