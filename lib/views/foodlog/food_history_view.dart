import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/logging/foodlog_model.dart';
import 'package:cal0appv2/viewModels/foodlog/food_history_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/views/foodlog/food_detail_view.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';
import 'package:cal0appv2/views/widgets/app_pill_chip.dart';
import 'package:cal0appv2/views/widgets/source_badge.dart';

class FoodHistoryView extends StatefulWidget {
  const FoodHistoryView({super.key});

  @override
  State<FoodHistoryView> createState() => _FoodHistoryViewState();
}

class _FoodHistoryViewState extends State<FoodHistoryView> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final uid = context.read<AuthViewModel>().currentUid ?? '';
      context.read<FoodHistoryViewModel>().load(uid);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = context.watch<FoodHistoryViewModel>();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.header,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Food History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // ── Search + filter header ──────────────────────────────────────
          Container(
            color: c.card,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: vm.setSearch,
                  style: AppTextStyles.bodyCompact.copyWith(
                    color: c.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search food entries...',
                    hintStyle: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: c.textSecondary,
                      size: AppSizes.smallIconSize,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: AppSizes.miniIconSize + 2,
                              color: c.textSecondary,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              vm.setSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: c.background,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm + 2,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: c.divider),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                // Filter chips
                Row(
                  children: [
                    AppPillChip(
                      label: 'All',
                      selected: vm.activeFilter == HistoryFilter.all,
                      onTap: () => vm.setFilter(HistoryFilter.all),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppPillChip(
                      label: 'Manual',
                      selected: vm.activeFilter == HistoryFilter.manual,
                      onTap: () => vm.setFilter(HistoryFilter.manual),
                      icon: Icons.edit,
                      count: vm.totalManual,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppPillChip(
                      label: 'Scanned',
                      selected: vm.activeFilter == HistoryFilter.scanned,
                      onTap: () => vm.setFilter(HistoryFilter.scanned),
                      icon: Icons.qr_code_scanner,
                      count: vm.totalScanned,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: vm.isLoading
                ? Center(child: CircularProgressIndicator(color: c.primary))
                : vm.filtered.isEmpty
                ? _EmptyState(vm: vm)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      80,
                    ),
                    itemCount: vm.filtered.length,
                    itemBuilder: (ctx, i) {
                      final log = vm.filtered[i];
                      final showDate =
                          i == 0 ||
                          !_sameDay(vm.filtered[i - 1].loggedAt, log.loggedAt);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDate) _DateSeparator(date: log.loggedAt),
                          _HistoryCard(log: log, vm: vm),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Card ───────────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final FoodLogModel log;
  final FoodHistoryViewModel vm;

  const _HistoryCard({required this.log, required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: vm,
            child: FoodDetailView(log: log),
          ),
        ),
      ),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppRadius.xl),
              ),
              child: _Thumbnail(log: log),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm + 2,
                  AppSpacing.sm,
                  AppSpacing.sm + 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log.foodLogName,
                            style: AppTextStyles.bodyCompact.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        SourceBadge(source: log.source),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      DateFormat('h:mm a').format(log.loggedAt),
                      style: AppTextStyles.tiny.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    // Macros compact row
                    Row(
                      children: [
                        _MiniMacro('${log.calorieIntake}', 'kcal', c.primary),
                        const SizedBox(width: AppSpacing.sm + 2),
                        _MiniMacro(
                          '${log.protein.toStringAsFixed(1)}g',
                          'P',
                          c.success,
                        ),
                        const SizedBox(width: AppSpacing.sm + 2),
                        _MiniMacro(
                          '${log.carbs.toStringAsFixed(1)}g',
                          'C',
                          C0Theme.macroCarbs,
                        ),
                        const SizedBox(width: AppSpacing.sm + 2),
                        _MiniMacro(
                          '${log.fats.toStringAsFixed(1)}g',
                          'F',
                          c.slate,
                        ),
                      ],
                    ),
                    if (log.isScanned && log.scanAnalysisResult != null) ...[
                      const SizedBox(height: AppSpacing.xs + 2),
                      _AiChip(result: log.scanAnalysisResult!),
                    ],
                  ],
                ),
              ),
            ),
            // Delete button
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: AppSizes.smallIconSize,
                color: c.textSecondary,
              ),
              onPressed: () => _confirmDelete(context, log, vm),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    FoodLogModel log,
    FoodHistoryViewModel vm,
  ) {
    final c = C0Theme.of(context);
    final uid = context.read<AuthViewModel>().currentUid ?? '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Delete entry?', style: TextStyle(color: c.textPrimary)),
        content: Text(
          'Remove "${log.foodLogName}" from your history?',
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
              vm.delete(uid, log.foodLogID);
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

// ── Thumbnail ──────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final FoodLogModel log;
  const _Thumbnail({required this.log});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    if (log.isScanned && log.imagePath != null && log.imagePath!.isNotEmpty) {
      return SizedBox(
        width: 70,
        height: 80,
        child: Image.file(
          File(log.imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _IconThumbnail(log: log),
        ),
      );
    }
    return _IconThumbnail(log: log);
  }
}

class _IconThumbnail extends StatelessWidget {
  final FoodLogModel log;
  const _IconThumbnail({required this.log});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final color = log.isScanned ? c.primary : c.success;
    return Container(
      width: 70,
      height: 80,
      color: color.withValues(alpha: 0.08),
      child: Icon(
        log.isScanned ? Icons.qr_code_scanner : Icons.restaurant,
        color: color,
        size: 28,
      ),
    );
  }
}

// ── AI chip ────────────────────────────────────────────────────────────────

class _AiChip extends StatelessWidget {
  final String result;
  const _AiChip({required this.result});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final isSpiked = result.contains('SPIKED');
    final color = isSpiked ? c.warning : c.success;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.xs + 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSpiked ? Icons.warning_amber : Icons.shield,
            size: AppSizes.miniIconSize,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            result,
            style: AppTextStyles.micro.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini macro chip ────────────────────────────────────────────────────────

class _MiniMacro extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniMacro(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: value,
            style: AppTextStyles.tiny.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: AppTextStyles.micro.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Date separator ─────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final String label;
    if (d == today) {
      label = 'Today';
    } else if (d == today.subtract(const Duration(days: 1))) {
      label = 'Yesterday';
    } else {
      label = DateFormat('EEEE, d MMM yyyy').format(date);
    }
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xs + 2,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.tiny.copyWith(
              fontWeight: FontWeight.w700,
              color: c.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final FoodHistoryViewModel vm;
  const _EmptyState({required this.vm});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final String msg;
    if (vm.searchQuery.isNotEmpty) {
      msg = 'No results for "${vm.searchQuery}"';
    } else if (vm.activeFilter == HistoryFilter.scanned) {
      msg = 'No scanned entries yet';
    } else if (vm.activeFilter == HistoryFilter.manual) {
      msg = 'No manual entries yet';
    } else {
      msg = 'No food history yet';
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 56, color: c.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(
            msg,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            'Start logging food to see history here',
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
