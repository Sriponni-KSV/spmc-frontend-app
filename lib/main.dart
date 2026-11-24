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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'config/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Clean URL paths without hashes (#)
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    try {
      await dotenv.load(fileName: "assets/.env");
    } catch (_) {}
  }

  final authProvider = AuthProvider();
  await authProvider.initializeSession(); // Restore session prior to rendering

  final languageProvider = LanguageProvider();
  await languageProvider.initialize(
    userPreferredLanguage: authProvider.user?.preferredLanguage,
    userId: authProvider.user?.id,
  );

  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  // Prevent blank screen on release mode: display friendly error view
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFF8F9FA),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 48),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  final nav = AppRouter.parentNavigatorKey.currentState;
                  if (nav != null && nav.canPop()) {
                    nav.pop();
                  } else {
                    final ctx = AppRouter.parentNavigatorKey.currentContext;
                    if (ctx != null) {
                      ctx.go('/dashboard');
                    }
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Return to Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F5A8E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

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
    // Language provider is still read so the widget rebuilds when it changes,
    // but the MaterialApp is pinned to English.  Tamil locale is applied only
    // via Localizations.override inside the Home Visit subtree so that
    // root-navigator dialogs (showDialog) also remain in English everywhere
    // except where a Tamil override is explicitly provided.
    Provider.of<LanguageProvider>(context); // subscribe to changes (for Home Visit subtree rebuilds)

    return MaterialApp.router(
      title: 'Sri Ponni Medical Center',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: const Locale('en'), // always English at root level
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
