import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../viewmodels/login_view_model.dart';
import '../widgets/app_logo.dart';
import '../widgets/toast.dart';
import 'login_form_view.dart';

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
  static const _showGuestOption = false;
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _emailCtrl = TextEditingController();
  bool _startingUp = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _openSignIn() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginFormView()));
  }

  Future<void> _getStarted(LoginViewModel vm) async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email to get started'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _startingUp = true);
    await vm.continueWithEmail(email);
    if (!mounted) return;
    await context.read<WorkspaceRepository>().ensureBusinessBelongsTo(email);
    if (!mounted) return;
    setState(() => _startingUp = false);
    Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
  }

  void _continueAsGuest(LoginViewModel vm) {
    FocusScope.of(context).unfocus();
    Toast.show(context, 'Guest access is coming soon');
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
                      const AppLogoMark(size: 26),
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
                  Text('PERSONAL AI · WITH RECEIPTS', style: AppFonts.mono(size: 10.5, color: AppColors.chromeTx, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Text(
                    'Your paperwork,\nhandled.',
                    style: AppFonts.display(size: 30, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.6).copyWith(height: 1.15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in to keep your documents, answers and voice history on your device — private to you.',
                    style: AppFonts.body(size: 14.5, color: AppColors.chromeTx).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  _feature(Icons.shield_outlined, 'Answers from your own documents, with the source named'),
                  const SizedBox(height: 11),
                  _feature(Icons.mic_none_outlined, 'Ask by voice or chat, in English, हिंदी or मराठी'),
                  const SizedBox(height: 11),
                  _feature(Icons.vpn_key_outlined, 'Your data stays on this device'),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: _openSignIn,
                      child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
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
                  _field(
                    controller: _emailCtrl,
                    hint: 'you@company.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.chromeLine),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: _startingUp ? null : () => _getStarted(vm),
                      child: _startingUp
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : Text('Get started', style: AppFonts.body(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  if (_showGuestOption) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: vm.isLoading ? null : () => _continueAsGuest(vm),
                        child: RichText(
                          text: TextSpan(
                            style: AppFonts.body(size: 13, color: AppColors.chromeTx),
                            children: [
                              const TextSpan(text: 'Just '),
                              TextSpan(
                                text: 'explore as a guest',
                                style: AppFonts.body(size: 13, weight: FontWeight.w700, color: AppColors.accent2),
                              ),
                              const TextSpan(text: ' →'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
    TextInputType? keyboardType,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.chromeLine),
    );
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppFonts.body(size: 14.5, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppFonts.body(size: 14.5, color: AppColors.chromeTx.withOpacity(0.6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent2)),
      ),
    );
  }
}
