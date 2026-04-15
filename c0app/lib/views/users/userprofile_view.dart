import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:c0app/viewModels/usermodel/user_viewmodel.dart';

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

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser!.uid;
    Future.microtask(() async {
      final vm = Provider.of<UserViewModel>(context, listen: false);
      await vm.loadUser(userId);
      final u = vm.user;
      if (u != null) {
        _userName.text = u.userName;
        _userEmail.text = u.userEmail;
        _weight.text = u.weight.toString();
        _height.text = u.height.toString();
        setState(() {
          _gender = u.gender;
          _goal = u.goal;
          _activityLevel = u.activityLevel;
          _birthday = u.birthday;
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

  Future<void> _saveProfile(UserViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    await vm.updateProfile(
      userId: FirebaseAuth.instance.currentUser!.uid,
      userName: _userName.text,
      userEmail: _userEmail.text,
      gender: _gender,
      goal: _goal,
      activityLevel: _activityLevel,
      birthday: _birthday,
      weight: double.tryParse(_weight.text) ?? 0,
      height: double.tryParse(_height.text) ?? 0,
    );
    if (vm.successMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.successMessage!),
          backgroundColor: Colors.green,
        ),
      );
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
    final vm = Provider.of<UserViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.deepPurple,
                        child: Text(
                          _userName.text.isNotEmpty
                              ? _userName.text[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error / success messages
                    if (vm.errorMessage != null)
                      _buildBanner(vm.errorMessage!, Colors.red),
                    if (vm.successMessage != null)
                      _buildBanner(vm.successMessage!, Colors.green),

                    // Section: Account info
                    _sectionTitle('Account Info'),
                    _buildTextField(
                      _userName,
                      'Username',
                      Icons.person,
                      validator: (v) =>
                          v!.isEmpty ? 'Username is required' : null,
                    ),
                    _buildTextField(
                      _userEmail,
                      'Email',
                      Icons.email,
                      validator: (v) =>
                          !v!.contains('@') ? 'Invalid email' : null,
                    ),

                    // Section: Body info
                    _sectionTitle('Body Info'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _weight,
                            'Weight (kg)',
                            Icons.monitor_weight,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            _height,
                            'Height (cm)',
                            Icons.height,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),

                    // Birthday picker
                    const SizedBox(height: 12),
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

                    // Gender
                    _buildDropdown('Gender', _gender, [
                      'male',
                      'female',
                    ], (v) => setState(() => _gender = v!)),

                    // Goal
                    _buildDropdown('Goal', _goal, [
                      'maintain',
                      'lose weight',
                      'lose weight fast',
                      'gain weight',
                      'gain weight fast',
                    ], (v) => setState(() => _goal = v!)),

                    // Activity level
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

                    // Section: Change password
                    _sectionTitle('Change Password'),
                    _buildTextField(
                      _password,
                      'New Password',
                      Icons.lock,
                      obscure: true,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _password.text.isNotEmpty
                            ? () => vm.updatePassword(
                                FirebaseAuth.instance.currentUser!.uid,
                                _password.text,
                              )
                            : null,
                        child: const Text('Update Password'),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save button
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
                        onPressed: () => _saveProfile(vm),
                        child: const Text(
                          'Save Profile',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
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

  Widget _buildBanner(String message, Color color) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color),
    ),
    child: Text(message, style: TextStyle(color: color)),
  );

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
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
