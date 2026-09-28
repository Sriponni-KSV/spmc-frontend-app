import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'utils/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'utils/app_localizations.dart';
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

  final languageProvider = LanguageProvider();
  await languageProvider.initialize();

  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<ConnectivityService>(
          create: (_) => ConnectivityService(ApiEndpoints.baseUrl),
        ),
        ChangeNotifierProvider<HomeVisitController>(
          create: (_) => HomeVisitController(),
        ),
      ],
      child: MyApp(authProvider: authProvider),
    ),
  );
}

class MyApp extends StatefulWidget {
  final AuthProvider? authProvider;
  const MyApp({super.key, this.authProvider});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    AuthProvider? auth;
    if (widget.authProvider != null) {
      auth = widget.authProvider;
    } else {
      try {
        auth = Provider.of<AuthProvider>(context, listen: false);
      } catch (_) {
        auth = AuthProvider();
      }
    }
    _router = AppRouter.getRouter(auth!);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp.router(
      title: 'Sri Ponni Medical Center',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: languageProvider.locale,
      supportedLocales: LanguageProvider.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      builder: (context, child) => OfflineAwareWrapper(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
