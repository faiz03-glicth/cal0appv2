import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/../views/homepages/widgets/macro_row.dart';
import '/../views/homepages/widgets/food_diary.dart';
import '/../views/homepages/widgets/date_strip.dart';
import '/../views/homepages/widgets/c0_app_bar.dart';
import '/../views/homepages/widgets/calorie_ring.dart';
import '/../viewModels/foodlog/foodlog_viewmodel.dart';
import '/../viewModels/dashboard/dashboard_viewmodel.dart';
import '/../views/homepages/widgets/nutrient_section.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    Future.microtask(() {
      if (!mounted) return;
      context.read<DashboardViewModel>().loadDashboard(uid);
      context.read<FoodLogViewModel>().loadFoodLogs();
    });
  }

  /// Human-readable label for the selected date.
  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);
    if (selected == today) return 'Today';
    if (selected == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(selected);
  }

  /// Called when the user taps a day in DateStrip.
  /// Updates BOTH viewmodels so the calorie target (user profile) and the
  /// food logs are always in sync with the selected date.
  void _onDateSelected(BuildContext context, DateTime date) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // FoodLogViewModel drives the diary list + macro/calorie totals.
    context.read<FoodLogViewModel>().selectDate(date);

    // DashboardViewModel drives the calorie *target* (from user profile).
    // We pass the date so it can store it internally if needed.
    context.read<DashboardViewModel>().loadDashboard(uid, date: date);
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final foodVm = Provider.of<FoodLogViewModel>(context);
    final dashVm = Provider.of<DashboardViewModel>(context);
    final selectedDate = foodVm.selectedDate;

    return Scaffold(
      backgroundColor: c.background,
      appBar: C0AppBar(title: 'Dashboard'),
      body: dashVm.isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : RefreshIndicator(
              color: c.primary,
              onRefresh: () async {
                await dashVm.loadDashboard(uid);
                await foodVm.loadFoodLogs();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DateStrip(
                      selectedDate: selectedDate,
                      onDateSelected: (date) => _onDateSelected(context, date),
                    ),
                    //New Feature for adding Today /Yesterday
                    //yes surr
                    // Small "Today / Yesterday / Mon, 14 Apr" label.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        _dateLabel(selectedDate),
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    CalorieRing(
                      totalCalories: foodVm.totalCalories,
                      target: dashVm.calorieTarget,
                    ),
                    //Macross bros
                    MacroRow(
                      totalProtein: foodVm.totalProtein,
                      totalCarbs: foodVm.totalCarbs,
                      totalFat: foodVm.totalFat,
                      targets: dashVm.macroTargets,
                    ),
                    const NutrientSection(),
                    const FoodDiary(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }
}
