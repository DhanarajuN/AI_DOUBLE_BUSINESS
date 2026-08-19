import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/plan.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../routes/app_routes.dart';
import '../services/api_client.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../viewmodels/account_view_model.dart';
import 'dashboard_view.dart' show fmtN, fmtTok, initialsOf;
import 'plans_view.dart';

const _kSwatches = ['#1D4ED8', '#0F3D6E', '#0D9488', '#4F46E5', '#334155', '#0E8A5F'];

class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AccountViewModel(ctx.read<AuthRepository>(), ctx.read<WorkspaceRepository>(),
          ctx.read<SessionStorage>(), ctx.read<ApiClient>()),
      child: const _AccountBody(),
    );
  }
}

class _AccountBody extends StatefulWidget {
  const _AccountBody();

  @override
  State<_AccountBody> createState() => _AccountBodyState();
}

class _AccountBodyState extends State<_AccountBody> {
  Future<void> _confirmLogout(BuildContext context, AccountViewModel vm) async {
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
      await vm.logout();
      if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AccountViewModel>();
    final user = vm.user;
    final biz = vm.business;
    final data = vm.businessData;
    final bizName = _firstNonEmpty(data, const ['Business Name', 'businessName', 'Company Name', 'Name']);
    final bizCategory = _firstNonEmpty(data, const ['Business Category', 'businessCategory'])?.split('(').first.trim();
    final plan = biz != null ? planById(biz.planId) : null;
    final c = kCurrencies[vm.currency]!;

    return Scaffold(
      backgroundColor: AppColors.paper2,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Settings', style: AppFonts.display(size: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(initialsOf(bizName ?? user?.name ?? 'U'), style: AppFonts.display(size: 18, color: Colors.white)),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bizName ?? user?.name ?? 'User', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 16, weight: FontWeight.w700, color: AppColors.ink)),
                            Text(user?.username ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 12.5, color: AppColors.ink3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.line2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                      ),
                      onPressed: () => _confirmLogout(context, vm),
                      child: Text('Sign out', style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
                    ),
                  ),
                ],
              ),
            ),
            if (plan != null) ...[
              _sectionTitle('Business'),
              _card(
                child: Column(
                  children: [
                    if (bizName != null || bizCategory != null) ...[
                      _row(Icons.storefront_outlined, bizName ?? 'Business', bizCategory ?? '—'),
                      Divider(height: 20, color: AppColors.line),
                    ],
                    _row(Icons.local_offer_outlined, '${plan.name} plan', plan.price != null ? '${c.symbol}${fmtN(plan.price![vm.currency]!)} / month' : 'Custom pricing',
                        trailing: TextButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansView())),
                          child: Text('Change', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.accent)),
                        )),
                    Divider(height: 20, color: AppColors.line),
                    _row(Icons.bar_chart_outlined, '${fmtTok(vm.usageIn + vm.usageOut)} tokens used', '${fmtN(vm.usageCalls)} AI calls · ${fmtN(vm.bookingCount)} bookings'),
                  ],
                ),
              ),
            ],
            _sectionTitle('Brand'),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Accent colour', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: _kSwatches.map((hex) {
                      final color = Color(int.parse('FF${hex.substring(1)}', radix: 16));
                      final on = vm.accent.toLowerCase() == hex.toLowerCase();
                      return InkWell(
                        borderRadius: BorderRadius.circular(17),
                        onTap: () => vm.setAccent(hex),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: on ? Border.all(color: AppColors.ink, width: 2) : null),
                          alignment: Alignment.center,
                          child: on ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Theme', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppColors.paper2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                    child: Row(
                      children: [
                        (AppThemeMode.system, 'System'),
                        (AppThemeMode.light, 'Light'),
                        (AppThemeMode.dark, 'Dark'),
                      ].map((entry) {
                        final on = vm.themeMode == entry.$1;
                        return Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () => vm.setThemeMode(entry.$1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: on ? AppColors.card : null, borderRadius: BorderRadius.circular(9)),
                              child: Text(entry.$2, style: AppFonts.body(size: 12, weight: FontWeight.w600, color: on ? AppColors.ink : AppColors.ink2)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'AI Double Business · your key and documents never leave this device except as requests sent to your chosen AI provider.',
              textAlign: TextAlign.center,
              style: AppFonts.body(size: 11, color: AppColors.ink3).copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10, left: 2),
        child: Text(text, style: AppFonts.display(size: 16)),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: child,
      );

  Widget _row(IconData icon, String title, String subtitle, {Widget? trailing}) => Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppFonts.body(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                Text(subtitle, style: AppFonts.body(size: 12, color: AppColors.ink3)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      );

  String? _firstNonEmpty(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

}
