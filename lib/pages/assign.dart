import 'package:flutter/material.dart';
import 'summary.dart';
import 'docket_selection_page.dart';

class AssignPage extends StatefulWidget {
  final List<String> dockets;

  const AssignPage({Key? key, required this.dockets}) : super(key: key);

  @override
  State<AssignPage> createState() => _AssignPageState();
}

class _AssignPageState extends State<AssignPage> {
  final List<String> allWorkers = [
    'කමල්', 'අමල්', 'සුනිල්', 'චමින්ද',
    'රුවන්', 'නිමල්', 'සමන්', 'ජයන්ත',
  ];

  List<String> availableWorkers = [];
  List<String> selectedWorkers = [];
  List<String> assignedWorkers = [];

  @override
  void initState() {
    super.initState();
    availableWorkers = List.from(allWorkers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Worker'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Selected Dockets:",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...widget.dockets.map((d) => Text("• $d")).toList(),
            const SizedBox(height: 24),
            if (selectedWorkers.isNotEmpty) ...[
              const Text(
                'Selected Workers:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: selectedWorkers.map((worker) => Chip(
                  key: ValueKey('selected_$worker'),
                  label: Text(worker),
                  backgroundColor: Colors.blue[100],
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    if (selectedWorkers.contains(worker)) {
                      setState(() {
                        selectedWorkers.remove(worker);
                        if (!availableWorkers.contains(worker)) {
                          availableWorkers.add(worker);
                          availableWorkers.sort();
                        }
                      });
                    }
                  },
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Available Workers:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('available_workers_list'),
                itemCount: availableWorkers.length,
                itemBuilder: (context, index) {
                  if (index >= availableWorkers.length) return const SizedBox.shrink();
                  final worker = availableWorkers[index];
                  return Card(
                    key: ValueKey('available_$worker'),
                    child: ListTile(
                      title: Text(worker, style: const TextStyle(fontSize: 18)),
                      trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
                      onTap: () {
                        if (availableWorkers.contains(worker)) {
                          setState(() {
                            selectedWorkers.add(worker);
                            availableWorkers.remove(worker);
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            if (selectedWorkers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      assignedWorkers.addAll(selectedWorkers);
                      selectedWorkers.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${assignedWorkers.length} worker(s) assigned to ${widget.dockets.length} docket(s)',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Assign ${selectedWorkers.length} Worker(s)'),
                ),
              ),
            if (assignedWorkers.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Assigned Workers:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.green),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: assignedWorkers.map((worker) => Chip(
                  key: ValueKey('assigned_$worker'),
                  label: Text(worker),
                  backgroundColor: Colors.green[100],
                  avatar: const Icon(Icons.check, size: 16, color: Colors.green),
                )).toList(),
              ),
            ],
            const SizedBox(height: 24),
            // Bottom buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const DocketSelectionPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: assignedWorkers.isNotEmpty ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SummaryPage(
                            dockets: widget.dockets,
                            assignedWorkers: assignedWorkers,
                          ),
                        ),
                      );
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Assign',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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
