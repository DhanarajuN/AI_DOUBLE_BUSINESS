import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/server_urls.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../routes/app_routes.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final authRepository = context.read<AuthRepository>();
    final workspace = context.read<WorkspaceRepository>();
    await Future.wait([
      authRepository.restoreSession(),
      workspace.load(),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    if (!mounted) return;
    final loggedIn = authRepository.status == AuthStatus.authenticated;
    final isGuestSession = authRepository.currentUser?.roleName == 'guest';
    if (!loggedIn) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    } else if (workspace.business == null && isGuestSession) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
    } else {
      if (workspace.business == null) {
        final user = authRepository.currentUser;
        await workspace.ensureDefaultBusiness(name: user?.name ?? 'My business', owner: user?.name ?? '', email: user?.username ?? '');
        if (!mounted) return;
      }
      await _businessInformation(authRepository.currentUser?.username);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  Future<void> _businessInformation(String? email) async {
    final sessionStorage = context.read<SessionStorage>();
    final apiClient = context.read<ApiClient>();
    final cached = await sessionStorage.readBusinessId();
    AppLogger.i('Splash', 'Business lookup check — cached businessId: ${cached ?? 'none'}');

    final wanted = email?.trim().toLowerCase();
    if (wanted == null || wanted.isEmpty) {
      AppLogger.w('Splash', 'No signed-in email, skipping business lookup');
      return;
    }

    AppLogger.i('Splash', 'Looking up business for $wanted');
    try {
      final result = await apiClient.get(
        ServerUrls.businessInstances,
        query: {
          'pageNumber': '1',
          'pageSize': '10',
          'filters': jsonEncode([
            {'fieldName': 'parentJobInstanceId', 'condition': 'is', 'value': ''},
            {'fieldName': 'Work Email', 'condition': 'contains', 'value': wanted},
          ]),
        },
      );
      if (result is! Map<String, dynamic>) {
        AppLogger.w('Splash', 'Unexpected business lookup response: $result');
        return;
      }
      final jobs = result['jobs'] as List?;
      if (jobs == null || jobs.isEmpty) {
        AppLogger.w('Splash', 'No business found for $wanted');
        return;
      }
      final job = jobs.first;
      if (job is! Map<String, dynamic>) {
        AppLogger.w('Splash', 'Unexpected business record shape: $job');
        return;
      }
      final id = job['id'] as String?;
      if (id != null && id.isNotEmpty) {
        await sessionStorage.saveBusinessId(id);
        AppLogger.i('Splash', 'Resolved businessId: $id');
      } else {
        AppLogger.w('Splash', 'Business record had no id: $job');
      }
      final data = job['data'];
      if (data is Map<String, dynamic> && data.isNotEmpty) {
        await sessionStorage.saveBusinessData(data);
        AppLogger.i('Splash', 'Captured business data fields: ${data.keys.toList()}');
      } else {
        AppLogger.w('Splash', 'Business record had no data captured');
      }
    } catch (e) {
      AppLogger.w('Splash', 'Could not resolve businessId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chrome,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogoMark(size: 60),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                style: AppFonts.display(size: 26, color: Colors.white),
                children: [
                  const TextSpan(text: 'AI '),
                  TextSpan(
                    text: 'Double',
                    style: AppFonts.display(size: 26, weight: FontWeight.w800, color: AppColors.accent2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('BUSINESS', style: AppFonts.mono(size: 11, color: AppColors.chromeTx, letterSpacing: 3)),
            const SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent2),
            ),
          ],
        ),
      ),
    );
  }
}
