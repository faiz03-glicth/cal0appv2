import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/views/widgets/c0_app_bar.dart';
import 'package:cal0appv2/views/widgets/scan_confirm_sheet.dart';
import 'package:cal0appv2/viewModels/scan/scan_viewmodel.dart';

class ScanTab extends StatelessWidget {
  const ScanTab({super.key});

  Future<void> _pickAndScan(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null || !context.mounted) return;
    await context.read<ScanViewModel>().scanImage(File(picked.path));
  }

  void _openConfirmSheet(BuildContext context) {
    final vm = context.read<ScanViewModel>();
    if (vm.extractedResult == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: ScanConfirmSheet(initial: vm.extractedResult!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = Provider.of<ScanViewModel>(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: C0AppBar(title: 'Scan Label'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Camera / Gallery buttons ───────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    onPressed: vm.isScanning || vm.isAnalyzing
                        ? null
                        : () => _pickAndScan(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.primary),
                      foregroundColor: c.primary,
                    ),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    onPressed: vm.isScanning || vm.isAnalyzing
                        ? null
                        : () => _pickAndScan(context, ImageSource.gallery),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.barcode_reader),
                  label: const Text('Barcode'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BarcodeScannerView(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Loading: OCR ───────────────────────────────────────────────
            if (vm.isScanning) _loadingCard('Reading label text...', c),

            // ── Loading: AI ────────────────────────────────────────────────
            if (vm.isAnalyzing) _loadingCard('AI analyzing ingredients...', c),

            // ── Error ──────────────────────────────────────────────────────
            if (vm.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.warning.withOpacity(0.4)),
                ),
                child: Text(
                  vm.errorMessage!,
                  style: TextStyle(color: c.warning),
                ),
              ),

            // ── Success ────────────────────────────────────────────────────
            if (vm.successMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.success.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: c.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      vm.successMessage!,
                      style: TextStyle(
                        color: c.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Results ────────────────────────────────────────────────────
            if (vm.scannedText != null &&
                !vm.isScanning &&
                !vm.isAnalyzing) ...[
              // AI verdict banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: vm.hasSuspiciousIngredients
                      ? c.warning.withOpacity(0.12)
                      : c.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: vm.hasSuspiciousIngredients ? c.warning : c.success,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      vm.hasSuspiciousIngredients
                          ? Icons.warning_rounded
                          : Icons.check_circle,
                      color: vm.hasSuspiciousIngredients
                          ? c.warning
                          : c.success,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        vm.verdictLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: vm.hasSuspiciousIngredients
                              ? c.warning
                              : c.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Extracted nutrition card
              if (vm.extractedResult != null &&
                  vm.extractedResult!.hasUsefulData)
                _nutritionCard(vm, c),

              const SizedBox(height: 12),

              // Flagged ingredients — reads from extractedResult, not a
              // separate getter that no longer exists
              if (vm.hasSuspiciousIngredients &&
                  vm.extractedResult?.ingredientText.isNotEmpty == true) ...[
                Text(
                  'Flagged Ingredient Section',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: c.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: c.warning),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          vm.extractedResult!.ingredientText,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Low confidence warning
              if (vm.extractedResult != null &&
                  vm.extractedResult!.extractionConfidence < 0.4)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Label was partially read. '
                          'Please review and edit values before saving.',
                          style: TextStyle(color: c.textPrimary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Review & Save'),
                      onPressed: () => _openConfirmSheet(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.divider),
                      foregroundColor: c.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Clear'),
                    onPressed: vm.clearScan,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Raw OCR text collapsible
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Raw OCR Text',
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.divider),
                    ),
                    child: Text(
                      vm.scannedText!,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  Widget _loadingCard(String label, C0Colors c) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: c.textSecondary)),
      ],
    ),
  );

  Widget _nutritionCard(ScanViewModel vm, C0Colors c) {
    final r = vm.extractedResult!;
    return Container(
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_menu, color: c.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                'Extracted Nutrition',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(r.extractionConfidence * 100).toStringAsFixed(0)}% confidence',
                  style: TextStyle(
                    fontSize: 10,
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (r.productName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r.productName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (r.servingSize != null) ...[
            const SizedBox(height: 4),
            Text(
              'Per ${r.servingSize}${r.servingUnit} serving',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _macroChip('Calories', '${r.calories}', c.primary, c),
              _macroChip(
                'Protein',
                '${r.protein.toStringAsFixed(1)}g',
                c.success,
                c,
              ),
              _macroChip(
                'Carbs',
                '${r.carbs.toStringAsFixed(1)}g',
                Colors.orange,
                c,
              ),
              _macroChip('Fat', '${r.fat.toStringAsFixed(1)}g', c.slate, c),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, String value, Color color, C0Colors c) =>
      Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: c.textSecondary)),
        ],
      );
}
