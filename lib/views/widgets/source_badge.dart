import 'package:flutter/material.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/logging/foodlog_model.dart';

class SourceBadge extends StatelessWidget {
  final FoodLogSource source;
  final bool dense;

  const SourceBadge({super.key, required this.source, this.dense = false});

  bool get _isScanned => source == FoodLogSource.scanned;

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final color = _isScanned ? c.primary : c.success;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 5 : 6,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(dense ? 4 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isScanned ? Icons.qr_code_scanner : Icons.edit,
            size: dense ? 9 : 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            _isScanned ? 'Scanned' : 'Manual',
            style: AppTextStyles.micro.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: dense ? 9 : 10,
            ),
          ),
        ],
      ),
    );
  }
}
