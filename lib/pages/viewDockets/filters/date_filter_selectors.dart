import 'package:flutter/material.dart';

/// Date filter selector widget - contains reusable UI components
class DateFilterSelectors {
  // Common style for filter buttons
  static BoxDecoration filterBoxDecoration() {
    return BoxDecoration(
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
    );
  }

  // Common style for filter chips
  static BoxDecoration filterChipDecoration({required bool isSelected}) {
    return BoxDecoration(
      color: isSelected ? const Color(0xFF003366) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF003366)),
    );
  }
}
