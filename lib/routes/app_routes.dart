import 'package:flutter/material.dart';
import '../services/app_logger.dart';
import '../views/business_conversations_view.dart';
import '../views/home_shell_view.dart';
import '../views/login_view.dart';
import '../views/signup_view.dart';
import '../views/splash_view.dart';

final routeObserver = RouteObserver<PageRoute<dynamic>>();

class AppNavigatorObserver extends NavigatorObserver {
  String _label(Route<dynamic>? route) =>
      route?.settings.name ?? route?.runtimeType.toString() ?? 'unknown';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppLogger.i(
        'Navigation', 'push ${_label(route)} (from ${_label(previousRoute)})');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppLogger.i('Navigation',
        'pop ${_label(route)} (back to ${_label(previousRoute)})');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    AppLogger.i(
        'Navigation', 'replace ${_label(oldRoute)} with ${_label(newRoute)}');
  }
}

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  // Also reachable as home_shell_view's "Chats" tab (index 2) — this named route stays for
  // deep-linking into it directly (e.g. from a push notification for a specific conversation).
  static const String businessConversations = '/business/conversations';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
            builder: (_) => const SplashView(), settings: settings);
      case login:
        return MaterialPageRoute(
            builder: (_) => const LoginView(), settings: settings);
      case signup:
        return MaterialPageRoute(
            builder: (_) => const SignupView(), settings: settings);
      case home:
        return MaterialPageRoute(
            builder: (_) => const HomeShellView(), settings: settings);
      case businessConversations:
        return MaterialPageRoute(
            builder: (_) => const BusinessConversationsView(),
            settings: settings);
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body:
                Center(child: Text('No route defined for "${settings.name}"')),
          ),
          settings: settings,
        );
    }
  }
}
