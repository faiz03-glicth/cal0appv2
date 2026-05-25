import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/views/widgets/c0_app_bar.dart';
import 'package:cal0appv2/viewModels/usermodel/user_viewmodel.dart';
import 'package:cal0appv2/viewModels/theme/theme_viewmodel.dart';
import 'package:cal0appv2/viewModels/health/health_warning_viewmodel.dart';
import 'package:cal0appv2/models/health/health_condition.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/app_dropdown.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/app_message_banner.dart';
import 'package:cal0appv2/views/widgets/app_section_title.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';

class UserProfileView extends StatefulWidget {
  const UserProfileView({super.key});
  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _userName = TextEditingController();
  final _userEmail = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _password = TextEditingController();

  String _gender = 'male';
  String _goal = 'maintain';
  String _activityLevel = 'moderately active';
  DateTime _birthday = DateTime(2000);
  final Set<HealthCondition> _conditions = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty || !mounted) return;
      final vm = context.read<UserViewModel>();
      await vm.loadUser(uid);
      final u = vm.user;
      if (u != null && mounted) {
        _userName.text = u.userName;
        _userEmail.text = u.userEmail;
        _weight.text = u.weight.toString();
        _height.text = u.height.toString();
        setState(() {
          _gender = u.gender;
          _goal = u.goal;
          _activityLevel = u.activityLevel;
          _birthday = u.birthday;
          _conditions
            ..clear()
            ..addAll(u.healthConditions);
        });
      }
    });
  }

  @override
  void dispose() {
    _userName.dispose();
    _userEmail.dispose();
    _weight.dispose();
    _height.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save(UserViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await vm.updateProfile(
      userId: uid,
      userName: _userName.text,
      userEmail: _userEmail.text,
      gender: _gender,
      goal: _goal,
      activityLevel: _activityLevel,
      birthday: _birthday,
      weight: double.tryParse(_weight.text) ?? 0,
      height: double.tryParse(_height.text) ?? 0,
      healthConditions: _conditions.toList(),
    );
    if (mounted) {
      context.read<HealthWarningViewModel>().updateConditions(
        _conditions.toList(),
      );
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserViewModel>();
    final themeVm = context.watch<ThemeViewModel>();
    final c = C0Theme.of(context);

    return Scaffold(
      appBar: C0AppBar(title: 'My Profile'),
      backgroundColor: c.background,
      body: vm.isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: c.primary,
                        child: Text(
                          _userName.text.isNotEmpty
                              ? _userName.text[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.heading.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    if (vm.errorMessage != null) ...[
                      AppMessageBanner.error(message: vm.errorMessage!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (vm.successMessage != null) ...[
                      AppMessageBanner.success(message: vm.successMessage!),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ── App Settings (dark mode lives here now) ────────
                    const AppSectionTitle(title: 'App Settings'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            themeVm.isDark ? Icons.dark_mode : Icons.light_mode,
                            color: themeVm.isDark ? Colors.amber : c.primary,
                            size: 22,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              themeVm.isDark ? 'Dark Mode' : 'Light Mode',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w500,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          Switch(
                            value: themeVm.isDark,
                            onChanged: (_) => themeVm.toggleTheme(),
                            activeThumbColor: c.primary,
                            activeTrackColor: c.track,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Account info ───────────────────────────────────
                    const AppSectionTitle(title: 'Account Info'),
                    AppTextField(
                      controller: _userName,
                      label: 'Username',
                      hint: 'Your name',
                      icon: Icons.person,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _userEmail,
                      label: 'Email',
                      hint: 'Email address',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          !v!.contains('@') ? 'Invalid email' : null,
                    ),

                    // ── Body info ──────────────────────────────────────
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
                    const SizedBox(height: AppSpacing.xs),
                    ListTile(
                      tileColor: c.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      leading: Icon(Icons.cake, color: c.primary),
                      title: Text(
                        'Birthday',
                        style: AppTextStyles.body.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${_birthday.day}/${_birthday.month}/${_birthday.year}',
                        style: AppTextStyles.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                      onTap: _pickBirthday,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Preferences ────────────────────────────────────
                    const AppSectionTitle(title: 'Preferences'),
                    AppDropdown(
                      label: 'Gender',
                      value: _gender,
                      items: const ['male', 'female'],
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                    const SizedBox(height: AppSpacing.md),
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
                    const SizedBox(height: AppSpacing.md),
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

                    // ── Health conditions ──────────────────────────────
                    _HealthConditionsSection(
                      selected: _conditions,
                      onToggle: (cond) => setState(() {
                        _conditions.contains(cond)
                            ? _conditions.remove(cond)
                            : _conditions.add(cond);
                      }),
                    ),

                    // ── Password ───────────────────────────────────────
                    const AppSectionTitle(title: 'Change Password'),
                    AppTextField(
                      controller: _password,
                      label: 'New Password',
                      hint: 'Leave blank to keep current',
                      icon: Icons.lock,
                      obscure: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.primary),
                          foregroundColor: c.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        onPressed: _password.text.isNotEmpty
                            ? () => vm.updatePassword(
                                FirebaseAuth.instance.currentUser!.uid,
                                _password.text,
                              )
                            : null,
                        child: const Text('Update Password'),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    AppPrimaryButton(
                      label: 'Save Profile',
                      isLoading: vm.isLoading,
                      onPressed: () => _save(vm),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Health conditions section ─────────────────────────────────────────────────

class _HealthConditionsSection extends StatelessWidget {
  final Set<HealthCondition> selected;
  final ValueChanged<HealthCondition> onToggle;
  const _HealthConditionsSection({
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionTitle(title: 'Health Conditions'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: c.primary,
                size: AppSizes.smallIconSize,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Select conditions to receive personalised food warnings before logging.',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: HealthCondition.values
              .map(
                (cond) => GestureDetector(
                  onTap: () => onToggle(cond),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected.contains(cond) ? c.primary : c.fieldFill,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: selected.contains(cond)
                            ? c.primary
                            : c.formBorder,
                        width: selected.contains(cond) ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected.contains(cond)) ...[
                          Icon(
                            Icons.check,
                            size: AppSizes.miniIconSize,
                            color: Colors.white,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Text(
                          cond.shortLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: selected.contains(cond)
                                ? Colors.white
                                : c.textPrimary,
                            fontWeight: selected.contains(cond)
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF22c55e).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF22c55e),
                  size: 15,
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                  child: Text(
                    '${selected.length} condition${selected.length > 1 ? 's' : ''} active — warnings enabled.',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF22c55e),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
