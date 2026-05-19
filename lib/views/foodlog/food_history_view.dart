// lib/views/foodlog/food_history_view.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/viewModels/foodlog/food_history_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/views/foodlog/food_detail_view.dart';

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
          // ── Search + filter header ────────────────────────────────────────
          Container(
            color: c.card,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: vm.setSearch,
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search food entries...',
                    hintStyle: TextStyle(color: c.textSecondary, fontSize: 13),
                    prefixIcon: Icon(
                      Icons.search,
                      color: c.textSecondary,
                      size: 18,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 16,
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.divider),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter chips
                Row(
                  children: [
                    _filterChip('All', HistoryFilter.all, vm, c),
                    const SizedBox(width: 8),
                    _filterChip(
                      'Manual',
                      HistoryFilter.manual,
                      vm,
                      c,
                      icon: Icons.edit,
                      count: vm.totalManual,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      'Scanned',
                      HistoryFilter.scanned,
                      vm,
                      c,
                      icon: Icons.qr_code_scanner,
                      count: vm.totalScanned,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: vm.isLoading
                ? Center(child: CircularProgressIndicator(color: c.primary))
                : vm.filtered.isEmpty
                ? _buildEmpty(vm, c)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: vm.filtered.length,
                    itemBuilder: (ctx, i) {
                      final log = vm.filtered[i];
                      // Date separator
                      final showDate =
                          i == 0 ||
                          !_sameDay(vm.filtered[i - 1].loggedAt, log.loggedAt);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDate) _dateSeparator(log.loggedAt, c),
                          _buildCard(ctx, log, vm, c),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Card ──────────────────────────────────────────────────────────────────

  Widget _buildCard(
    BuildContext context,
    FoodLogModel log,
    FoodHistoryViewModel vm,
    C0Colors c,
  ) {
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left image/icon area
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: _buildThumbnail(log, c),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + source badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log.foodLogName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: c.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _sourceBadge(log, c),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Time
                    Text(
                      DateFormat('h:mm a').format(log.loggedAt),
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                    const SizedBox(height: 6),

                    // Macros compact row
                    Row(
                      children: [
                        _miniMacro(
                          '${log.calorieIntake}',
                          'kcal',
                          c.primary,
                          c,
                        ),
                        const SizedBox(width: 10),
                        _miniMacro(
                          '${log.protein.toStringAsFixed(1)}g',
                          'P',
                          c.success,
                          c,
                        ),
                        const SizedBox(width: 10),
                        _miniMacro(
                          '${log.carbs.toStringAsFixed(1)}g',
                          'C',
                          Colors.orange,
                          c,
                        ),
                        const SizedBox(width: 10),
                        _miniMacro(
                          '${log.fats.toStringAsFixed(1)}g',
                          'F',
                          c.slate,
                          c,
                        ),
                      ],
                    ),

                    // Scan-specific: AI result chip
                    if (log.isScanned && log.scanAnalysisResult != null) ...[
                      const SizedBox(height: 6),
                      _aiChip(log.scanAnalysisResult!, c),
                    ],
                  ],
                ),
              ),
            ),

            // Delete button
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: c.textSecondary,
              ),
              onPressed: () => _confirmDelete(context, log, vm, c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(FoodLogModel log, C0Colors c) {
    if (log.isScanned && log.imagePath != null && log.imagePath!.isNotEmpty) {
      return SizedBox(
        width: 70,
        height: 80,
        child: Image.file(
          File(log.imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconThumbnail(log, c),
        ),
      );
    }
    return _iconThumbnail(log, c);
  }

  Widget _iconThumbnail(FoodLogModel log, C0Colors c) => Container(
    width: 70,
    height: 80,
    color: log.isScanned
        ? c.primary.withOpacity(0.08)
        : c.success.withOpacity(0.08),
    child: Icon(
      log.isScanned ? Icons.qr_code_scanner : Icons.restaurant,
      color: log.isScanned ? c.primary : c.success,
      size: 28,
    ),
  );

  Widget _sourceBadge(FoodLogModel log, C0Colors c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: log.isScanned
          ? c.primary.withOpacity(0.1)
          : c.success.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          log.isScanned ? Icons.qr_code_scanner : Icons.edit,
          size: 10,
          color: log.isScanned ? c.primary : c.success,
        ),
        const SizedBox(width: 3),
        Text(
          log.isScanned ? 'Scanned' : 'Manual',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: log.isScanned ? c.primary : c.success,
          ),
        ),
      ],
    ),
  );

  Widget _aiChip(String result, C0Colors c) {
    final isSpiked = result.contains('SPIKED');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isSpiked ? c.warning : c.success).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSpiked ? Icons.warning_amber : Icons.shield,
            size: 10,
            color: isSpiked ? c.warning : c.success,
          ),
          const SizedBox(width: 3),
          Text(
            result,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isSpiked ? c.warning : c.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMacro(String value, String label, Color color, C0Colors c) =>
      RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
            ),
            TextSpan(
              text: ' $label',
              style: TextStyle(fontSize: 10, color: c.textSecondary),
            ),
          ],
        ),
      );

  // ── Date separator ────────────────────────────────────────────────────────

  Widget _dateSeparator(DateTime date, C0Colors c) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    String label;
    if (d == today)
      label = 'Today';
    else if (d == today.subtract(const Duration(days: 1)))
      label = 'Yesterday';
    else
      label = DateFormat('EEEE, d MMM yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
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
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chip ───────────────────────────────────────────────────────────

  Widget _filterChip(
    String label,
    HistoryFilter filter,
    FoodHistoryViewModel vm,
    C0Colors c, {
    IconData? icon,
    int? count,
  }) {
    final active = vm.activeFilter == filter;
    return GestureDetector(
      onTap: () => vm.setFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.primary : c.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c.primary : c.divider, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: active ? Colors.white : c.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : c.textSecondary,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withOpacity(0.3)
                      : c.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : c.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildEmpty(FoodHistoryViewModel vm, C0Colors c) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.history, size: 56, color: c.textSecondary),
        const SizedBox(height: 12),
        Text(
          vm.searchQuery.isNotEmpty
              ? 'No results for "${vm.searchQuery}"'
              : vm.activeFilter == HistoryFilter.scanned
              ? 'No scanned entries yet'
              : vm.activeFilter == HistoryFilter.manual
              ? 'No manual entries yet'
              : 'No food history yet',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Start logging food to see history here',
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );

  void _confirmDelete(
    BuildContext context,
    FoodLogModel log,
    FoodHistoryViewModel vm,
    C0Colors c,
  ) {
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
