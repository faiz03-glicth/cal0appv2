import 'package:flutter/material.dart';
import 'package:cal0appv2/views/users/userprofile_view.dart';
import 'package:cal0appv2/views/homepages/tabs/home_tabs.dart';
import 'package:cal0appv2/views/homepages/tabs/scan_tabs.dart';
import 'package:cal0appv2/views/homepages/tabs/dashboard_tabs.dart';
import 'package:cal0appv2/views/debug/debug_view.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeTab(),
    const DashboardTab(),
    const ScanTab(),
    const UserProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("C0 App"),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugView()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
