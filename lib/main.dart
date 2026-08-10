import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'constants/server_urls.dart';
import 'repositories/auth_repository.dart';
import 'repositories/workspace_repository.dart';
import 'routes/app_routes.dart';
import 'services/api_client.dart';
import 'services/app_logger.dart';
import 'services/session_storage.dart';
import 'theme/app_theme.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppLogger.init();

    FlutterError.onError = (details) {
      AppLogger.e('FlutterError', details.exceptionAsString(), details.exception, details.stack);
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.e('PlatformDispatcher', 'Uncaught async error', error, stack);
      return true;
    };

    runApp(const AiDoubleBusinessApp());
  }, (error, stack) {
    AppLogger.e('runZonedGuarded', 'Uncaught zone error', error, stack);
  });
}

class AiDoubleBusinessApp extends StatefulWidget {
  const AiDoubleBusinessApp({super.key});

  @override
  State<AiDoubleBusinessApp> createState() => _AiDoubleBusinessAppState();
}

class _AiDoubleBusinessAppState extends State<AiDoubleBusinessApp> with WidgetsBindingObserver {
  Brightness _systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  Timer? _brightnessPoll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _brightnessPoll = Timer.periodic(const Duration(seconds: 1), (_) => _checkBrightness());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _brightnessPoll?.cancel();
    super.dispose();
  }

  void _checkBrightness() {
    final current = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (current != _systemBrightness) {
      _systemBrightness = current;
      setState(() {});
      WidgetsBinding.instance.reassembleApplication();
    }
  }

  @override
  void didChangePlatformBrightness() => _checkBrightness();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.i('Lifecycle', state.name);
  }

  Brightness _resolveBrightness(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.system:
        return _systemBrightness;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(
          create: (_) => ApiClient(baseUrl: ServerUrls.baseUrl, tenant: ServerUrls.tenant),
          dispose: (_, client) => client.close(),
        ),
        Provider<SessionStorage>(create: (_) => SessionStorage()),
        ChangeNotifierProvider<AuthRepository>(
          create: (ctx) => AuthRepository(ctx.read<ApiClient>(), ctx.read<SessionStorage>()),
        ),
        ChangeNotifierProvider<WorkspaceRepository>(create: (_) => WorkspaceRepository()),
      ],
      child: Builder(
        builder: (context) {
          final workspace = context.watch<WorkspaceRepository>();
          AppColors.configure(
            accentHex: workspace.accent,
            brightness: _resolveBrightness(workspace.themeMode),
          );
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            navigatorObservers: [AppNavigatorObserver(), routeObserver],
          );
        },
      ),
    );
  }
}
