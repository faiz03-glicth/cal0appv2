import 'theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'services/firebase_options.dart';
import 'package:provider/provider.dart';
import 'viewModels/wrapper/wrapper.dart';
import 'viewModels/viewauth/auth_viewmodel.dart';
import 'viewModels/usermodel/user_viewmodel.dart';
import 'package:firebase_core/firebase_core.dart';
import 'viewModels/dashboard/dashboard_viewmodel.dart';
import 'package:cal0appv2/viewmodels/theme_viewmodel.dart';
import 'package:cal0appv2/viewModels/foodlog_viewmodel.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';
import 'package:cal0appv2/viewModels/viewauth/register_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LogService.error("FLUTTER ERROR: ${details.exception}");
    if (details.stack != null) {
      LogService.error("STACK TRACE: ${details.stack}");
    }
  };
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Firebase.initializeApp();
  LogService.info("Binding Initialized");
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    LogService.info("Firebase Connection Successful");
  } catch (e) {
    LogService.info("Firebase Error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => RegisterViewModel()),
        ChangeNotifierProvider(create: (_) => UserViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(create: (_) => FoodLogViewModel()),
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeVm = Provider.of<ThemeViewModel>(context);
    return MaterialApp(
      title: 'C0 Calorie Counter',
      theme: C0Theme.lightTheme,
      darkTheme: C0Theme.darkTheme,
      themeMode: themeVm.themeMode,
      home: const Wrapper(),
    );
  }
}
