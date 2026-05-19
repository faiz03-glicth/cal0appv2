// lib/views/foodlog/food_detail_view.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/viewModels/foodlog/food_history_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';

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
            icon: const Icon(Icons.edit, color: Colors.white, size: 20),
            onPressed: () => _openEdit(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scanned image (if available)
            if (_log.isScanned &&
                _log.imagePath != null &&
                _log.imagePath!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_log.imagePath!),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (_log.isScanned && _log.imagePath != null)
              const SizedBox(height: 16),

            // Source + date card
            _infoCard(c, [
              _row(
                'Source',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _log.isScanned ? Icons.qr_code_scanner : Icons.edit,
                      size: 14,
                      color: _log.isScanned ? c.primary : c.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _log.isScanned ? 'Scanned via OCR' : 'Manual Entry',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _log.isScanned ? c.primary : c.success,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _row(
                'Date',
                Text(
                  DateFormat('d MMM yyyy, h:mm a').format(_log.loggedAt),
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                ),
              ),
              if (_log.servingSize != null)
                _row(
                  'Serving',
                  Text(
                    '${_log.servingSize}${_log.servingUnit}',
                    style: TextStyle(color: c.textPrimary, fontSize: 13),
                  ),
                ),
              if (_log.isScanned && _log.scanConfidence != null)
                _row(
                  'OCR Confidence',
                  Text(
                    '${(_log.scanConfidence! * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: c.textPrimary, fontSize: 13),
                  ),
                ),
            ]),
            const SizedBox(height: 12),

            // AI result (scanned only)
            if (_log.isScanned && _log.scanAnalysisResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (isSpiked ? c.warning : c.success).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isSpiked ? c.warning : c.success).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSpiked ? Icons.warning_rounded : Icons.shield,
                      color: isSpiked ? c.warning : c.success,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Analysis',
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _log.scanAnalysisResult!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSpiked ? c.warning : c.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_log.isScanned) const SizedBox(height: 12),

            // Macros card
            _sectionTitle('Nutrition', c),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _macroBar(
                    'Calories',
                    _log.calorieIntake.toDouble(),
                    2000,
                    'kcal',
                    c.primary,
                    c,
                  ),
                  _macroBar('Protein', _log.protein, 150, 'g', c.success, c),
                  _macroBar(
                    'Carbohydrates',
                    _log.carbs,
                    250,
                    'g',
                    Colors.orange,
                    c,
                  ),
                  _macroBar('Fat', _log.fats, 65, 'g', c.slate, c),
                  if (_log.sugar > 0)
                    _macroBar('Sugar', _log.sugar, 50, 'g', Colors.pink, c),
                  if (_log.sodium > 0)
                    _macroBar(
                      'Sodium',
                      _log.sodium,
                      2300,
                      'mg',
                      Colors.deepPurple,
                      c,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  Widget _sectionTitle(String t, C0Colors c) => Text(
    t,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: c.textSecondary,
      letterSpacing: 0.5,
    ),
  );

  Widget _infoCard(C0Colors c, List<Widget> rows) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(children: rows),
  );

  Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: C0Theme.slateGrey, fontSize: 13),
        ),
        value,
      ],
    ),
  );

  Widget _macroBar(
    String label,
    double value,
    double max,
    String unit,
    Color color,
    C0Colors c,
  ) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: c.textPrimary)),
              Text(
                '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: color.withOpacity(0.12),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _openEdit(BuildContext context) {
    // Simple edit dialog for name + calories
    final c = C0Theme.of(context);
    final nameCtrl = TextEditingController(text: _log.foodLogName);
    final calCtrl = TextEditingController(text: '${_log.calorieIntake}');
    final proCtrl = TextEditingController(text: '${_log.protein}');
    final carbCtrl = TextEditingController(text: '${_log.carbs}');
    final fatCtrl = TextEditingController(text: '${_log.fats}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Edit Entry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _editField(nameCtrl, 'Name', Icons.label, c),
              _editField(
                calCtrl,
                'Calories',
                Icons.local_fire_department,
                c,
                number: true,
              ),
              Row(
                children: [
                  Expanded(
                    child: _editField(
                      proCtrl,
                      'Protein g',
                      Icons.fitness_center,
                      c,
                      number: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _editField(
                      carbCtrl,
                      'Carbs g',
                      Icons.grain,
                      c,
                      number: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _editField(
                      fatCtrl,
                      'Fat g',
                      Icons.water_drop,
                      c,
                      number: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final uid = context.read<AuthViewModel>().currentUid ?? '';
                    _log.foodLogName = nameCtrl.text.trim();
                    _log.calorieIntake =
                        int.tryParse(calCtrl.text) ?? _log.calorieIntake;
                    _log.protein =
                        double.tryParse(proCtrl.text) ?? _log.protein;
                    _log.carbs = double.tryParse(carbCtrl.text) ?? _log.carbs;
                    _log.fats = double.tryParse(fatCtrl.text) ?? _log.fats;
                    await context.read<FoodHistoryViewModel>().update(
                      uid,
                      _log,
                    );
                    setState(() {});
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    C0Colors c, {
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 12),
        prefixIcon: Icon(icon, color: c.primary, size: 16),
        filled: true,
        fillColor: c.background,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.divider),
        ),
      ),
    ),
  );
}
