import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Widget buildDateFilterSelector({
  required BuildContext context,
  required DateTime? selectedDate,
  required Function() onSelectDate,
  required Function() onClearDate,
}) {
  return GestureDetector(
    onTap: onSelectDate,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDDDDD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Color(0xFF003366), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              selectedDate == null
                  ? 'All Dates'
                  : DateFormat('MMM dd, yyyy').format(selectedDate),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (selectedDate != null)
            GestureDetector(
              onTap: onClearDate,
              child: const Icon(Icons.close, size: 18, color: Colors.grey),
            ),
        ],
      ),
    ),
  );
}
