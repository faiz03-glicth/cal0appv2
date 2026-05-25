import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/views/foodlog/food_history_view.dart';
import 'package:cal0appv2/views/widgets/food_sheet.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';
import 'package:cal0appv2/viewModels/foodlog/food_history_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';
import 'package:cal0appv2/views/widgets/app_message_banner.dart';
import 'package:cal0appv2/views/widgets/source_badge.dart';

class FoodDiary extends StatelessWidget {
  const FoodDiary({super.key});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = Provider.of<FoodLogViewModel>(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = vm.selectedDate;

    final String diaryLabel;
    if (selected == today) {
      diaryLabel = "Today's Diary";
    } else if (selected == today.subtract(const Duration(days: 1))) {
      diaryLabel = "Yesterday's Diary";
    } else {
      diaryLabel = DateFormat('EEE, d MMM').format(selected);
    }

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                diaryLabel,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
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
                icon: Icon(Icons.history, size: AppSizes.miniIconSize, color: c.primary),
                label: Text(
                  'History',
                  style: AppTextStyles.caption.copyWith(color: c.primary),
                ),
              ),
            ],
          ),

          // Error banner
          if (vm.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppMessageBanner.error(message: vm.errorMessage!),
          ],

          // Content
          if (vm.isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
              ),
            )
          else if (vm.foodLogs.isEmpty)
            _EmptyState(isToday: vm.isToday, date: selected)
          else
            Column(
              children: vm.foodLogs
                  .map<Widget>((log) => _DiaryItem(log: log, vm: vm))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ── Diary item row ─────────────────────────────────────────────────────────

class _DiaryItem extends StatelessWidget {
  final FoodLogModel log;
  final FoodLogViewModel vm;
  const _DiaryItem({required this.log, required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider, width: 1)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: log.isScanned
                  ? c.primary.withValues(alpha: 0.12)
                  : c.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.sm + 2),
            ),
            child: Icon(
              log.isScanned ? Icons.qr_code_scanner : Icons.restaurant,
              size: AppSizes.smallIconSize,
              color: log.isScanned ? c.primary : c.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

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
                        style: AppTextStyles.bodyCompact.copyWith(
                          fontWeight: FontWeight.w500,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SourceBadge(source: log.source, dense: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'P: ${log.protein.toStringAsFixed(1)}g  '
                  'C: ${log.carbs.toStringAsFixed(1)}g  '
                  'F: ${log.fats.toStringAsFixed(1)}g',
                  style: AppTextStyles.tiny.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),

          // Calories
          Text(
            '${log.calorieIntake} kcal',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: c.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Edit / Delete menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: c.textSecondary, size: AppSizes.smallIconSize),
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
                    Icon(Icons.edit, size: AppSizes.miniIconSize + 2, color: c.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Edit', style: TextStyle(color: c.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: AppSizes.miniIconSize + 2, color: c.warning),
                    const SizedBox(width: AppSpacing.sm),
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

  void _openEditSheet(BuildContext context, FoodLogModel log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: Provider.of<FoodLogViewModel>(context, listen: false),
        child: FoodSheet(isEdit: true, existing: log),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context, FoodLogModel log, FoodLogViewModel vm, C0Colors c,
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
            child: Text('Delete', style: TextStyle(color: c.warning, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isToday;
  final DateTime date;
  const _EmptyState({required this.isToday, required this.date});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final label = isToday
        ? 'No food logged today.\nTap + Add to start tracking!'
        : 'No food logged on ${DateFormat('EEE, d MMM').format(date)}.\nTap + Add to fill it in.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Column(
          children: [
            Icon(isToday ? Icons.no_food : Icons.history, size: 40, color: c.textSecondary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: c.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}