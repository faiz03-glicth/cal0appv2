// lib/views/homepages/widgets/food_diary.dart

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/views/foodlog/food_history_view.dart';
import 'package:cal0appv2/views/homepages/widgets/food_sheet.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';
import 'package:cal0appv2/viewModels/foodlog/food_history_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';

class FoodDiary extends StatelessWidget {
  const FoodDiary({super.key});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = Provider.of<FoodLogViewModel>(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = vm.selectedDate;

    String diaryLabel;
    if (selected == today) {
      diaryLabel = "Today's Diary";
    } else if (selected == today.subtract(const Duration(days: 1))) {
      diaryLabel = "Yesterday's Diary";
    } else {
      diaryLabel = DateFormat('EEE, d MMM').format(selected);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                diaryLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: c.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider(
                      create: (_) => FoodHistoryViewModel(),
                      child: const FoodHistoryView(),
                    ),
                  ),
                ),
                icon: Icon(Icons.history, size: 14, color: c.primary),
                label: Text(
                  'History',
                  style: TextStyle(color: c.primary, fontSize: 13),
                ),
              ),
            ],
          ),

          // ── Error banner ──────────────────────────────────────────────────
          if (vm.errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.warning.withValues(alpha: 0.4)),
              ),
              child: Text(
                vm.errorMessage!,
                style: TextStyle(color: c.warning, fontSize: 12),
              ),
            ),

          // ── Content ───────────────────────────────────────────────────────
          if (vm.isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: c.primary,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (vm.foodLogs.isEmpty)
            _buildEmpty(c, vm.isToday, selected)
          else
            Column(
              children: vm.foodLogs
                  .map<Widget>((log) => _buildItem(context, log, vm, c))
                  .toList(),
            ),
        ],
      ),
    );
  }

  // ── Log item row ───────────────────────────────────────────────────────────
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
          // Icon — different for scanned vs manual
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: log.isScanned
                  ? c.primary.withValues(alpha: 0.12)
                  : c.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              log.isScanned ? Icons.qr_code_scanner : Icons.restaurant,
              size: 18,
              color: log.isScanned ? c.primary : c.success,
            ),
          ),
          const SizedBox(width: 12),
          // Name + macros + source badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.foodLogName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Source badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: log.isScanned
                            ? c.primary.withValues(alpha: 0.1)
                            : c.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.isScanned ? 'Scanned' : 'Manual',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: log.isScanned ? c.primary : c.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'P: ${log.protein.toStringAsFixed(1)}g  '
                  'C: ${log.carbs.toStringAsFixed(1)}g  '
                  'F: ${log.fats.toStringAsFixed(1)}g',
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              ],
            ),
          ),

          // Calories
          Text(
            '${log.calorieIntake} kcal',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: c.primary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),

          // Edit / Delete menu
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

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmpty(C0Colors c, bool isToday, DateTime date) {
    final label = isToday
        ? 'No food logged today.\nTap + Add to start tracking!'
        : 'No food logged on ${DateFormat('EEE, d MMM').format(date)}.\n'
              'Tap + Add to fill it in.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              isToday ? Icons.no_food : Icons.history,
              size: 40,
              color: c.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sheet helpers ──────────────────────────────────────────────────────────
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
    final uid = context.read<AuthViewModel>().currentUid ?? '';
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
              vm.deleteFoodLog(uid: uid, foodLogID: log.foodLogID);
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
