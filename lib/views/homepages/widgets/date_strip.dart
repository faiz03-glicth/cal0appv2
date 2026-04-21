import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '/../theme/app_theme.dart';

class DateStrip extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const DateStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<DateStrip> {
  late final ScrollController _scrollController;
  late final List<DateTime> _dates;

  static const int _totalDays = 14;
  static const double _itemWidth = 48.0;
  static const double _itemSpacing = 8.0;

  DateTime _stripDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  void initState() {
    super.initState();
    final today = _stripDate(DateTime.now());

    // index 0 = 13 days ago, index 13 = today
    _dates = List.generate(
      _totalDays,
      (i) => today.subtract(Duration(days: _totalDays - 1 - i)),
    );

    // scroll so today is fully visible on the right
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected(animate: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected({bool animate = false}) {
    if (!_scrollController.hasClients) return;

    final index = _dates.indexWhere(
      (d) => d == _stripDate(widget.selectedDate),
    );
    if (index == -1) return;

    final viewportWidth = _scrollController.position.viewportDimension;
    final targetOffset =
        index * (_itemWidth + _itemSpacing) -
        (viewportWidth / 2) +
        (_itemWidth / 2);

    final clamped = targetOffset.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final today = _stripDate(DateTime.now());
    final selected = _stripDate(widget.selectedDate);

    return Container(
      color: c.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: _dates.length,
          separatorBuilder: (_, _) => const SizedBox(width: _itemSpacing),
          itemBuilder: (context, index) {
            final date = _dates[index];
            final isToday = date == today;
            final isSelected = date == selected;

            return GestureDetector(
              onTap: () {
                widget.onDateSelected(date);
              },
              child: Container(
                width: _itemWidth,
                decoration: BoxDecoration(
                  color: isSelected ? c.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday && !isSelected
                      ? Border.all(color: c.primary, width: 1.5)
                      : !isSelected
                      ? Border.all(color: c.divider, width: 1)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE').format(date), // Mon, Tue…
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
