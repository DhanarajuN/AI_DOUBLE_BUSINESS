import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../widgets/coming_soon_view.dart';

class AccountView extends StatelessWidget {
  const AccountView({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign out?', style: AppFonts.display(size: 17)),
        content: Text("You'll need to sign in again to manage this workspace.", style: AppFonts.body(size: 13.5, color: AppColors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AppFonts.body(size: 14, color: AppColors.ink2))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Sign out', style: AppFonts.body(size: 14, weight: FontWeight.w600, color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthRepository>().logout();
      if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ComingSoonView(
      title: 'Settings',
      message: 'Profile, AI connection, brand and theme settings are still in progress.',
      footer: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.line2),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        onPressed: () => _confirmLogout(context),
        child: Text('Sign out', style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
      ),
    );
  }
}
