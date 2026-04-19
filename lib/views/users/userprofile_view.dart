import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cal0appv2/views/homepages/widgets/c0_app_bar.dart';
import 'package:cal0appv2/viewModels/usermodel/user_viewmodel.dart';
// 👆 removed unused ThemeViewModel import

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
          _birthday = u.birthday ?? DateTime(2000);
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
          backgroundColor: C0Theme.successGreen,
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
    final c = C0Theme.of(context);

    return Scaffold(
      appBar: C0AppBar(title: 'My Profile', showBack: false),
      backgroundColor: c.background,
      body: vm.isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
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
                        backgroundColor: c.primary,
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

                    // Banners
                    if (vm.errorMessage != null)
                      _buildBanner(vm.errorMessage!, c.warning),
                    if (vm.successMessage != null)
                      _buildBanner(vm.successMessage!, c.success),

                    // Account info
                    _sectionTitle('Account Info', c),
                    _buildTextField(
                      _userName,
                      'Username',
                      Icons.person,
                      c,
                      validator: (v) =>
                          v!.isEmpty ? 'Username is required' : null,
                    ),
                    _buildTextField(
                      _userEmail,
                      'Email',
                      Icons.email,
                      c,
                      validator: (v) =>
                          !v!.contains('@') ? 'Invalid email' : null,
                    ),

                    // Body info
                    _sectionTitle('Body Info', c),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _weight,
                            'Weight (kg)',
                            Icons.monitor_weight,
                            c,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            _height,
                            'Height (cm)',
                            Icons.height,
                            c,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),

                    // Birthday
                    const SizedBox(height: 4),
                    ListTile(
                      tileColor: c.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(Icons.cake, color: c.primary),
                      title: Text(
                        'Birthday',
                        style: TextStyle(color: c.textPrimary),
                      ),
                      subtitle: Text(
                        '${_birthday.day}/${_birthday.month}/${_birthday.year}',
                        style: TextStyle(color: c.textSecondary),
                      ),
                      onTap: _pickBirthday,
                    ),
                    const SizedBox(height: 12),

                    // Preferences
                    _sectionTitle('Preferences', c),
                    _buildDropdown(
                      'Gender',
                      _gender,
                      ['male', 'female'],
                      (v) => setState(() => _gender = v!),
                      c,
                    ),
                    _buildDropdown(
                      'Goal',
                      _goal,
                      [
                        'maintain',
                        'lose weight',
                        'lose weight fast',
                        'gain weight',
                        'gain weight fast',
                      ],
                      (v) => setState(() => _goal = v!),
                      c,
                    ),
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
                      c,
                    ),

                    // Change password
                    _sectionTitle('Change Password', c),
                    _buildTextField(
                      _password,
                      'New Password',
                      Icons.lock,
                      c,
                      obscure: true,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.primary),
                          foregroundColor: c.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _saveProfile(vm),
                        child: const Text(
                          'Save Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _sectionTitle(String title, C0Colors c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: c.primary,
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
    IconData icon,
    C0Colors c, {
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
      style: TextStyle(color: c.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textSecondary),
        prefixIcon: Icon(icon, color: c.primary),
        filled: true,
        fillColor: c.card,
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
          borderSide: BorderSide(
            color: c.textSecondary.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.warning, width: 1),
        ),
        errorMaxLines: 2,
      ),
    ),
  );

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
    C0Colors c,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      value: value,
      dropdownColor: c.card,
      style: TextStyle(color: c.textPrimary, fontSize: 15),
      icon: Icon(Icons.keyboard_arrow_down, color: c.primary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textSecondary),
        filled: true,
        fillColor: c.card,
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
          borderSide: BorderSide(
            color: c.textSecondary.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
    ),
  );
}
