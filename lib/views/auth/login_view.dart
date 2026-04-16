import "package:flutter/material.dart";
import 'package:provider/provider.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'register_view.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<AuthViewModel>(context);
    final email = TextEditingController();
    final password = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(hintText: "Email"),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(hintText: "Password"),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterView()),
              ),
              child: const Text("Don't have an account? Register"),
            ),
            if (vm.errorMessage != null)
              Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),
            vm.isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () => vm.signIn(email.text, password.text),
                    child: const Text("Login"),
                  ),
          ],
        ),
      ),
    );
  }
}
