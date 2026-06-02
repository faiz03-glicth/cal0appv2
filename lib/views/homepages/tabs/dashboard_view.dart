import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/nutrient_totals.dart';
import '/../views/widgets/macro_row.dart';
import '/../views/widgets/food_diary.dart';
import '/../views/widgets/date_strip.dart';
import '/../views/widgets/c0_app_bar.dart';
import '/../views/widgets/calorie_ring.dart';
import '/../views/widgets/tdee_info_card.dart';
import '/../viewModels/foodlog/foodlog_viewmodel.dart';
import '/../viewModels/dashboard/dashboard_viewmodel.dart';
import '/../views/widgets/nutrient_section.dart';
import '/../viewModels/viewauth/auth_viewmodel.dart';

// ── UC015 AF1: Dashboard content filter ───────────────────────────────────

enum DashboardFilter { all, calories, macros, nutrients }

// ── Main tab ───────────────────────────────────────────────────────────────

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  DashboardFilter _activeFilter = DashboardFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final uid = context.read<AuthViewModel>().currentUid ?? '';
      if (uid.isEmpty) return;
      context.read<DashboardViewModel>().loadDashboard(uid);
      context.read<FoodLogViewModel>().loadFoodLogs(uid: uid);
    });
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);
    if (selected == today) return 'Today';
    if (selected == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(selected);
  }

  Future<void> _onDateSelected(BuildContext context, DateTime date) async {
    final uid = context.read<AuthViewModel>().currentUid ?? '';
    if (uid.isEmpty) return;
    await context.read<FoodLogViewModel>().changeSelectedDate(date, uid: uid);
  }

  bool get _showCalories =>
      _activeFilter == DashboardFilter.all ||
      _activeFilter == DashboardFilter.calories;
  bool get _showMacros =>
      _activeFilter == DashboardFilter.all ||
      _activeFilter == DashboardFilter.macros;
  bool get _showNutrients =>
      _activeFilter == DashboardFilter.all ||
      _activeFilter == DashboardFilter.nutrients;

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final uid = context.read<AuthViewModel>().currentUid ?? '';
    final dashVm = context.watch<DashboardViewModel>();

    return Scaffold(
      backgroundColor: c.background,
      appBar: C0AppBar(title: 'Dashboard'),
      body: dashVm.isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : RefreshIndicator(
              color: c.primary,
              onRefresh: () async {
                await dashVm.refreshDashboard(uid);
                await context.read<FoodLogViewModel>().loadFoodLogs(uid: uid);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Date strip ──────────────────────────────────────
                    Selector<FoodLogViewModel, DateTime>(
                      selector: (_, vm) => vm.selectedDate,
                      builder: (ctx, selectedDate, _) => DateStrip(
                        selectedDate: selectedDate,
                        onDateSelected: (d) => _onDateSelected(ctx, d),
                      ),
                    ),

                    // ── Date label ──────────────────────────────────────
                    Selector<FoodLogViewModel, DateTime>(
                      selector: (_, vm) => vm.selectedDate,
                      builder: (ctx, selectedDate, _) => Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.sm,
                          AppSpacing.xl,
                          0,
                        ),
                        child: Text(
                          _dateLabel(selectedDate),
                          style: AppTextStyles.caption.copyWith(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                    // ── Filter chips ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.md,
                        AppSpacing.xl,
                        0,
                      ),
                      child: _DashboardFilterRow(
                        active: _activeFilter,
                        onChanged: (f) => setState(() => _activeFilter = f),
                      ),
                    ),

                    // ── Calorie ring ────────────────────────────────────
                    if (_showCalories)
                      Selector<FoodLogViewModel, int>(
                        selector: (_, vm) => vm.totalCalories,
                        builder: (_, cal, _) => CalorieRing(
                          totalCalories: cal,
                          target: dashVm.calorieTarget,
                        ),
                      ),

                    // ── TDEE info card ──────────────────────────────────
                    if (_showCalories) const TdeeInfoCard(),

                    if (_showCalories) const SizedBox(height: AppSpacing.md),

                    // ── Macro row ───────────────────────────────────────
                    if (_showMacros)
                      Selector<FoodLogViewModel, NutrientTotals>(
                        selector: (_, vm) => vm.totals,
                        builder: (_, totals, _) => MacroRow(
                          totalProtein: totals.protein,
                          totalCarbs: totals.carbs,
                          totalFat: totals.fat,
                          targets: dashVm.macroTargets,
                        ),
                      ),

                    if (_showMacros) const SizedBox(height: AppSpacing.md),

                    // ── Full nutrient panel ─────────────────────────────
                    if (_showNutrients) const NutrientSection(),

                    // ── Food diary ──────────────────────────────────────
                    const FoodDiary(),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Filter row ─────────────────────────────────────────────────────────────

class _DashboardFilterRow extends StatelessWidget {
  final DashboardFilter active;
  final ValueChanged<DashboardFilter> onChanged;

  const _DashboardFilterRow({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);

    const filters = [
      (DashboardFilter.all, 'All', Icons.grid_view_rounded),
      (DashboardFilter.calories, 'Calories', Icons.local_fire_department),
      (DashboardFilter.macros, 'Macros', Icons.bar_chart_rounded),
      (DashboardFilter.nutrients, 'Nutrients', Icons.science_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = active == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => onChanged(f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? c.primary : c.card,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isSelected ? c.primary : c.divider,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: c.primary.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f.$3,
                      size: 13,
                      color: isSelected ? Colors.white : c.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      f.$2,
                      style: AppTextStyles.caption.copyWith(
                        color: isSelected ? Colors.white : c.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
