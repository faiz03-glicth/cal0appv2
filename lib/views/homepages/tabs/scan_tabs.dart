import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/views/homepages/widgets/c0_app_bar.dart';
import 'package:cal0appv2/viewModels/scan/scan_viewmodel.dart';

class ScanTab extends StatelessWidget {
  const ScanTab({super.key});

  Future<void> _pickAndScan(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null || !context.mounted) return;
    await context.read<ScanViewModel>().scanImage(File(picked.path));
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
            // Camera / Gallery buttons
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
                    onPressed: vm.isScanning
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
                    onPressed: vm.isScanning
                        ? null
                        : () => _pickAndScan(context, ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Loading
            if (vm.isScanning)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: c.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Scanning label...',
                      style: TextStyle(color: c.textSecondary),
                    ),
                  ],
                ),
              ),

            // Error
            if (vm.errorMessage != null)
              Container(
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

            // Results
            if (vm.scannedText != null && !vm.isScanning) ...[
              // Verdict banner
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
                        vm.hasSuspiciousIngredients
                            ? 'Potential amino spiking detected!'
                            : 'No suspicious ingredients found.',
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
              const SizedBox(height: 16),

              // Flagged ingredients
              if (vm.hasSuspiciousIngredients) ...[
                Text(
                  'Flagged Ingredients',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ...vm.flaggedIngredients.map(
                  (i) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: c.warning),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            i,
                            style: TextStyle(color: c.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Raw OCR text
              Text(
                'Extracted Text',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
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
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: vm.clearScan,
                  child: const Text('Clear'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
