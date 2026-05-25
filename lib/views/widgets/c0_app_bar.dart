import 'package:flutter/material.dart';
import 'package:cal0appv2/theme/app_theme.dart';

class C0AppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;

  const C0AppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return AppBar(
      backgroundColor: c.header,
      foregroundColor: c.headerText,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                size: AppSizes.fieldIconSize,
              ),
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Row(
        children: [
          Container(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          Text(title, style: AppTextStyles.title.copyWith(color: Colors.white)),
        ],
      ),
      // No dark mode toggle here — it's in UserProfileView > App Settings
      actions: actions,
    );
  }
}
