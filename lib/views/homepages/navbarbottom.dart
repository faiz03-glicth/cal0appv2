import 'package:cal0appv2/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '/../views/users/userprofile_view.dart';
import '/../views/homepages/tabs/home_tabs.dart';
import '/../views/homepages/tabs/dashboard_view.dart';
import '/../views/widgets/food_sheet.dart';
import '/../views/barcode/barcode_scanner_view.dart';
import '/../viewModels/scan/barcode_viewmodel.dart';
import '/../viewModels/scan/scan_viewmodel.dart';
import '/../viewModels/viewauth/auth_viewmodel.dart';
import '/../viewModels/foodlog/foodlog_viewmodel.dart';
import '/../views/widgets/scan_confirm_sheet.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});
  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _currentIndex = 0;

  // Only 3 tabs now — Scan tab removed
  final List<Widget> _pages = [
    const HomeTab(),
    const DashboardTab(),
    const UserProfileView(),
  ];

  void _openActionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFoodModal(),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required C0Colors c,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 65,
        height: 56, // ADD fixed height
        child: Column(
          mainAxisSize: MainAxisSize.min, // ADD this
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? c.primary : c.slate,
              size: 22,
            ), // reduce from 24
            const SizedBox(height: 2), // reduce from 4
            Text(
              label,
              style: TextStyle(
                color: isSelected ? c.primary : c.slate,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openActionModal(context),
        backgroundColor: c.primary,
        elevation: 6,
        shape: const CircleBorder(),
        tooltip: 'Add food',
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      bottomNavigationBar: BottomAppBar(
        color: c.card,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 8,
        padding: EdgeInsets.zero,
        height: 60, // ADD explicit height
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildNavItem(icon: Icons.home, label: 'Home', index: 0, c: c),
                const SizedBox(width: 8),
                _buildNavItem(
                  icon: Icons.menu_book_rounded,
                  label: 'Diary',
                  index: 1,
                  c: c,
                ),
              ],
            ),
            const SizedBox(width: 80),
            Row(
              children: [
                _buildNavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  index: 2,
                  c: c,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Food Modal ─────────────────────────────────────────────────────────

class _AddFoodModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text(
            'Add food',
            style: AppTextStyles.title.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how to log',
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _ActionCard(
                icon: Icons.search,
                label: 'Search food',
                subtitle: 'Manual or API',
                iconBg: const Color(0xFFEBF3FF),
                iconColor: const Color(0xFF185FA5),
                onTap: () {
                  final foodLogVm = context
                      .read<FoodLogViewModel>(); // capture BEFORE pop
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ChangeNotifierProvider.value(
                      value: foodLogVm, // use captured reference, not context
                      child: const FoodSheet(isEdit: false),
                    ),
                  );
                },
              ),
              _ActionCard(
                icon: Icons.barcode_reader,
                label: 'Scan barcode',
                subtitle: 'Product lookup',
                iconBg: const Color(0xFFEAF3DE),
                iconColor: const Color(0xFF3B6D11),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: context.read<BarcodeViewModel>(),
                        child: const BarcodeScannerView(),
                      ),
                    ),
                  );
                },
              ),
              _ActionCard(
                icon: Icons.camera_alt_outlined,
                label: 'Photo log',
                subtitle: 'OCR label scan',
                iconBg: const Color(0xFFFAEEDA),
                iconColor: const Color(0xFF854F0B),
                onTap: () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 90,
                  );
                  if (picked == null || !context.mounted) return;
                  final vm = context.read<ScanViewModel>();
                  await vm.scanImage(File(picked.path));
                  if (!context.mounted) return;
                  if (vm.extractedResult != null) {
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
                },
              ),
              _ActionCard(
                icon: Icons.science_outlined,
                label: 'Supplement',
                subtitle: 'Whey / protein',
                iconBg: const Color(0xFFEEEDFE),
                iconColor: const Color(0xFF534AB7),
                onTap: () {
                  final foodLogVm = context.read<FoodLogViewModel>();
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ChangeNotifierProvider.value(
                      value: foodLogVm,
                      child: const FoodSheet(isEdit: false),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: c.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodyCompact.copyWith(
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: AppTextStyles.micro.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
