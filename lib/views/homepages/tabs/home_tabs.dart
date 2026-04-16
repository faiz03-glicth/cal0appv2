import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeTab extends StatelessWidget {
  const HomeTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home, size: 64, color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(
              'Welcome back!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
