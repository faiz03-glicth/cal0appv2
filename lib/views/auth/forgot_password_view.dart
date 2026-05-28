import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/viewauth/forgot_password_viewmodel.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/app_message_banner.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ForgotPasswordViewModel(),
      child: const _ForgotPasswordBody(),
    );
  }
}

class _ForgotPasswordBody extends StatefulWidget {
  const _ForgotPasswordBody();

  @override
  State<_ForgotPasswordBody> createState() => _ForgotPasswordBodyState();
}

class _ForgotPasswordBodyState extends State<_ForgotPasswordBody> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ForgotPasswordViewModel>();
    final c = C0Theme.of(context);

    return Scaffold(
      backgroundColor: C0Theme.oatmealWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: C0Theme.deepSage,
            size: AppSizes.fieldIconSize,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl + 4,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // ── Header ────────────────────────────────────────────
              Center(
                child: Container(
                  width: AppSizes.avatarMd,
                  height: AppSizes.avatarMd,
                  decoration: BoxDecoration(
                    color: C0Theme.deepSage.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    border: Border.all(
                      color: C0Theme.deepSage.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_reset_outlined,
                    color: C0Theme.deepSage,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Text(
                  'Forgot Password',
                  style: AppTextStyles.heading.copyWith(
                    color: C0Theme.deepSage,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(
                  vm.emailSent
                      ? 'Check your email inbox'
                      : 'Enter your registered email and we\'ll\nsend you a reset link.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyCompact.copyWith(
                    color: C0Theme.slateGrey,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl + 8),

              // ── Success state ─────────────────────────────────────
              if (vm.emailSent) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: C0Theme.successGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: C0Theme.successGreen.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: C0Theme.successGreen,
                        size: 48,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Reset link sent!',
                        style: AppTextStyles.title.copyWith(
                          color: C0Theme.successGreen,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        vm.successMessage ?? '',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: C0Theme.slateGrey,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppPrimaryButton(
                  label: 'Back to Login',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: () {
                      context.read<ForgotPasswordViewModel>()
                        ..emailSent = false
                        ..clearMessages();
                      setState(() => _emailCtrl.clear());
                    },
                    child: Text(
                      'Resend email',
                      style: AppTextStyles.bodyCompact.copyWith(
                        color: C0Theme.deepSage,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // ── Email input ───────────────────────────────────
                AppTextField(
                  controller: _emailCtrl,
                  label: 'Email Address',
                  hint: 'Enter your registered email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),

                if (vm.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppMessageBanner.error(message: vm.errorMessage!),
                ],

                const SizedBox(height: AppSpacing.xxl + 4),

                AppPrimaryButton(
                  label: 'Send Reset Link',
                  isLoading: vm.isLoading,
                  icon: Icons.send_outlined,
                  onPressed: () => context
                      .read<ForgotPasswordViewModel>()
                      .sendResetEmail(_emailCtrl.text),
                ),

                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Remember your password? ',
                        style: AppTextStyles.bodyCompact.copyWith(
                          color: C0Theme.slateGrey,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Login',
                          style: AppTextStyles.bodyCompact.copyWith(
                            color: C0Theme.deepSage,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
