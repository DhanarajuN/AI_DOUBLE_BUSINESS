import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../routes/app_routes.dart';
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
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
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
