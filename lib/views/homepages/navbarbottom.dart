import '/../theme/app_theme.dart';
import 'package:flutter/material.dart';
import '/../views/users/userprofile_view.dart';
import '/../views/homepages/tabs/scan_tabs.dart';
import '/../views/homepages/tabs/home_tabs.dart';
import '/../views/homepages/widgets/food_sheet.dart';
import '/../views/homepages/tabs/dashboard_view.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeTab(),
    const DashboardTab(),
    const ScanTab(),
    const UserProfileView(),
  ];

  void _openAddFoodModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FoodSheet(isEdit: false),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required var c,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 65, // Fixed width prevents shifting
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? c.primary : c.slate, size: 24),
            const SizedBox(height: 4),
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
        onPressed: () => _openAddFoodModal(context),
        backgroundColor: c.primary,
        elevation: 6,
        shape: const CircleBorder(),
        tooltip: 'Add Food Log',
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      // ────────────────────────────────────────────────────────────────────────
      bottomNavigationBar: BottomAppBar(
        color: c.card,
        shape: const CircularNotchedRectangle(), // Creates the cutout
        notchMargin: 8.0, // Space between the button and the bar
        elevation: 8,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Pushes to edges
          children: [
            Row(
              children: [
                _buildNavItem(icon: Icons.home, label: 'Home', index: 0, c: c),
                const SizedBox(width: 8),
                _buildNavItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  index: 1,
                  c: c,
                ),
              ],
            ),
            Row(
              children: [
                _buildNavItem(
                  icon: Icons.qr_code_scanner,
                  label: 'Scan',
                  index: 2,
                  c: c,
                ),
                const SizedBox(width: 8),
                _buildNavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  index: 3,
                  c: c,
                ),
              ],
            ),
          ],
        ),
      ),
      // ────────────────────────────────────────────────────────────────────────
    );
  }
}
