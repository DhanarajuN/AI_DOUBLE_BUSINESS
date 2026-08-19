import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job_type_schema.dart';
import '../models/plan.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../routes/app_routes.dart';
import '../services/api_client.dart';
import '../services/business_lookup_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../viewmodels/signup_view_model.dart';
import '../widgets/app_logo.dart';

class SignupView extends StatelessWidget {
  const SignupView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => SignupViewModel(ctx.read<AuthRepository>(), ctx.read<WorkspaceRepository>(), ctx.read<ApiClient>()),
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
  final _dynamicCtrls = <String, TextEditingController>{};

  TextEditingController _ctrlFor(String fieldName, {String initial = ''}) =>
      _dynamicCtrls.putIfAbsent(fieldName, () => TextEditingController(text: initial));

  @override
  void dispose() {
    for (final c in _dynamicCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _warn(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  void _nextGroup(SignupViewModel vm, String group) {
    final error = vm.validateGroup(group);
    if (error != null) {
      _warn(error);
      return;
    }
    vm.nextStep();
  }

  Future<void> _complete(SignupViewModel vm) async {
    await vm.complete();
    if (!mounted) return;
    await resolveBusinessForEmail(
      context.read<SessionStorage>(),
      context.read<ApiClient>(),
      context.read<AuthRepository>().currentUser?.username,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  void _handleBack(SignupViewModel vm) {
    if (vm.step > 0) {
      vm.prevStep();
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SignupViewModel>();
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBack(vm);
      },
      child: Scaffold(
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
                _stepBarRow(vm),
                const SizedBox(height: 20),
                ..._buildCurrentStep(vm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBarRow(SignupViewModel vm) {
    final total = vm.totalSteps;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _stepBar(vm.step >= i)),
        ],
      ],
    );
  }

  Widget _stepBar(bool on) => Container(height: 4, decoration: BoxDecoration(color: on ? AppColors.accent : AppColors.line2, borderRadius: BorderRadius.circular(2)));

  List<Widget> _buildCurrentStep(SignupViewModel vm) {
    if (vm.schema == null) {
      if (vm.loadingSchema) {
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      }
      if (vm.schemaFailed) {
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
            child: Column(
              children: [
                Text("Couldn't load the signup form.", style: AppFonts.body(size: 13.5, color: AppColors.ink2)),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: vm.retryLoadSchema,
                  child: Text('Retry', style: AppFonts.body(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
                ),
              ],
            ),
          ),
        ];
      }
      return const [];
    }

    final groups = vm.groupNames;
    if (vm.step < groups.length) {
      return _buildGroupStep(vm, groups[vm.step]);
    }
    return _buildPlanStep(vm);
  }

  List<Widget> _buildGroupStep(SignupViewModel vm, String group) {
    final fields = vm.fieldsForGroup(group);
    return [
      Text(group, style: AppFonts.display(size: 24)),
      const SizedBox(height: 20),
      ...fields.map((f) => _fieldWidget(vm, f)),
      const SizedBox(height: 24),
      Row(
        children: [
          if (vm.step > 0) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.line2),
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              onPressed: vm.prevStep,
              child: Text('Back', style: AppFonts.body(size: 14.5, weight: FontWeight.w600, color: AppColors.ink)),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: _primaryButton('Continue', Icons.arrow_forward, () => _nextGroup(vm, group))),
        ],
      ),
    ];
  }

  Widget _fieldWidget(SignupViewModel vm, JobTypeField field) {
    if (field.type == 'Selection') return _selectionField(vm, field);
    return _dynamicTextField(vm, field);
  }

  Widget _selectionField(SignupViewModel vm, JobTypeField field) {
    final options = vm.optionsForField(field);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, mandatory: field.mandatory),
          const SizedBox(height: 8),
          if (options.isEmpty)
            Text('No options available.', style: AppFonts.body(size: 12.5, color: AppColors.ink3))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((o) {
                final on = field.multiselect
                    ? ((vm.valueOf(field.name) as Set<String>?)?.contains(o) ?? false)
                    : vm.valueOf(field.name) == o;
                return _chip(o, on, () => field.multiselect ? vm.toggleMultiValue(field, o) : vm.pickSingleValue(field, o));
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _dynamicTextField(SignupViewModel vm, JobTypeField field) {
    final ctrl = _ctrlFor(field.name, initial: (vm.valueOf(field.name) as String?) ?? '');
    final keyboardType = field.type == 'Email'
        ? TextInputType.emailAddress
        : field.type == 'Numeric Text'
            ? TextInputType.number
            : TextInputType.text;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, mandatory: field.mandatory),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: TextField(
              controller: ctrl,
              keyboardType: keyboardType,
              maxLines: field.name.toLowerCase().contains('description') ? 3 : 1,
              onChanged: (v) => vm.setTextValue(field.name, v),
              style: AppFonts.body(size: 14.5, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: field.label,
                hintStyle: AppFonts.body(size: 14, color: AppColors.ink3),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlanStep(SignupViewModel vm) {
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
            onPressed: vm.prevStep,
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

  Widget _label(String text, {bool mandatory = false}) => Text(
        mandatory ? '$text *' : text,
        style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink),
      );

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
