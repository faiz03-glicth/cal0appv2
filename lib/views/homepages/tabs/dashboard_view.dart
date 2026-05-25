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
import '/../viewModels/foodlog/foodlog_viewmodel.dart';
import '/../viewModels/dashboard/dashboard_viewmodel.dart';
import '/../views/widgets/nutrient_section.dart';
import '/../viewModels/viewauth/auth_viewmodel.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final uid = context.read<AuthViewModel>().currentUid ?? '';
      if (uid.isEmpty) return;
      // loadDashboard is a no-op if user is already cached
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
    // Only reload food logs — user profile doesn't change per date
    await context.read<FoodLogViewModel>().changeSelectedDate(date, uid: uid);
  }

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

                    // ── Calorie ring ────────────────────────────────────
                    // Selector: rebuilds ONLY when calories or target change
                    Selector<FoodLogViewModel, int>(
                      selector: (_, vm) => vm.totalCalories,
                      builder: (_, cal, __) => CalorieRing(
                        totalCalories: cal,
                        target: dashVm.calorieTarget,
                      ),
                    ),

                    // ── Macro row ───────────────────────────────────────
                    // Selector: rebuilds only when NutrientTotals changes
                    Selector<FoodLogViewModel, NutrientTotals>(
                      selector: (_, vm) => vm.totals,
                      builder: (_, totals, __) => MacroRow(
                        totalProtein: totals.protein,
                        totalCarbs: totals.carbs,
                        totalFat: totals.fat,
                        targets: dashVm.macroTargets,
                      ),
                    ),

                    // ── Nutrient section (sugar, sodium, etc.) ──────────
                    // NutrientSection uses its own Selector internally
                    const NutrientSection(),

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
