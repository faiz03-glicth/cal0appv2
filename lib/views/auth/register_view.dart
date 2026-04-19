import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/viewauth/register_viewmodel.dart';

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
      backgroundColor: C0Theme.oatmealWhite, // 👈 always light bg
      appBar: AppBar(
        backgroundColor: C0Theme.oatmealWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: C0Theme.deepSage,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: C0Theme.deepSage,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error banner
                if (vm.errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: C0Theme.warningRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: C0Theme.warningRed.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      vm.errorMessage!,
                      style: const TextStyle(
                        color: C0Theme.warningRed,
                        fontSize: 13,
                      ),
                    ),
                  ),

                _sectionTitle('Account Info'),
                _buildField(
                  _userName,
                  'Username',
                  Icons.person,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                _buildField(
                  _userEmail,
                  'Email',
                  Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => !v!.contains('@') ? 'Invalid email' : null,
                ),
                _buildField(
                  _password,
                  'Password',
                  Icons.lock,
                  obscure: true,
                  validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                ),
                _buildField(
                  _confirmPassword,
                  'Confirm Password',
                  Icons.lock_outline,
                  obscure: true,
                  validator: (v) =>
                      v != _password.text ? 'Passwords do not match' : null,
                ),

                _sectionTitle('Body Info'),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        _weight,
                        'Weight (kg)',
                        Icons.monitor_weight,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        _height,
                        'Height (cm)',
                        Icons.height,
                        isNumber: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Birthday
                _fieldLabel('Birthday'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickBirthday,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFDDDDD8),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cake_outlined,
                          color: C0Theme.deepSage,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_birthday.day}/${_birthday.month}/${_birthday.year}',
                          style: const TextStyle(
                            color: C0Theme.charcoal,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _sectionTitle('Preferences'),
                _buildDropdown('Gender', _gender, [
                  'male',
                  'female',
                ], (v) => setState(() => _gender = v!)),
                _buildDropdown('Goal', _goal, [
                  'maintain',
                  'lose weight',
                  'lose weight fast',
                  'gain weight',
                  'gain weight fast',
                ], (v) => setState(() => _goal = v!)),
                _buildDropdown(
                  'Activity Level',
                  _activityLevel,
                  [
                    'sedentary',
                    'lightly active',
                    'moderately active',
                    'very active',
                    'extra active',
                  ],
                  (v) => setState(() => _activityLevel = v!),
                ),

                const SizedBox(height: 28),

                // Register button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C0Theme.deepSage,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: vm.isLoading ? null : () => _register(vm),
                    child: vm.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Back to login
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: C0Theme.slateGrey,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: C0Theme.deepSage,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── helpers

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: C0Theme.deepSage,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: C0Theme.charcoal,
    ),
  );

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
    bool isNumber = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel(label),
      const SizedBox(height: 8),
      TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType:
            keyboardType ??
            (isNumber ? TextInputType.number : TextInputType.text),
        validator: validator,
        style: const TextStyle(color: C0Theme.charcoal, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Enter $label',
          hintStyle: const TextStyle(color: C0Theme.slateGrey, fontSize: 14),
          prefixIcon: Icon(icon, color: C0Theme.deepSage, size: 20),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDDDD8), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C0Theme.deepSage, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C0Theme.warningRed, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C0Theme.warningRed, width: 1.5),
          ),
          errorMaxLines: 2,
        ),
      ),
      const SizedBox(height: 16),
    ],
  );

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel(label),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: value,
        dropdownColor: Colors.white,
        style: const TextStyle(color: C0Theme.charcoal, fontSize: 15),
        icon: const Icon(Icons.keyboard_arrow_down, color: C0Theme.deepSage),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDDDD8), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: C0Theme.deepSage, width: 1.5),
          ),
        ),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: onChanged,
      ),
      const SizedBox(height: 16),
    ],
  );
}
