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

  // Create a soft, unique color for each worker based on their name
  Color _colorForName(String name) {
    final hash = name.runes.fold<int>(0, (p, c) => p + c);
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.45, 0.65).toColor();
  }

  String _initialForName(String name) {
    if (name.isEmpty) return '?';
    return name.characters.first; // works fine with Sinhala
  }

  String get _titleSuffix {
    if (widget.dockets.isEmpty) return '';
    if (widget.dockets.length == 1) {
      // Use the full docket label if only one docket selected
      return widget.dockets.first;
    }
    // For multiple dockets, show count in parentheses
    return '(${widget.dockets.length})';
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _titleSuffix.isEmpty
        ? 'Assign Workers'
        : 'Assign Workers ';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText, overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + selected dockets list
            Text(
              titleText,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.dockets.isNotEmpty) ...[
              const Text(
                "Selected Dockets:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...widget.dockets.map((d) => Text("• $d")).toList(),
              const SizedBox(height: 16),
            ],

            // Selected Workers (chips with avatar)
            if (selectedWorkers.isNotEmpty) ...[
              const Text(
                'Selected Workers:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedWorkers.map((worker) {
                  final color = _colorForName(worker);
                  return InputChip(
                    key: ValueKey('selected_$worker'),
                    avatar: CircleAvatar(
                      backgroundColor: color,
                      child: Text(
                        _initialForName(worker),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    label: Text(worker),
                    backgroundColor: Colors.blue[50],
                    onDeleted: () {
                      setState(() {
                        selectedWorkers.remove(worker);
                        if (!availableWorkers.contains(worker)) {
                          availableWorkers.add(worker);
                          availableWorkers.sort();
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Available Workers: grid of small cards with dummy avatars
            const Text(
              'Available Workers:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive columns
                  int crossAxisCount = 2;
                  if (constraints.maxWidth > 900) {
                    crossAxisCount = 4;
                  } else if (constraints.maxWidth > 600) {
                    crossAxisCount = 3;
                  }

                  return GridView.builder(
                    key: const ValueKey('available_workers_grid'),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: availableWorkers.length,
                    itemBuilder: (context, index) {
                      final worker = availableWorkers[index];
                      final color = _colorForName(worker);

                      return InkWell(
                        key: ValueKey('available_$worker'),
                        onTap: () {
                          setState(() {
                            selectedWorkers.add(worker);
                            availableWorkers.remove(worker);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: color,
                                  child: Text(
                                    _initialForName(worker),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  worker,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_circle_outline,
                                            size: 18, color: Colors.green),
                                        SizedBox(width: 6),
                                        Text(
                                          'Add',
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Assign button for selected workers
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
                  child: Text('Assign ${assignedWorkers.length + selectedWorkers.length > 0 ? selectedWorkers.length : ''} Worker(s)'.trim()),
                ),
              ),

            // Assigned workers
            if (assignedWorkers.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Assigned Workers:',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: assignedWorkers.map((worker) {
                  final color = _colorForName(worker);
                  return Chip(
                    key: ValueKey('assigned_$worker'),
                    avatar: CircleAvatar(
                      backgroundColor: color,
                      child: Text(
                        _initialForName(worker),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    label: Text(worker),
                    backgroundColor: Colors.green[50],
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 20),

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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: assignedWorkers.isNotEmpty
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SummaryPage(
                                  dockets: widget.dockets,
                                  assignedWorkers: assignedWorkers,
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Assign',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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