// Function to implement the date and week filter selectors
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'date_filter_selectors.dart';

// Date filter selector widget
Widget buildDateFilterSelector({
  required BuildContext context,
  required DateTime? selectedDate,
  required Function() onPreviousDay,
  required Function() onNextDay,
  required Function() onClearFilter,
  required Function() onSelectDate,
}) {
  final dateLabel = selectedDate == null
      ? 'All Dates'
      : DateFormat('MMM dd, yyyy').format(selectedDate);

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(
      children: [
        // Previous day button
        IconButton(
          icon: const Icon(Icons.chevron_left),
          color: const Color(0xFF003366),
          onPressed: onPreviousDay,
          tooltip: 'Previous Day',
        ),

        // Date selector
        Expanded(
          child: GestureDetector(
            onTap: onSelectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: DateFilterSelectors.filterBoxDecoration(),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF003366),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (selectedDate != null)
                    GestureDetector(
                      onTap: onClearFilter,
                      child: const Icon(Icons.close, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Next day button
        IconButton(
          icon: const Icon(Icons.chevron_right),
          color: const Color(0xFF003366),
          onPressed: onNextDay,
          tooltip: 'Next Day',
        ),
      ],
    ),
  );
}

// Week filter selector widget
Widget buildWeekFilterSelector({
  required BuildContext context,
  required bool isWeekFilterActive,
  required DateTime? weekStartDate,
  required DateTime? weekEndDate,
  required Function() onPreviousWeek,
  required Function() onNextWeek,
  required Function() onCurrentWeek,
  required Function() onClearFilter,
}) {
  // Format the week date range
  final weekLabel = (weekStartDate == null || weekEndDate == null)
      ? 'All Weeks'
      : '${DateFormat('MMM dd').format(weekStartDate)} - ${DateFormat('MMM dd').format(weekEndDate)}';

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        // Previous week button
        IconButton(
          icon: const Icon(Icons.chevron_left),
          color: const Color(0xFF003366),
          onPressed: onPreviousWeek,
          tooltip: 'Previous Week',
        ),

        // Week selector
        Expanded(
          child: GestureDetector(
            onTap: onCurrentWeek,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: DateFilterSelectors.filterBoxDecoration(),
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range,
                    color: Color(0xFF003366),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    weekLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (isWeekFilterActive)
                    GestureDetector(
                      onTap: onClearFilter,
                      child: const Icon(Icons.close, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Next week button
        IconButton(
          icon: const Icon(Icons.chevron_right),
          color: const Color(0xFF003366),
          onPressed: onNextWeek,
          tooltip: 'Next Week',
        ),
      ],
    ),
  );
}
