import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Center(
      child: Container(
        width: AppSizes.sheetHandleW,
        height: AppSizes.sheetHandleH,
        decoration: BoxDecoration(
          color: c.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
