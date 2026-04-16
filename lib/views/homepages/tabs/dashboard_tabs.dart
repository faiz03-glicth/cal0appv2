import 'package:flutter/material.dart';


class DashboardTab extends StatelessWidget {
  const DashboardTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Dashboard coming soon')),
    );
  }
}
