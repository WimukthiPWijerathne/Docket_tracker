import 'package:flutter/material.dart';
import '../services/worker_service.dart';
import '../models/worker_model.dart';
import '../service/docket_assignment_service.dart'; // ✅ added

class AssignPage extends StatefulWidget {
  final String depot; // default depot filter from previous page
  final List<dynamic> dockets; // dockets passed from previous page

  const AssignPage({super.key, required this.depot, required this.dockets});

  @override
  State<AssignPage> createState() => _AssignPageState();
}

class _AssignPageState extends State<AssignPage> {
  final WorkerService _workerService = WorkerService();
  final DocketAssignmentService _assignmentService = DocketAssignmentService();

  // Workers
  List<Worker> workers = [];
  List<Worker> filteredWorkers = [];
  List<bool> status = [];
  bool isLoading = true;
  String? errorMessage;

  // Depot filter
  final List<String> depots = ['All', 'Kadana', 'Mahara', 'Paliyagoda', 'Wattala'];
  String selectedDepot = 'All';

  @override
  void initState() {
    super.initState();
    selectedDepot = widget.depot; // start with depot from previous page
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final fetchedWorkers = await _workerService.fetchWorkersByDepot(selectedDepot);
      if (mounted) {
        setState(() {
          workers = fetchedWorkers;
          filteredWorkers = fetchedWorkers;
          status = List<bool>.filled(filteredWorkers.length, false);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
          workers = [];
          filteredWorkers = [];
          status = [];
        });
      }
    }
  }

  Future<void> _onAssign() async {
    if (!mounted) return;

    final selectedIndices = <int>[];
    for (int i = 0; i < status.length; i++) {
      if (status[i]) selectedIndices.add(i);
    }

    if (selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one worker'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedWorkers = selectedIndices.map((i) => filteredWorkers[i]).toList();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final currentTime = DateTime.now().toIso8601String();
      int successCount = 0;
      int failCount = 0;
      List<String> errorMessages = [];

      // Loop through dockets
      for (final docket in widget.dockets) {
        final String docketId = docket.id ?? docket['id'];
        final String docketSerial =
            docket.docketSerial ?? docket['docketSerial'] ?? docketId;

        for (final worker in selectedWorkers) {
          try {
            debugPrint("🔄 Assigning ${worker.name} to docket $docketSerial ($docketId)");

            final success = await _assignmentService.assignWorkerToDocket(
              docketId: docketId,
              assignedPerson: worker.name,
              assignedTime: currentTime,
              reassigned: false, // adjust if needed
              uploadedBy: 'CSE001',
              uploadedTime: currentTime,
            );

            if (success) {
              successCount++;
              debugPrint("✅ Assigned ${worker.name} to $docketSerial");
            } else {
              failCount++;
              errorMessages.add("❌ Failed: ${worker.name} → $docketSerial");
            }
          } catch (e) {
            failCount++;
            errorMessages.add("❌ Error assigning ${worker.name} → $docketSerial: $e");
          }

          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      Navigator.of(context).pop(); // close loading

      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ $successCount assigned, ❌ $failCount failed"),
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
          ),
        );
      }

      if (errorMessages.isNotEmpty) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Assignment Errors"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: errorMessages.map((m) => Text(m)).toList(),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("OK")),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Assignment failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onCancel() {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < status.length; i++) {
        status[i] = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All selections cancelled'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF003366).withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Employee No', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366)))),
          Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366)))),
          Expanded(flex: 2, child: Text('Depot', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366)))),
          Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366)))),
          Expanded(flex: 1, child: Center(child: Text('Select', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366))))),
        ],
      ),
    );
  }

  Widget _buildWorkerRow(Worker worker, bool isSelected, int index) {
    return InkWell(
      onTap: () {
        if (mounted) {
          setState(() {
            status[index] = !status[index];
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF003366).withOpacity(0.05) : Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(worker.employeeNo, style: const TextStyle(fontSize: 12))),
            Expanded(flex: 3, child: Text(worker.name, style: const TextStyle(fontSize: 12))),
            Expanded(flex: 2, child: Text(worker.depot, style: const TextStyle(fontSize: 12))),
            Expanded(
              flex: 2,
              child: Text(
                worker.status,
                style: TextStyle(
                  fontSize: 12,
                  color: worker.isAvailable ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(color: isSelected ? const Color(0xFF003366) : Colors.grey),
                    borderRadius: BorderRadius.circular(3),
                    color: isSelected ? const Color(0xFF003366) : Colors.transparent,
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
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

    double contentHeight = headerHeight + (filteredWorkers.length * rowHeight);
    double tableHeight = contentHeight > maxHeight ? maxHeight : contentHeight;

    return Scaffold(
      appBar: AppBar(
        title: Text("Workers (${selectedDepot})"),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadWorkers),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Workers", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 8),
            Text('Total: ${filteredWorkers.length} workers', style: const TextStyle(fontSize: 16, color: Color(0xFF666666))),
            const SizedBox(height: 16),

            // ✅ Depot Filter Dropdown
            Row(
              children: [
                const Text("Filter by Depot: ",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: selectedDepot,
                  items: depots.map((depot) {
                    return DropdownMenuItem<String>(
                      value: depot,
                      child: Text(depot),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedDepot = value;
                      });
                      _loadWorkers();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text('API Error: $errorMessage', style: const TextStyle(color: Colors.orange))),
                  ],
                ),
              ),
            Container(
              height: tableHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildHeaderRow(),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredWorkers.isEmpty
                            ? Center(child: Text('No workers available for "$selectedDepot"'))
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: filteredWorkers.length,
                                itemBuilder: (context, index) {
                                  final worker = filteredWorkers[index];
                                  return _buildWorkerRow(
                                    worker,
                                    status.length > index ? status[index] : false,
                                    index,
                                  );
                                },
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
                    onPressed: isLoading ? null : _onAssign,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Assign', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _onCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
