import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../viewmodels/login_view_model.dart';
import '../widgets/app_logo.dart';
import '../widgets/google_logo.dart';

/// The "Sign in to continue" form screen — reached from the chrome landing
/// page's Sign in button. Username/password + Google, matching the design
/// reference exactly.
class LoginFormView extends StatelessWidget {
  const LoginFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => LoginViewModel(ctx.read<AuthRepository>()),
      child: const _LoginFormBody(),
    );
  }
}

class _LoginFormBody extends StatefulWidget {
  const _LoginFormBody();

  @override
  State<_LoginFormBody> createState() => _LoginFormBodyState();
}

class _LoginFormBodyState extends State<_LoginFormBody> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final TapGestureRecognizer _registerRecognizer;

  @override
  void initState() {
    super.initState();
    _registerRecognizer = TapGestureRecognizer()..onTap = _register;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _registerRecognizer.dispose();
    super.dispose();
  }

  Future<void> _submit(LoginViewModel vm) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final success = await vm.login(username: _usernameCtrl.text.trim(), password: _passwordCtrl.text);
    if (success && mounted) {
      _navigateAfterAuth();
    }
  }

  Future<void> _submitGoogle(LoginViewModel vm) async {
    FocusScope.of(context).unfocus();
    final success = await vm.loginWithGoogle();
    if (success && mounted) {
      _navigateAfterAuth();
    } else if (!success && mounted && vm.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage!), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _navigateAfterAuth() {
    final hasBusiness = context.read<WorkspaceRepository>().business != null;
    Navigator.of(context).pushReplacementNamed(hasBusiness ? AppRoutes.home : AppRoutes.signup);
  }

  void _register() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      backgroundColor: AppColors.paper2,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogoMark(size: 76)),
                  const SizedBox(height: 20),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: AppFonts.display(size: 30, weight: FontWeight.w800, color: AppColors.ink),
                        children: [
                          const TextSpan(text: 'AI '),
                          TextSpan(
                            text: 'Double',
                            style: AppFonts.display(size: 30, weight: FontWeight.w700, color: AppColors.warm)
                                .copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text('Sign in to continue', style: AppFonts.body(size: 14.5, color: AppColors.ink2)),
                  ),
                  const SizedBox(height: 32),
                  if (vm.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.08),
                        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(vm.errorMessage!, style: AppFonts.body(size: 12.5, color: AppColors.danger)),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _field(
                    controller: _usernameCtrl,
                    hint: 'Username',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Enter your username';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _passwordCtrl,
                    hint: 'Password',
                    obscureText: vm.obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        vm.obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.ink3,
                        size: 19,
                      ),
                      onPressed: vm.toggleObscurePassword,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your password';
                      if (v.length < 6) return 'Must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                    onPressed: vm.isLoading ? null : () => _submit(vm),
                    child: vm.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.line2)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: AppFonts.mono(size: 11, color: AppColors.ink3)),
                      ),
                      Expanded(child: Divider(color: AppColors.line2)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.card,
                      side: BorderSide(color: AppColors.line2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                    onPressed: vm.isLoading ? null : () => _submitGoogle(vm),
                    child: vm.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.ink3),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const GoogleLogo(size: 19),
                              const SizedBox(width: 11),
                              Text('Continue with Google', style: AppFonts.body(size: 15, weight: FontWeight.w600, color: AppColors.ink)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 26),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: AppFonts.body(size: 13.5, color: AppColors.ink2),
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Register',
                            style: AppFonts.body(size: 13.5, weight: FontWeight.w700, color: AppColors.accent),
                            recognizer: _registerRecognizer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: AppFonts.body(size: 14.5, color: AppColors.ink),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppFonts.body(size: 14.5, color: AppColors.ink3),
        filled: true,
        fillColor: AppColors.paper,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent, width: 1.4)),
        errorBorder: border.copyWith(borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }
}
