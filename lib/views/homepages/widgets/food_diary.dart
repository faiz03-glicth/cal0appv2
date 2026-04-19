import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/viewModels/dashboard/dashboard_viewmodel.dart';

class FoodDiary extends StatelessWidget {
  final List<dynamic> foodLogs;
  final VoidCallback onAdd;

  const FoodDiary({super.key, required this.foodLogs, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = Provider.of<DashboardViewModel>(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
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
          // Header with "Food Diary" title and "Add" button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Food Diary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: c.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddFoodSheet(context, vm, c),
                icon: Icon(Icons.add, size: 16, color: c.primary),
                label: Text(
                  'Add',
                  style: TextStyle(color: c.primary, fontSize: 13),
                ),
              ),
            ],
          ),
          if (vm.errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.warning.withOpacity(0.4)),
              ),
              child: Text(
                vm.errorMessage!,
                style: TextStyle(color: c.warning, fontSize: 12),
              ),
            ),
          vm.isLoading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      color: c.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : vm.foodLogs.isEmpty
              ? _buildEmpty(c)
              : Column(
                  children: vm.foodLogs
                      .map<Widget>((log) => _buildItem(context, log, c))
                      .toList(),
                ),
        ],
      ),
    );
  }

  // ── Add food bottom sheet ─────────────────────────────────────────────────
  void _showAddFoodSheet(
    BuildContext context,
    DashboardViewModel vm,
    C0Colors c,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFoodSheet(vm: vm),
    );
  }

  Widget _buildItem(
    BuildContext context,
    dynamic log,
    DashboardViewModel vm,
    C0Colors c,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.restaurant, size: 18, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.foodLogName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  'P: ${log.protein.toStringAsFixed(1)}g  '
                  'C: ${log.carbs.toStringAsFixed(1)}g  '
                  'F: ${log.fat.toStringAsFixed(1)}g',
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${log.calorieIntake} kcal',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: c.primary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(C0Colors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.no_food, size: 40, color: c.textSecondary),
            const SizedBox(height: 8),
            Text(
              'No food logged today',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
