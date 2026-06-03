import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/views/foodlog/food_detail_view.dart';
import 'package:cal0appv2/viewModels/foodlog/food_history_viewmodel.dart';

class RecentScanCarousel extends StatelessWidget {
  final List<FoodLogModel> items;
  const RecentScanCarousel({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 165,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (ctx, i) => _ScanCard(item: items[i]),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  final FoodLogModel item;
  const _ScanCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final isSpiked = item.scanAnalysisResult?.contains('SPIKED') ?? false;
    final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: context.read<FoodHistoryViewModel>(),
            child: FoodDetailView(log: item),
          ),
        ),
      ),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              child: hasImage
                  ? Image.file(
                      File(item.imagePath!),
                      width: 140,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _Placeholder(isSpiked: isSpiked, c: c),
                    )
                  : _Placeholder(isSpiked: isSpiked, c: c),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs + 2,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.foodLogName,
                      style: AppTextStyles.micro.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.calorieIntake} kcal',
                          style: AppTextStyles.micro.copyWith(
                            color: c.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // AI verdict dot
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: item.scanAnalysisResult == null
                                ? c.divider
                                : isSpiked
                                ? c.warning
                                : c.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final bool isSpiked;
  final C0Colors c;
  const _Placeholder({required this.isSpiked, required this.c});
  @override
  Widget build(BuildContext context) => Container(
    width: 140,
    height: 88,
    color: isSpiked
        ? c.warning.withValues(alpha: 0.08)
        : c.primary.withValues(alpha: 0.06),
    child: Icon(
      Icons.qr_code_scanner,
      color: isSpiked ? c.warning : c.primary,
      size: 30,
    ),
  );
}
