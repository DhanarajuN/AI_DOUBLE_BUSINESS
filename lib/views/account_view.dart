import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/industry.dart';
import '../models/plan.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../routes/app_routes.dart';
import '../services/llm_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/account_view_model.dart';
import '../widgets/business_icons.dart';
import 'dashboard_view.dart' show fmtN, fmtTok, initialsOf;
import 'plans_view.dart';

const _kSwatches = ['#1D4ED8', '#0F3D6E', '#0D9488', '#4F46E5', '#334155', '#0E8A5F'];

class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AccountViewModel(ctx.read<AuthRepository>(), ctx.read<WorkspaceRepository>()),
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
  final _keyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final vm = context.read<AccountViewModel>();
      _keyCtrl.text = vm.apiKey;
      _modelCtrl.text = vm.model;
      _brandCtrl.text = vm.brand;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    _brandCtrl.dispose();
    super.dispose();
  }

  Future<void> _testKey(AccountViewModel vm) async {
    if (!vm.keyReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an API key first'), behavior: SnackBarBehavior.floating));
      return;
    }
    try {
      await vm.testConnection();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection works — you're ready"), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${LlmService.friendlyError(e)}'), behavior: SnackBarBehavior.floating));
    }
  }

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

  Future<void> _resetAll(BuildContext context, AccountViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset everything?', style: AppFonts.display(size: 17)),
        content: Text("This clears your chat, documents, bookings and settings on this device. It can't be undone.", style: AppFonts.body(size: 13.5, color: AppColors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AppFonts.body(size: 14, color: AppColors.ink2))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Reset', style: AppFonts.body(size: 14, weight: FontWeight.w600, color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await vm.resetAll();
      if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.signup, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AccountViewModel>();
    final user = vm.user;
    final biz = vm.business;
    final ind = biz != null ? industryById(biz.industryId) : null;
    final plan = biz != null ? planById(biz.planId) : null;
    final c = kCurrencies[vm.currency]!;
    final P = kProviders[vm.provider]!;

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
                        child: Text(initialsOf(user?.name ?? 'U'), style: AppFonts.display(size: 18, color: Colors.white)),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? 'User', style: AppFonts.body(size: 16, weight: FontWeight.w700, color: AppColors.ink)),
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
            if (biz != null && ind != null && plan != null) ...[
              _sectionTitle('Business'),
              _card(
                child: Column(
                  children: [
                    _row(businessIcon(ind.iconKey), biz.name, '${ind.name} · ${biz.size.isEmpty ? '—' : biz.size}'),
                    Divider(height: 20, color: AppColors.line),
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
            _sectionTitle('AI connection'),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('AI provider', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppColors.paper2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                    child: Row(
                      children: kProviders.entries.map((e) {
                        final on = vm.provider == e.key;
                        return Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () => vm.setProvider(e.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: on ? AppColors.card : null, borderRadius: BorderRadius.circular(9)),
                              child: Text(e.value.name, style: AppFonts.body(size: 11.5, weight: FontWeight.w600, color: on ? AppColors.ink : AppColors.ink2)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('API key', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _keyCtrl,
                          hint: P.keyHint,
                          obscure: vm.obscureKey,
                          onChanged: vm.setApiKey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.line2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: vm.toggleObscureKey,
                        child: Text(vm.obscureKey ? 'Show' : 'Hide', style: AppFonts.body(size: 12, weight: FontWeight.w600, color: AppColors.ink)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Stored only on this device. Calls go straight from your phone to ${P.name}.', style: AppFonts.body(size: 11, color: AppColors.ink3).copyWith(height: 1.4)),
                  const SizedBox(height: 14),
                  Text('Model', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 7),
                  _field(controller: _modelCtrl, hint: P.model, onChanged: vm.setModel),
                  const SizedBox(height: 6),
                  Text('Leave blank to use the default (${P.model}).', style: AppFonts.body(size: 11, color: AppColors.ink3)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: vm.testing ? null : () => _testKey(vm),
                      icon: vm.testing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome_outlined, size: 17),
                      label: Text(vm.testing ? 'Testing…' : 'Test connection', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            _sectionTitle('Brand'),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Assistant name', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 7),
                  _field(controller: _brandCtrl, hint: 'AI Double', onChanged: vm.setBrand),
                  const SizedBox(height: 14),
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
            _sectionTitle('Data'),
            _card(
              child: Column(
                children: [
                  _row(Icons.description_outlined, '${vm.docCount} document${vm.docCount == 1 ? '' : 's'}', 'Stored on this device'),
                  Divider(height: 20, color: AppColors.line),
                  _row(Icons.delete_outline, 'Reset everything', 'Clears chat, docs and settings',
                      trailing: TextButton(
                        onPressed: () => _resetAll(context, vm),
                        child: Text('Reset', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.danger)),
                      )),
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

  Widget _field({required TextEditingController controller, required String hint, bool obscure = false, ValueChanged<String>? onChanged}) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2));
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: AppFonts.body(size: 14, color: AppColors.ink),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppFonts.body(size: 13, color: AppColors.ink3),
        filled: true,
        fillColor: AppColors.paper2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
      ),
    );
  }
}
