import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../design/tokens.dart';

class DateStrip extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final Color? accentColor; // Optional color parameter
  
  const DateStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.accentColor,
  });

  @override
  State<DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<DateStrip> {
  late ScrollController _scrollController;
  late List<DateTime> _dates;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _generateDates();
    
    // Scroll to selected date after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _generateDates() {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day - 15);
    
    _dates = List.generate(60, (index) {
      return startDate.add(Duration(days: index));
    });
  }
  
  void _scrollToSelectedDate() {
    final selectedIndex = _dates.indexWhere((date) => 
        _isSameDay(date, widget.selectedDate));
    
    if (selectedIndex != -1 && _scrollController.hasClients) {
      final scrollOffset = (selectedIndex * 56.0) - 
          (MediaQuery.of(context).size.width / 2) + 28;
      final max = _scrollController.position.maxScrollExtent;
      final clamped = scrollOffset.isFinite
          ? scrollOffset.clamp(0.0, max)
          : 0.0;
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  bool _isToday(DateTime date) {
    return _isSameDay(date, DateTime.now());
  }
  
  void _navigateDate(int direction) {
    final newDate = widget.selectedDate.add(Duration(days: direction));
    widget.onDateSelected(newDate);
    
    // Update dates list if needed
    if (!_dates.any((date) => _isSameDay(date, newDate))) {
      _generateDates();
      setState(() {});
    }
    
    // Scroll to new date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? AppColors.emerald;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with selected date info and navigation arrows
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.calendar,
                  size: 16,
                  color: accentColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(widget.selectedDate),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateDate(-1),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.glassBackground,
                      borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: const Icon(
                      LucideIcons.chevronLeft,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: () => _navigateDate(1),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.glassBackground,
                      borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: const Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: AppSpacing.md),
        
        // Scrollable date strip
        SizedBox(
          height: 56,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _dates.length,
            itemBuilder: (context, index) {
              final date = _dates[index];
              final isSelected = _isSameDay(date, widget.selectedDate);
              final isToday = _isToday(date);
              
              return GestureDetector(
                onTap: () => widget.onDateSelected(date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? accentColor 
                        : AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(AppBorderRadius.full),
                    border: Border.all(
                      color: isSelected 
                          ? accentColor 
                          : isToday
                              ? accentColor.withOpacity(0.5)
                              : AppColors.glassBorder,
                      width: isToday && !isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected 
                        ? [
                            BoxShadow(
                              color: accentColor.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        date.day.toString(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isSelected 
                              ? Colors.black 
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: AppTextStyles.label.copyWith(
                          color: isSelected 
                              ? Colors.black.withOpacity(0.7) 
                              : AppColors.textTertiary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
