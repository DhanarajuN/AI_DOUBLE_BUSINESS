import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job_type_schema.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../routes/app_routes.dart';
import '../services/api_client.dart';
import '../services/business_lookup_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../viewmodels/signup_view_model.dart';
import '../widgets/app_logo.dart';
import 'login_form_view.dart';

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
    final error = await vm.complete();
    if (!mounted) return;
    if (error != null) {
      _warn(error);
      return;
    }
    await resolveBusinessForEmail(
      context.read<SessionStorage>(),
      context.read<ApiClient>(),
      context.read<AuthRepository>().currentUser?.username,
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginFormView(showDefaultPasswordNotice: true)),
      (route) => false,
    );
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
                    Text('AI Double', style: AppFonts.display(size: 16, weight: FontWeight.w800, color: AppColors.chrome)),
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
    return const [];
  }

  void _completeGroup(SignupViewModel vm, String group) {
    final error = vm.validateGroup(group);
    if (error != null) {
      _warn(error);
      return;
    }
    _complete(vm);
  }

  List<Widget> _buildGroupStep(SignupViewModel vm, String group) {
    final fields = vm.fieldsForGroup(group);
    final isLastStep = vm.step == vm.groupNames.length - 1;
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
          Expanded(
            child: _primaryButton(
              isLastStep ? (vm.submitting ? 'Creating…' : 'Create workspace') : 'Continue',
              Icons.arrow_forward,
              isLastStep
                  ? (vm.submitting ? null : () => _completeGroup(vm, group))
                  : () => _nextGroup(vm, group),
            ),
          ),
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
                    ? ((vm.valueOf(field.name) as Set<String>?)?.contains(o.submissionValue) ?? false)
                    : vm.valueOf(field.name) == o.submissionValue;
                return _chip(o.label, on, () => field.multiselect ? vm.toggleMultiValue(field, o) : vm.pickSingleValue(field, o));
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
