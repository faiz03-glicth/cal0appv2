import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/viewauth/register_viewmodel.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/app_dropdown.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/app_message_banner.dart';
import 'package:cal0appv2/views/widgets/app_section_title.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _userName = TextEditingController();
  final _userEmail = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  String _gender = 'male';
  String _goal = 'maintain';
  String _activityLevel = 'moderately active';
  DateTime _birthday = DateTime(2000);

  @override
  void dispose() {
    _userName.dispose();
    _userEmail.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  Future<void> _register(RegisterViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    final success = await vm.register(
      userName: _userName.text.trim(),
      userEmail: _userEmail.text.trim(),
      userPassword: _password.text,
      confirmPassword: _confirmPassword.text,
      gender: _gender,
      goal: _goal,
      activityLevel: _activityLevel,
      birthday: _birthday,
      weight: double.tryParse(_weight.text) ?? 0,
      height: double.tryParse(_height.text) ?? 0,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created!'),
          backgroundColor: C0Theme.successGreen,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<RegisterViewModel>(context);
    return Scaffold(
      backgroundColor: C0Theme.oatmealWhite,
      appBar: AppBar(
        backgroundColor: C0Theme.oatmealWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: C0Theme.deepSage,
            size: AppSizes.fieldIconSize,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Account',
          style: AppTextStyles.title.copyWith(color: C0Theme.deepSage),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vm.errorMessage != null) ...[
                  AppMessageBanner.error(message: vm.errorMessage!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const AppSectionTitle(title: 'Account Info'),
                AppTextField(
                  controller: _userName,
                  label: 'Username',
                  hint: 'Enter Username',
                  icon: Icons.person,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _userEmail,
                  label: 'Email',
                  hint: 'Enter Email',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => !v!.contains('@') ? 'Invalid email' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _password,
                  label: 'Password',
                  hint: 'Enter Password',
                  icon: Icons.lock,
                  obscure: true,
                  validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _confirmPassword,
                  label: 'Confirm Password',
                  hint: 'Re-enter Password',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator: (v) =>
                      v != _password.text ? 'Passwords do not match' : null,
                ),
                const AppSectionTitle(title: 'Body Info'),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _weight,
                        label: 'Weight (kg)',
                        hint: 'kg',
                        icon: Icons.monitor_weight,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        controller: _height,
                        label: 'Height (cm)',
                        hint: 'cm',
                        icon: Icons.height,
                        isNumber: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Birthday',
                  style: AppTextStyles.fieldLabel.copyWith(
                    color: C0Theme.charcoal,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _BirthdayField(birthday: _birthday, onTap: _pickBirthday),
                const AppSectionTitle(title: 'Preferences'),
                AppDropdown(
                  label: 'Gender',
                  value: _gender,
                  items: const ['male', 'female'],
                  onChanged: (v) => setState(() => _gender = v!),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppDropdown(
                  label: 'Goal',
                  value: _goal,
                  items: const [
                    'maintain',
                    'lose weight',
                    'lose weight fast',
                    'gain weight',
                    'gain weight fast',
                  ],
                  onChanged: (v) => setState(() => _goal = v!),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppDropdown(
                  label: 'Activity Level',
                  value: _activityLevel,
                  items: const [
                    'sedentary',
                    'lightly active',
                    'moderately active',
                    'very active',
                    'extra active',
                  ],
                  onChanged: (v) => setState(() => _activityLevel = v!),
                ),
                const SizedBox(height: AppSpacing.xxl + 4),
                AppPrimaryButton(
                  label: 'Create Account',
                  isLoading: vm.isLoading,
                  onPressed: () => _register(vm),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
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
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BirthdayField extends StatelessWidget {
  final DateTime birthday;
  final VoidCallback onTap;
  const _BirthdayField({required this.birthday, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: c.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.formBorder, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cake_outlined,
              color: c.primary,
              size: AppSizes.fieldIconSize,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${birthday.day}/${birthday.month}/${birthday.year}',
              style: AppTextStyles.fieldText.copyWith(color: c.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
