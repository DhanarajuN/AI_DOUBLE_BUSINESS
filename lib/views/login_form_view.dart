import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_repository.dart';
import '../routes/app_routes.dart';
import '../services/api_client.dart';
import '../services/business_lookup_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../viewmodels/login_view_model.dart';
import '../widgets/app_logo.dart';
import '../widgets/google_logo.dart';

class LoginFormView extends StatelessWidget {
  final bool showDefaultPasswordNotice;

  const LoginFormView({super.key, this.showDefaultPasswordNotice = false});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => LoginViewModel(ctx.read<AuthRepository>()),
      child: _LoginFormBody(showDefaultPasswordNotice: showDefaultPasswordNotice),
    );
  }
}

class _LoginFormBody extends StatefulWidget {
  final bool showDefaultPasswordNotice;

  const _LoginFormBody({required this.showDefaultPasswordNotice});

  @override
  State<_LoginFormBody> createState() => _LoginFormBodyState();
}

class _LoginFormBodyState extends State<_LoginFormBody> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
    if (widget.showDefaultPasswordNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your default password is Gosure@123'), behavior: SnackBarBehavior.floating),
        );
      });
    }
  }

  Future<void> _loadRememberedCredentials() async {
    final remembered =
        await context.read<SessionStorage>().readRememberedCredentials();
    if (remembered == null || !mounted) return;
    setState(() {
      _usernameCtrl.text = remembered.username;
      _passwordCtrl.text = remembered.password;
      _rememberMe = true;
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(LoginViewModel vm) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final success = await vm.login(username: username, password: password);
    if (success && mounted) {
      final storage = context.read<SessionStorage>();
      if (_rememberMe) {
        await storage.saveRememberedCredentials(username: username, password: password);
      } else {
        await storage.clearRememberedCredentials();
      }
      if (!mounted) return;
      await _navigateAfterAuth();
    }
  }

  Future<void> _submitGoogle(LoginViewModel vm) async {
    FocusScope.of(context).unfocus();
    final success = await vm.loginWithGoogle();
    if (success && mounted) {
      await _navigateAfterAuth();
    } else if (!success && mounted && vm.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage!), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _navigateAfterAuth() async {
    final user = context.read<AuthRepository>().currentUser;
    final identity = user?.username ?? '';
    final workspace = context.read<WorkspaceRepository>();
    await workspace.ensureBusinessBelongsTo(identity);
    await workspace.ensureDefaultBusiness(name: user?.name ?? 'My business', owner: user?.name ?? '', email: identity);
    if (!mounted) return;
    await resolveBusinessForEmail(context.read<SessionStorage>(), context.read<ApiClient>(), identity);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      backgroundColor: AppColors.paper2,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
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
                    child: Text('AI Double', style: AppFonts.display(size: 30, weight: FontWeight.w800, color: AppColors.chrome)),
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
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: AppColors.accent,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (value) => setState(() => _rememberMe = value ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        child: Text('Remember me', style: AppFonts.body(size: 13.5, color: AppColors.ink2)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                ],
              ),
            ),
          ),
            ),
            if (vm.isLoading)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.paper2.withOpacity(0.85),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.accent),
                    ),
                  ),
                ),
              ),
          ],
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
