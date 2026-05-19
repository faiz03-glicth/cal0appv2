import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/scan_result_model.dart';
import 'package:cal0appv2/viewModels/scan/scan_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';

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
  late final TextEditingController _serving;
  bool _addToFoodLog = true;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _name = TextEditingController(text: r.productName);
    _calories = TextEditingController(
      text: r.calories > 0 ? '${r.calories}' : '',
    );
    _protein = TextEditingController(text: r.protein > 0 ? '${r.protein}' : '');
    _carbs = TextEditingController(text: r.carbs > 0 ? '${r.carbs}' : '');
    _fat = TextEditingController(text: r.fat > 0 ? '${r.fat}' : '');
    _serving = TextEditingController(
      text: r.servingSize != null ? '${r.servingSize}' : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _serving.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = context.watch<ScanViewModel>();

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

              // Header row
              Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: c.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confirm Scan Results',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  // Confidence badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _confidenceColor(
                        widget.initial.extractionConfidence,
                        c,
                      ).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(widget.initial.extractionConfidence * 100).toStringAsFixed(0)}% match',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _confidenceColor(
                          widget.initial.extractionConfidence,
                          c,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Review and edit before saving. '
                'Fields are auto-filled from your label.',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
              const SizedBox(height: 16),

              // Fields
              _field(_name, 'Product / Supplement Name', Icons.label, c),
              _field(
                _serving,
                'Serving Size (g)',
                Icons.straighten,
                c,
                isNumber: true,
              ),

              Text(
                'Macros per serving',
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
                    child: _field(
                      _calories,
                      'Calories',
                      Icons.local_fire_department,
                      c,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(
                      _protein,
                      'Protein (g)',
                      Icons.fitness_center,
                      c,
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _carbs,
                      'Carbs (g)',
                      Icons.grain,
                      c,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(
                      _fat,
                      'Fat (g)',
                      Icons.water_drop,
                      c,
                      isNumber: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Add to food diary toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.divider),
                ),
                child: Row(
                  children: [
                    Icon(Icons.book, size: 18, color: c.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Add to today's food diary",
                        style: TextStyle(color: c.textPrimary, fontSize: 14),
                      ),
                    ),
                    Switch(
                      value: _addToFoodLog,
                      onChanged: (v) => setState(() => _addToFoodLog = v),
                      activeColor: c.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Error banner
              if (vm.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    vm.errorMessage!,
                    style: TextStyle(color: c.warning, fontSize: 13),
                  ),
                ),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: vm.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(
                    vm.isSaving ? 'Saving...' : 'Save Result',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: vm.isSaving ? null : () => _save(context, vm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _save(BuildContext context, ScanViewModel vm) async {
    final uid = context.read<AuthViewModel>().currentUid ?? '';
    if (uid.isEmpty) return;

    final confirmed = widget.initial.copyWith(
      productName: _name.text.trim(),
      calories: int.tryParse(_calories.text) ?? widget.initial.calories,
      protein: double.tryParse(_protein.text) ?? widget.initial.protein,
      carbs: double.tryParse(_carbs.text) ?? widget.initial.carbs,
      fat: double.tryParse(_fat.text) ?? widget.initial.fat,
      servingSize: double.tryParse(_serving.text),
    );

    final ok = await vm.saveScanResult(
      uid: uid,
      confirmed: confirmed,
      addToFoodLog: _addToFoodLog,
    );

    if (ok && context.mounted) Navigator.pop(context);
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    C0Colors c, {
    bool isNumber = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: c.primary, size: 18),
        filled: true,
        fillColor: c.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
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

  Color _confidenceColor(double conf, C0Colors c) {
    if (conf >= 0.7) return c.success;
    if (conf >= 0.4) return Colors.orange;
    return c.warning;
  }
}
