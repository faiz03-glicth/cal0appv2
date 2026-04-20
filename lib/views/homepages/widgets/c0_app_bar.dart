import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/theme/theme_viewmodel.dart';

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
    final themeVm = Provider.of<ThemeViewModel>(context);

    return AppBar(
      backgroundColor: c.header,
      foregroundColor: c.headerText,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Row(
        children: [
          // App logo dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        // Theme toggle — always visible
        IconButton(
          icon: Icon(
            themeVm.isDark ? Icons.light_mode : Icons.dark_mode,
            color: Colors.white,
            size: 20,
          ),
          onPressed: themeVm.toggleTheme,
          tooltip: themeVm.isDark ? 'Light mode' : 'Dark mode',
        ),
        // Extra actions passed in
        if (actions != null) ...actions!,
      ],
    );
  }
}
