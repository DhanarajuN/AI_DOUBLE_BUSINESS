import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../models/industry.dart';
import '../models/plan.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../viewmodels/signup_view_model.dart';
import '../widgets/app_logo.dart';
import '../widgets/business_icons.dart';

class SignupView extends StatelessWidget {
  const SignupView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => SignupViewModel(ctx.read<AuthRepository>(), ctx.read<WorkspaceRepository>()),
      child: const _SignupBody(),
    );
  }
}

class _SignupBody extends StatefulWidget {
  const _SignupBody();

  @override
  State<_SignupBody> createState() => _SignupBodyState();
}

class _SignupBodyState extends State<_SignupBody> {
  final _nameCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final owner = context.read<SignupViewModel>().initialOwnerName;
    if (owner != null) _ownerCtrl.text = owner;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    super.dispose();
  }

  void _next(SignupViewModel vm) {
    final error = vm.validateStep1(_nameCtrl.text);
    if (error != null) {
      _warn(error);
      return;
    }
    vm.goToStep2();
  }

  void _warn(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _complete(SignupViewModel vm) async {
    await vm.complete(name: _nameCtrl.text, owner: _ownerCtrl.text);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SignupViewModel>();
    return Scaffold(
      backgroundColor: AppColors.paper2,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppLogoMark(size: 22),
                  const SizedBox(width: 9),
                  RichText(
                    text: TextSpan(
                      style: AppFonts.display(size: 16, color: AppColors.ink),
                      children: [
                        const TextSpan(text: 'AI '),
                        TextSpan(text: 'Double', style: AppFonts.display(size: 16, weight: FontWeight.w800, color: AppColors.accent)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _stepBar(true)),
                  const SizedBox(width: 6),
                  Expanded(child: _stepBar(vm.step == 2)),
                ],
              ),
              const SizedBox(height: 20),
              if (vm.step == 1) ..._buildStep1(vm) else ..._buildStep2(vm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBar(bool on) => Container(height: 4, decoration: BoxDecoration(color: on ? AppColors.accent : AppColors.line2, borderRadius: BorderRadius.circular(2)));

  List<Widget> _buildStep1(SignupViewModel vm) {
    return [
      Text('Set up your workspace', style: AppFonts.display(size: 24)),
      const SizedBox(height: 6),
      Text(
        "Your AI Double is tailored to your industry — the services it books and the questions it expects.",
        style: AppFonts.body(size: 13.5, color: AppColors.ink2).copyWith(height: 1.5),
      ),
      const SizedBox(height: 20),
      _label('Business name'),
      _textField(_nameCtrl, 'e.g. Sunrise Insurance'),
      const SizedBox(height: 14),
      _label('Your name'),
      _textField(_ownerCtrl, 'Your full name'),
      const SizedBox(height: 14),
      _label('Which industry are you in?'),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.6,
        children: kIndustries.map((i) {
          final on = vm.industryId == i.id;
          return _tile(
            onTap: () => vm.pickIndustry(i.id),
            on: on,
            icon: businessIcon(i.iconKey),
            label: i.name,
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
      _primaryButton('Continue', Icons.arrow_forward, () => _next(vm)),
    ];
  }

  List<Widget> _buildStep2(SignupViewModel vm) {
    final c = kCurrencies[vm.region]!;
    final plans = kPlans.where((p) => p.id != 'enterprise').toList();
    return [
      Text('Team & plan', style: AppFonts.display(size: 24)),
      const SizedBox(height: 6),
      Text(
        'Pick a starting plan — change it any time. Every plan includes a conversation package.',
        style: AppFonts.body(size: 13.5, color: AppColors.ink2).copyWith(height: 1.5),
      ),
      const SizedBox(height: 20),
      _label('Team size'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kTeamSizes.map((s) {
          final on = vm.size == s;
          return _chip(s, on, () => vm.pickSize(s));
        }).toList(),
      ),
      const SizedBox(height: 18),
      _label('Billing region'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kCurrencies.entries.map((e) {
          final on = vm.region == e.key;
          return _chip(e.value.label, on, () => vm.pickRegion(e.key));
        }).toList(),
      ),
      const SizedBox(height: 18),
      _label('Plan'),
      const SizedBox(height: 8),
      ...plans.map((p) {
        final on = vm.planId == p.id;
        final price = p.price![vm.region]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => vm.pickPlan(p.id),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: on ? AppColors.accent : AppColors.line, width: on ? 1.4 : 1),
                boxShadow: on ? [BoxShadow(color: AppColors.accent.withOpacity(0.14), blurRadius: 18, offset: const Offset(0, 8))] : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: on ? AppColors.accent : AppColors.line2, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: on ? Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p.name}${p.hot ? ' · popular' : ''}', style: AppFonts.body(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                        Text('${p.conversations} conversations · ${_fmtTok(p.tokens)} tokens', style: AppFonts.body(size: 12, color: AppColors.ink3)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${c.symbol}$price', style: AppFonts.display(size: 17)),
                      Text('/ month', style: AppFonts.body(size: 10.5, color: AppColors.ink3)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }),
      const SizedBox(height: 10),
      Row(
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.line2),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            onPressed: vm.goToStep1,
            child: Text('Back', style: AppFonts.body(size: 14.5, weight: FontWeight.w600, color: AppColors.ink)),
          ),
          const SizedBox(width: 10),
          Expanded(child: _primaryButton(vm.submitting ? 'Creating…' : 'Create workspace', Icons.arrow_forward, vm.submitting ? null : () => _complete(vm))),
        ],
      ),
    ];
  }

  String _fmtTok(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return '$n';
  }

  Widget _label(String text) => Text(text, style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink));

  Widget _textField(TextEditingController ctrl, String hint) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2));
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: TextField(
        controller: ctrl,
        style: AppFonts.body(size: 14.5, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppFonts.body(size: 14, color: AppColors.ink3),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
        ),
      ),
    );
  }

  Widget _tile({required VoidCallback onTap, required bool on, required IconData icon, required String label}) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: on ? AppColors.accentSoft : AppColors.card,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: on ? AppColors.accent : AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: on ? Colors.white : AppColors.paper2, borderRadius: BorderRadius.circular(9)),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(label, style: AppFonts.body(size: 12, weight: FontWeight.w600, color: AppColors.ink))),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: on ? AppColors.accent : AppColors.line2),
        ),
        child: Text(label, style: AppFonts.body(size: 13, weight: FontWeight.w600, color: on ? Colors.white : AppColors.ink2)),
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback? onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(width: 8),
          Icon(icon, size: 17),
        ],
      ),
    );
  }
}
