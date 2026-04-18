import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cal0appv2/views/debug/debug_view.dart';
import 'package:cal0appv2/viewmodels/theme_viewmodel.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final themeVm = Provider.of<ThemeViewModel>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Home', style: TextStyle(color: c.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugView()),
              );
            },
          ),

          IconButton(
            icon: Icon(
              themeVm.isDark ? Icons.light_mode : Icons.dark_mode,
              color: themeVm.isDark ? Colors.amber : c.primary,
            ),
            onPressed: themeVm.toggleTheme,
            tooltip: themeVm.isDark ? 'Light mode' : 'Dark mode',
          ),
          IconButton(
            icon: Icon(Icons.logout, color: c.primary),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 64, color: c.primary),
            const SizedBox(height: 16),
            Text(
              'Welcome back!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(user?.email ?? '', style: TextStyle(color: c.textSecondary)),
            const SizedBox(height: 32),

            // Theme toggle card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        themeVm.isDark ? Icons.dark_mode : Icons.light_mode,
                        color: themeVm.isDark ? Colors.amber : c.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        themeVm.isDark ? 'Dark mode' : 'Light mode',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: themeVm.isDark,
                    onChanged: (_) => themeVm.toggleTheme(),
                    activeColor: c.primary,
                    activeTrackColor: c.track,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
