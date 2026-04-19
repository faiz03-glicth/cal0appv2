import 'package:flutter/material.dart';
import 'package:cal0appv2/theme/app_theme.dart';

class DateStrip extends StatelessWidget {
  const DateStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return Container(
      color: c.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.map<Widget>((d) {
          final isToday =
              d.day == now.day && d.month == now.month && d.year == now.year;

          return Column(
            children: [
              Text(
                dayLabels[d.weekday - 1],
                style: TextStyle(
                  color: isToday ? c.primary : c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isToday ? c.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday
                      ? null
                      : Border.all(color: c.divider, width: 1),
                ),
                child: Center(
                  child: Text(
                    '${d.day}',
                    style: TextStyle(
                      color: isToday ? Colors.white : c.textPrimary,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
