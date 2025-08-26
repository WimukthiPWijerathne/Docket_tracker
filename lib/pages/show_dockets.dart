import 'package:flutter/material.dart';
import 'assign.dart';

class ShowDocketsPage extends StatefulWidget {
  final String title;

  const ShowDocketsPage({super.key, required this.title});

  @override
  State<ShowDocketsPage> createState() => _ShowDocketsPageState();
}

class _ShowDocketsPageState extends State<ShowDocketsPage> {
  late final List<Map<String, String>> dockets;
  late final List<bool> status;

  @override
  void initState() {
    super.initState();
    dockets = List.generate(6, (index) {
      final DateTime date = DateTime.now().subtract(Duration(days: index));
      final String formatted =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return {
        'date': formatted,
        'location': 'Location ${index + 1}',
      };
    });
    status = List<bool>.filled(dockets.length, false);
  }

  Widget _buildSimpleRow(String date, String location, bool isSelected, int index,
      {bool isHeader = false}) {
    if (isHeader) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF003366).withOpacity(0.1),
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: const Row(
          children: [
            Expanded(
                flex: 3,
                child: Text('Date',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF003366)))),
            Expanded(
                flex: 3,
                child: Text('Location',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF003366)))),
            Expanded(
                flex: 2,
                child: Center(
                    child: Text('Status',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003366))))),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () {
        setState(() {
          status[index] = !status[index];
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF003366).withOpacity(0.05)
              : Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(date)),
            Expanded(flex: 3, child: Text(location)),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: isSelected
                            ? const Color(0xFF003366)
                            : Colors.grey),
                    borderRadius: BorderRadius.circular(3),
                    color:
                        isSelected ? const Color(0xFF003366) : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double rowHeight = 56.0;
    const double headerHeight = 56.0;
    const double maxHeight = 400.0;

    double contentHeight = headerHeight + (dockets.length * rowHeight);
    double tableHeight = contentHeight > maxHeight ? maxHeight : contentHeight;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 16),

            // Simple table container
            Container(
              height: tableHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildSimpleRow('Date', 'Location', false, -1,
                      isHeader: true),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: dockets.asMap().entries.map((entry) {
                        return _buildSimpleRow(
                          entry.value['date']!,
                          entry.value['location']!,
                          status[entry.key],
                          entry.key,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final selectedDockets = dockets.asMap().entries
                          .where((entry) => status[entry.key])
                          .map((entry) =>
                              '${entry.value['date']} - ${entry.value['location']}')
                          .toList();

                      if (selectedDockets.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select at least one docket'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AssignPage(dockets: selectedDockets),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Assign',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/docket_selection');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
