import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/views/auth/register_view.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/app_message_banner.dart';
import 'package:cal0appv2/views/auth/forgot_password_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<AuthViewModel>(context);
    return Scaffold(
      backgroundColor: C0Theme.oatmealWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl + 4,
            vertical: AppSpacing.xxxl + 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxxl + 8),
              const _LoginHeader(),
              const SizedBox(height: AppSpacing.xxxl + 16),
              AppTextField(
                controller: _email,
                label: 'Email',
                hint: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _password,
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline,
                obscure: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordView(),
                    ),
                  ),
                  child: Text(
                    'Forgot password?',
                    style: AppTextStyles.caption.copyWith(
                      color: C0Theme.deepSage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (vm.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppMessageBanner.error(message: vm.errorMessage!),
              ],
              const SizedBox(height: AppSpacing.xxl + 4),
              AppPrimaryButton(
                label: 'Login',
                isLoading: vm.isLoading,
                onPressed: () => vm.signIn(_email.text, _password.text),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _RegisterLink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            decoration: BoxDecoration(
              color: C0Theme.deepSage,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 40),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'C0 App',
            style: AppTextStyles.heading.copyWith(color: C0Theme.deepSage),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            'Track your nutrition daily',
            style: AppTextStyles.bodyCompact.copyWith(color: C0Theme.slateGrey),
          ),
        ],
      ),
    );
  }
}

class _RegisterLink extends StatelessWidget {
  const _RegisterLink();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: AppTextStyles.bodyCompact.copyWith(color: C0Theme.slateGrey),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterView()),
            ),
            child: Text(
              'Register',
              style: AppTextStyles.bodyCompact.copyWith(
                color: C0Theme.deepSage,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
