import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';

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

  Future<void> _register(AuthViewModel vm) async {
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
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // go back to login
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
    final vm = Provider.of<AuthViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    vm.errorMessage!,
                    style: const TextStyle(color: Colors.red),
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

              // Birthday
              const SizedBox(height: 4),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.cake, color: Colors.deepPurple),
                title: const Text('Birthday'),
                subtitle: Text(
                  '${_birthday.day}/${_birthday.month}/${_birthday.year}',
                ),
                onTap: _pickBirthday,
              ),
              const SizedBox(height: 12),

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

              const SizedBox(height: 24),

              // Register button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: vm.isLoading ? null : () => _register(vm),
                  child: vm.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Account',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Back to login
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(color: Colors.deepPurple),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.deepPurple,
      ),
    ),
  );

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
    ),
  );
}
