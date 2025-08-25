import 'package:flutter/material.dart';

class AssignPage extends StatefulWidget {
  final List<String> dockets;

  const AssignPage({Key? key, required this.dockets}) : super(key: key);

  @override
  State<AssignPage> createState() => _AssignPageState();
}

class _AssignPageState extends State<AssignPage> {
  final List<String> workers = [
    'කමල්', 'අමල්', 'සුනිල්', 'චමින්ද',
    'රුවන්', 'නිමල්', 'සමන්', 'ජයන්ත',
  ];

  String? selectedWorker;

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
            const Text(
              'Available Workers:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: workers.length,
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  final isSelected = worker == selectedWorker;
                  return Card(
                    color: isSelected ? Colors.blue[100] : null,
                    child: ListTile(
                      title: Text(worker, style: const TextStyle(fontSize: 18)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : null,
                      onTap: () {
                        setState(() {
                          selectedWorker = worker;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            if (selectedWorker != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$selectedWorker assigned to ${widget.dockets.length} docket(s)',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Assign ${selectedWorker!}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
