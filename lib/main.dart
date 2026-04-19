import 'theme/app_theme.dart';
import 'services/secure_config.dart';
import 'package:flutter/material.dart';
import 'services/firebase_options.dart';
import 'package:provider/provider.dart';
import 'viewModels/wrapper/wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'viewModels/viewauth/auth_viewmodel.dart';
import 'package:firebase_core/firebase_core.dart';
import 'viewModels/usermodel/user_viewmodel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'viewModels/dashboard/dashboard_viewmodel.dart';
import 'package:cal0appv2/viewmodels/theme_viewmodel.dart';
import 'package:cal0appv2/viewModels/foodlog_viewmodel.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';
import 'package:cal0appv2/viewModels/viewauth/register_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'crypt.env');
  await SecureConfig.init();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 10485760,
  );
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LogService.error('FLUTTER ERROR: ${details.exception}');
  };
  //debugPrint("Firebase Initialized");
  LogService.info("Binding Initialized");
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    LogService.info("Firebase Connection Successful");
  } catch (e) {
    LogService.info("Firebase Error: $e");
  }
  await Firebase.initializeApp();

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
