// Package info note: requires `package_info_plus` in pubspec.yaml:
//   package_info_plus: ^6.0.0

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cal0appv2/views/homepages/navbarbottom.dart';
import 'package:cal0appv2/views/auth/login_view.dart';
import 'package:cal0appv2/viewModels/health/health_warning_viewmodel.dart';
import 'package:cal0appv2/services/logging/activity_logger.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final uid = snapshot.data!.uid;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) return;
            // Get app version for log context
            String version = '1.0.0';
            try {
              final info = await PackageInfo.fromPlatform();
              version = '${info.version}+${info.buildNumber}';
            } catch (_) {}
            ActivityLogger.instance.init(uid: uid, appVersion: version);
            ActivityLogger.instance.log(ActivityEventType.userLogin);
            if (context.mounted) {
              context.read<HealthWarningViewModel>().loadConditions(uid);
            }
          });
          return const Homepage();
        }

        // Signed out — clear logger session
        ActivityLogger.instance.clearSession();
        return const LoginView();
      },
    );
  }
}
