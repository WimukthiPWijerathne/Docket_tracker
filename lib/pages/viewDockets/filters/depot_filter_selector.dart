import 'package:flutter/material.dart';

Widget buildDepotFilterSelector({
  required BuildContext context,
  required String? selectedDepot,
  required List<String> availableDepots,
  required Function(String?) onDepotSelected,
}) {
  return Container(
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
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedDepot,
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF003366)),
        isExpanded: true,
        hint: Row(
          children: const [
            Icon(Icons.location_on, color: Color(0xFF003366), size: 18),
            SizedBox(width: 8),
            Text('All Depots'),
          ],
        ),
        selectedItemBuilder: (context) {
          return availableDepots.map<Widget>((String item) {
            return Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF003366),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item == 'All' ? 'All Depots' : item,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          }).toList();
        },
        items: availableDepots.map<DropdownMenuItem<String>>((String item) {
          return DropdownMenuItem<String>(
            value: item == 'All' ? null : item,
            child: Text(
              item == 'All' ? 'All Depots' : item,
              style: const TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
        onChanged: onDepotSelected,
      ),
    ),
  );
}
