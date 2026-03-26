import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'utils/app_theme.dart';
import 'screens/login_page.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical App Auth',
      debugShowCheckedModeBanner: false,
      // This single line injects our centralized AppTheme across the entire app
      theme: AppTheme.lightTheme,
      // Start the application at the Login Screen
      home: const LoginScreen(),
    );
  }
}
