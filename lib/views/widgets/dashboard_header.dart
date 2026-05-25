import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/usermodel/user_viewmodel.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final userVM = context.watch<UserViewModel>();
    final name = userVM.userName.isNotEmpty ? userVM.userName : 'User';
    final String initial = name[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      color: c.header,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getDynamicGreeting(),
                style: const TextStyle(
                  color: C0Theme.oatmealWhite,
                  fontSize: 13,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  color: C0Theme.oatmealWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          CircleAvatar(
            backgroundColor: C0Theme.oatmealWhite,
            child: Text(
              initial,
              style: const TextStyle(
                color: C0Theme.charcoal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}
