import 'package:cal0appv2/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/viewModels/wrapper/wrapper.dart';
import 'package:cal0appv2/services/auth/secure_config.dart';
import 'package:cal0appv2/services/firebase/firebase_options.dart';
import '/../viewModels/scan/scan_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cal0appv2/viewModels/usermodel/user_viewmodel.dart';
import '/../services/logs/debuglog_services.dart';
import '/../viewModels/theme/theme_viewmodel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/../viewModels/foodlog/foodlog_viewmodel.dart';
import 'package:cal0appv2/viewModels/dashboard/dashboard_viewmodel.dart';
import '/../viewModels/viewauth/register_viewmodel.dart';
import '/../viewModels/foodlog/food_history_viewmodel.dart';
import 'package:cal0appv2/viewModels/health/health_warning_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LogService.error('FLUTTER ERROR: ${details.exception}');
  };

  LogService.info('Env loading');
  try {
    await dotenv.load(fileName: 'crypt.env');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    LogService.info('Firebase connected');
  } catch (e) {
    LogService.error('Firebase init error: $e');
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 10485760,
  );

  try {
    await SecureConfig.init();
    LogService.info('SecureConfig initialized');
  } catch (e) {
    LogService.error('SecureConfig Error: $e');
  }

  runApp(const _AppRoot());
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  // Create instances here so we can wire callbacks before build
  final _authVm = AuthViewModel();
  final _foodLogVm = FoodLogViewModel();
  final _dashboardVm = DashboardViewModel();
  final _healthVm = HealthWarningViewModel();

  @override
  void initState() {
    super.initState();
    // Wire sign-out callbacks so state is always clean after logout
    _authVm.addSignOutCallback(_foodLogVm.clearForLogout);
    _authVm.addSignOutCallback(_dashboardVm.clearForLogout);
    _authVm.addSignOutCallback(_healthVm.clearForLogout);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authVm),
        ChangeNotifierProvider.value(value: _foodLogVm),
        ChangeNotifierProvider.value(value: _dashboardVm),
        ChangeNotifierProvider.value(value: _healthVm),
        ChangeNotifierProvider(create: (_) => RegisterViewModel()),
        ChangeNotifierProvider(create: (_) => UserViewModel()),
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
        ChangeNotifierProvider(create: (_) => ScanViewModel()),
        ChangeNotifierProvider(create: (_) => FoodHistoryViewModel()),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (_, themeVm, __) => MaterialApp(
          title: 'C0 Calorie Counter',
          theme: C0Theme.lightTheme,
          darkTheme: C0Theme.darkTheme,
          themeMode: themeVm.themeMode,
          home: const Wrapper(),
        ),
      ),
    );
  }
}
