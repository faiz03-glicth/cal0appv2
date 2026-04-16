import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_options.dart';
import 'viewModels/viewauth/auth_viewmodel.dart';
import 'viewModels/wrapper/wrapper.dart';
import 'package:provider/provider.dart';
import 'viewModels/usermodel/user_viewmodel.dart';
import 'viewModels/dashboard/dashboard_viewmodel.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => UserViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
      ],
      child: MaterialApp(
        title: 'C0 App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: const Wrapper(),
      ),
    );
  }
}
