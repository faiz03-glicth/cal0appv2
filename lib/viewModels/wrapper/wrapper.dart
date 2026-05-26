import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/homepages/navbarbottom.dart';
import 'package:cal0appv2/views/auth/login_view.dart';
import 'package:cal0appv2/viewModels/health/health_warning_viewmodel.dart';
import 'package:cal0appv2/services/logging/activity_logger.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  // Update this string when you release a new version
  static const String _appVersion = '1.0.0';

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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ActivityLogger.instance.init(uid: uid, appVersion: _appVersion);
            ActivityLogger.instance.log(ActivityEventType.userLogin);
            context.read<HealthWarningViewModel>().loadConditions(uid);
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
