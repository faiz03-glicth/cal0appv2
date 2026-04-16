import 'package:flutter/material.dart';

class ScanTab extends StatelessWidget {
  const ScanTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Scanner coming soon')),
    );
  }
}
