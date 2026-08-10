import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../viewmodels/login_view_model.dart';
import '../widgets/google_logo.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => LoginViewModel(ctx.read<AuthRepository>()),
      child: const _LoginBody(),
    );
  }
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPasswordForm = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(LoginViewModel vm) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final success = await vm.login(username: _usernameCtrl.text.trim(), password: _passwordCtrl.text);
    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  Future<void> _submitGoogle(LoginViewModel vm) async {
    FocusScope.of(context).unfocus();
    final success = await vm.loginWithGoogle();
    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } else if (!success && mounted && vm.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage!), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      backgroundColor: AppColors.chrome,
      body: Stack(
        children: [
          Positioned(
            right: -80,
            top: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.accent2.withOpacity(0.22), Colors.transparent]),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(color: AppColors.chrome, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 10),
                      RichText(
                        text: TextSpan(
                          style: AppFonts.display(size: 18, color: Colors.white),
                          children: [
                            const TextSpan(text: 'AI '),
                            TextSpan(text: 'Double', style: AppFonts.display(size: 18, weight: FontWeight.w800, color: AppColors.accent2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 56),
                  Text('PERSONAL AI · FOR YOUR BUSINESS', style: AppFonts.mono(size: 10.5, color: AppColors.chromeTx, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Text(
                    'Your customers,\nanswered instantly.',
                    style: AppFonts.display(size: 30, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.6).copyWith(height: 1.15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in to manage your AI agent, bookings and documents — tailored to your business.',
                    style: AppFonts.body(size: 14.5, color: AppColors.chromeTx).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  _feature(Icons.calendar_month_outlined, 'Every booking, taken and tracked automatically'),
                  const SizedBox(height: 11),
                  _feature(Icons.forum_outlined, 'Answers your customers from your own documents'),
                  const SizedBox(height: 11),
                  _feature(Icons.insights_outlined, 'Usage, plan and performance in one dashboard'),
                  const SizedBox(height: 40),
                  if (vm.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        border: Border.all(color: AppColors.danger.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(vm.errorMessage!, style: AppFonts.body(size: 12.5, color: Colors.white)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFDADCE0)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: vm.isLoading ? null : () => _submitGoogle(vm),
                      child: vm.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF3C4043)),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GoogleLogo(size: 19),
                                SizedBox(width: 11),
                                Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: Color(0xFF1f2937))),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.chromeLine)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: AppFonts.mono(size: 11, color: AppColors.chromeTx)),
                      ),
                      const Expanded(child: Divider(color: AppColors.chromeLine)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_showPasswordForm)
                    TextButton(
                      onPressed: () => setState(() => _showPasswordForm = true),
                      child: Text('Sign in with email', style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.chromeTx)),
                    )
                  else
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _field(
                            controller: _usernameCtrl,
                            hint: 'you@company.com',
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Enter your email';
                              if (!_emailRegex.hasMatch(value)) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          _field(
                            controller: _passwordCtrl,
                            hint: 'Password',
                            obscureText: vm.obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                vm.obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.chromeTx,
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
                          const SizedBox(height: 14),
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
                                : const Text('Continue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  Text(
                    'By continuing you agree to the Terms and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: AppFonts.body(size: 11, color: AppColors.chromeTx.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.chromeLine),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.accent2),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(text, style: AppFonts.body(size: 13.5, color: AppColors.chromeTx)),
          ),
        ),
      ],
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
      borderSide: const BorderSide(color: AppColors.chromeLine),
    );
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: AppFonts.body(size: 14.5, color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppFonts.body(size: 14.5, color: AppColors.chromeTx.withOpacity(0.6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        suffixIcon: suffixIcon,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent2)),
        errorBorder: border.copyWith(borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }
}
