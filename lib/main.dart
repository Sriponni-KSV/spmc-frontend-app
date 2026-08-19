import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'utils/app_theme.dart';
import 'providers/auth_provider.dart';
import 'controllers/home_visit_controller.dart';
import 'services/connectivity_service.dart';
import 'widgets/offline_banner.dart';
import 'core/routes/app_router.dart';
import 'config/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Clean URL paths without hashes (#)
  await dotenv.load(fileName: "assets/.env");

  final authProvider = AuthProvider();
  await authProvider.initializeSession(); // Restore session prior to rendering

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ConnectivityService>(
          create: (_) => ConnectivityService(ApiEndpoints.baseUrl),
        ),
        ChangeNotifierProvider<HomeVisitController>(
          create: (_) => HomeVisitController(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.createRouter(context);

    return MaterialApp.router(
      title: 'Sri Ponni Medical Center',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) => OfflineAwareWrapper(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
