import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cal0appv2/viewModels/foodlog_viewmodel.dart';
import 'package:cal0appv2/views/homepages/widgets/macro_row.dart';
import 'package:cal0appv2/views/homepages/widgets/food_diary.dart';
import 'package:cal0appv2/views/homepages/widgets/date_strip.dart';
import 'package:cal0appv2/views/homepages/widgets/c0_app_bar.dart';
import 'package:cal0appv2/views/homepages/widgets/calorie_ring.dart';
import 'package:cal0appv2/viewModels/dashboard/dashboard_viewmodel.dart';
import 'package:cal0appv2/views/homepages/widgets/dashboard_header.dart';
import 'package:cal0appv2/views/homepages/widgets/nutrient_section.dart';

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

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final dashVm = Provider.of<DashboardViewModel>(context);
    final foodVm = Provider.of<FoodLogViewModel>(context);
    final uid = FirebaseAuth.instance.currentUser!.uid;

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
                    const DateStrip(),
                    CalorieRing(
                      totalCalories: foodVm.totalCalories,
                      target: dashVm.calorieTarget,
                    ),
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
