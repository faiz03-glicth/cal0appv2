import 'package:flutter/material.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/views/homepages/widgets/c0_app_bar.dart';

class ScanTab extends StatelessWidget {
  const ScanTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: C0AppBar(title: "Scanner"),
      body: Center(child: Text('Scanner coming soon')),
    );
  }
}
