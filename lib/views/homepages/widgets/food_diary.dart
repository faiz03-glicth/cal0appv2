import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/viewModels/foodlog_viewmodel.dart';
import 'package:cal0appv2/views/homepages/widgets/food_sheet.dart';

class FoodDiary extends StatelessWidget {
  const FoodDiary({super.key});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = Provider.of<FoodLogViewModel>(context);

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
                onPressed: () => _openAddSheet(context),
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
                      .map<Widget>((log) => _buildItem(context, log, vm, c))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    FoodLogModel log,
    FoodLogViewModel vm,
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
                  'F: ${log.fats.toStringAsFixed(1)}g',
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
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: c.textSecondary, size: 18),
            color: c.card,
            onSelected: (val) {
              if (val == 'edit') {
                vm.prefillForEdit(log);
                _openEditSheet(context, log);
              } else if (val == 'delete') {
                _confirmDelete(context, log, vm, c);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16, color: c.primary),
                    const SizedBox(width: 8),
                    Text('Edit', style: TextStyle(color: c.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: c.warning),
                    const SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: c.warning)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(C0Colors c) => Padding(
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

  void _openAddSheet(BuildContext context) {
    Provider.of<FoodLogViewModel>(context, listen: false).clearForm();
    _openSheet(context, isEdit: false);
  }

  void _openEditSheet(BuildContext context, FoodLogModel log) {
    _openSheet(context, isEdit: true, existing: log);
  }

  void _openSheet(
    BuildContext context, {
    required bool isEdit,
    FoodLogModel? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: Provider.of<FoodLogViewModel>(context, listen: false),
        child: FoodSheet(isEdit: isEdit, existing: existing),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    FoodLogModel log,
    FoodLogViewModel vm,
    C0Colors c,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Delete food?', style: TextStyle(color: c.textPrimary)),
        content: Text(
          'Remove "${log.foodLogName}" from your diary?',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              vm.deleteFoodLog(log.foodLogID);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: c.warning, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
