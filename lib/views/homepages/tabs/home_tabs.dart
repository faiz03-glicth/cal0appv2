import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/usermodel/user_viewmodel.dart';
import 'package:cal0appv2/viewModels/foodlog/food_history_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/views/widgets/c0_app_bar.dart';
import 'package:cal0appv2/views/widgets/recent_scan_carousel.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';
import 'package:cal0appv2/views/debug/debug_view.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';
import 'package:cal0appv2/viewModels/dashboard/dashboard_viewmodel.dart';
import 'package:cal0appv2/views/users/userprofile_view.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final uid = context.read<AuthViewModel>().currentUid ?? '';
      if (uid.isNotEmpty) {
        context.read<FoodHistoryViewModel>().load(uid);
        // ADD these two lines:
        context.read<DashboardViewModel>().loadDashboard(uid);
        context.read<FoodLogViewModel>().loadFoodLogs(uid: uid);
      }
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = C0Theme.of(context);
    final userVm = context.watch<UserViewModel>();
    final histVm = context.watch<FoodHistoryViewModel>();
    final name = userVm.userName.isNotEmpty ? userVm.userName : 'there';
    final scanned = histVm.filtered.where((l) => l.isScanned).toList();

    return Scaffold(
      backgroundColor: c.background,
      appBar: C0AppBar(
        title: 'C0 App',
        actions: [
          if (kDebugBuild)
            IconButton(
              icon: const Icon(
                Icons.bug_report_outlined,
                color: Colors.white70,
              ),
              tooltip: 'Debug',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugView()),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileView()),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: c.primary,
        onRefresh: () async {
          final uid = context.read<AuthViewModel>().currentUid ?? '';
          if (uid.isNotEmpty) await histVm.load(uid);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero greeting ──────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.primary, c.primary.withValues(alpha: 0.7)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      name,
                      style: AppTextStyles.heading.copyWith(
                        color: Colors.white,
                        fontSize: 30,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      children: [
                        _HeroStat(
                          Icons.qr_code_scanner,
                          '${scanned.length}',
                          'Scans',
                        ),
                        const SizedBox(width: AppSpacing.xxl),
                        _HeroStat(
                          Icons.restaurant_outlined,
                          '${histVm.filtered.length}',
                          'Logged',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const _SimpleCalorieRing(),
              const SizedBox(height: AppSpacing.lg),

              // ── Recent scan carousel ───────────────────────────────
              if (scanned.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 14, color: c.textSecondary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Recent Scans',
                        style: AppTextStyles.bodyCompact.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                RecentScanCarousel(items: scanned.take(8).toList()),
                const SizedBox(height: AppSpacing.lg),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: AppCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: c.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            Icons.qr_code_scanner,
                            color: c.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No scans yet',
                                style: AppTextStyles.bodyCompact.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Scan a supplement label to check for amino spiking',
                                style: AppTextStyles.caption.copyWith(
                                  color: c.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Feature grid ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'Features',
                  style: AppTextStyles.bodyCompact.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: _FeatureCard(
                        Icons.document_scanner_outlined,
                        'AI Scan',
                        'Detect amino spiking',
                        c.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _FeatureCard(
                        Icons.health_and_safety_outlined,
                        'Health Check',
                        'Smart food warnings',
                        const Color(0xFF22c55e),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: _FeatureCard(
                        Icons.bar_chart_rounded,
                        'Dashboard',
                        'Daily nutrients',
                        const Color(0xFFf5a623),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _FeatureCard(
                        Icons.history_rounded,
                        'History',
                        'Review past logs',
                        C0Theme.slateGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _HeroStat(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min, // ADD this
    children: [
      Icon(icon, color: Colors.white70, size: 14),
      const SizedBox(width: AppSpacing.xs),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ADD this
        children: [
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.micro.copyWith(color: Colors.white60),
          ),
        ],
      ),
    ],
  );
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _FeatureCard(this.icon, this.title, this.subtitle, this.color);
  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: AppTextStyles.micro.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

// Build-mode check
const bool kDebugBuild = !bool.fromEnvironment('dart.vm.product');

class _SimpleCalorieRing extends StatelessWidget {
  const _SimpleCalorieRing();

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final foodVm = context.watch<FoodLogViewModel>();
    final dashVm = context.watch<DashboardViewModel>();
    final consumed = foodVm.totalCalories;
    final target = dashVm.calorieTarget;
    final remaining = (target - consumed).clamp(0, target);
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final isOver = consumed > target;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg), // was AppSpacing.xl
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, size: 16, color: c.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  "Today's Calories",
                  style: AppTextStyles.bodyCompact.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Goal: $target kcal',
                  style: AppTextStyles.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md), // was AppSpacing.lg
            Row(
              children: [
                // Smaller ring
                SizedBox(
                  width: 88, // was 100
                  height: 88, // was 100
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 9, // was 10
                          backgroundColor: isOver
                              ? c.warning.withValues(alpha: 0.15)
                              : c.primary.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOver ? c.warning : c.primary,
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$consumed',
                            style: AppTextStyles.statValue.copyWith(
                              color: isOver ? c.warning : c.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 20, // was 22
                            ),
                          ),
                          Text(
                            'kcal',
                            style: AppTextStyles.micro.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg), // was AppSpacing.xl
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CalStat(
                        label: 'Eaten',
                        value: '$consumed kcal',
                        color: c.primary,
                        icon: Icons.restaurant_outlined,
                      ),
                      const SizedBox(
                        height: AppSpacing.sm,
                      ), // was AppSpacing.md
                      _CalStat(
                        label: isOver ? 'Over by' : 'Remaining',
                        value: '${isOver ? consumed - target : remaining} kcal',
                        color: isOver ? c.warning : c.success,
                        icon: isOver
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                      ),
                      const SizedBox(
                        height: AppSpacing.sm,
                      ), // was AppSpacing.md
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}% of goal',
                            style: AppTextStyles.micro.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: c.primary.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isOver ? c.warning : c.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _CalStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          // ADD Expanded to prevent overflow
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // ADD this
            children: [
              Text(
                label,
                style: AppTextStyles.micro.copyWith(color: c.textSecondary),
                overflow: TextOverflow.ellipsis, // ADD this
              ),
              Text(
                value,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis, // ADD this
              ),
            ],
          ),
        ),
      ],
    );
  }
}
