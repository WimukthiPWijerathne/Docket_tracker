import 'package:flutter/material.dart';
import 'summary.dart';
import 'docket_selection_page.dart';
import '../service/docket_assignment_service.dart';
import '../models/dockets.dart';

class AssignPage extends StatefulWidget {
  final List<Docket> dockets; // Changed from List<String> to List<Docket>

  const AssignPage({Key? key, required this.dockets}) : super(key: key);

  @override
  State<AssignPage> createState() => _AssignPageState();
}

class _AssignPageState extends State<AssignPage> {
  final DocketAssignmentService _assignmentService = DocketAssignmentService();
  final List<String> allWorkers = [
    'කමල්', 'අමල්', 'සුනිල්', 'චමින්ද',
    'රුවන්', 'නිමල්', 'සමන්', 'ජයන්ත',
  ];

  List<String> availableWorkers = [];
  List<String> selectedWorkers = [];
  List<String> assignedWorkers = [];
  Map<String, List<String>> docketAssignments = {}; // Track which workers are assigned to which dockets

  @override
  void initState() {
    super.initState();
    availableWorkers = List.from(allWorkers);
    _initializeDocketAssignments();
  }

  void _initializeDocketAssignments() {
    // Initialize assignment tracking for each docket
    for (final docket in widget.dockets) {
      docketAssignments[docket.id] = [];
    }
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
      // Use the docket serial if available, otherwise use ID
      return widget.dockets.first.docketSerial.isNotEmpty 
          ? widget.dockets.first.docketSerial 
          : widget.dockets.first.id;
    }
    // For multiple dockets, show count in parentheses
    return '(${widget.dockets.length})';
  }

  Future<void> _assignWorkersToSelected() async {
    if (selectedWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one worker'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

      // Process each selected docket
      for (final docket in widget.dockets) {
        // Check if this docket already has assignments (for reassigned flag)
        final bool isReassigned = docketAssignments[docket.id]!.isNotEmpty;
        
        // Assign each selected worker to this docket
        for (final worker in selectedWorkers) {
          try {
            print('🔄 Assigning worker $worker to docket ${docket.docketSerial} (${docket.id})');
            
            final success = await _assignmentService.assignWorkerToDocket(
              docketId: docket.id,
              assignedPerson: worker,
              assignedTime: currentTime,
              reassigned: isReassigned,
              uploadedBy: docket.uploadedBy.isNotEmpty ? docket.uploadedBy : 'CSE001',
              uploadedTime: docket.uploadedTime.isNotEmpty ? docket.uploadedTime : currentTime,
            );

            if (success) {
              successCount++;
              // Track the assignment
              if (!docketAssignments[docket.id]!.contains(worker)) {
                docketAssignments[docket.id]!.add(worker);
              }
              print('✅ Successfully assigned $worker to ${docket.docketSerial}');
            } else {
              failCount++;
              final errorMsg = 'Failed to assign $worker to ${docket.docketSerial} (${docket.id})';
              errorMessages.add(errorMsg);
              print('❌ $errorMsg');
            }
          } catch (e, stackTrace) {
            failCount++;
            final errorMsg = 'Error assigning $worker to ${docket.docketSerial}: $e';
            errorMessages.add(errorMsg);
            print('❌ $errorMsg');
            print('Stack trace: $stackTrace');
          }
          
          // Small delay between assignments to avoid overwhelming the server
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      Navigator.of(context).pop(); // Close loading dialog

      if (successCount > 0) {
        setState(() {
          // Move selected workers to assigned workers
          for (final worker in selectedWorkers) {
            if (!assignedWorkers.contains(worker)) {
              assignedWorkers.add(worker);
            }
          }
          // Remove assigned workers from available pool
          availableWorkers.removeWhere((w) => assignedWorkers.contains(w));
          // Clear selected workers
          selectedWorkers.clear();
        });

        String message = 'Successfully assigned $successCount worker-docket combinations';
        if (failCount > 0) {
          message += ', $failCount failed';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );

        // Show error details if any
        if (errorMessages.isNotEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Assignment Errors'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: errorMessages.map((msg) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $msg'),
                    ),
                  ).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All assignments failed. ${errorMessages.join(', ')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process assignments: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _titleSuffix.isEmpty
        ? 'Assign Workers'
        : 'Assign Workers $_titleSuffix';

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
              ...widget.dockets.map((docket) => 
                Text("• ${docket.docketSerial.isNotEmpty ? docket.docketSerial : docket.id} (${docket.docketType})")
              ).toList(),
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
                        if (!availableWorkers.contains(worker) && !assignedWorkers.contains(worker)) {
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
                  onPressed: _assignWorkersToSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Assign ${selectedWorkers.length} Worker(s) to ${widget.dockets.length} Docket(s)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Assigned workers (now with delete functionality)
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
                  return InputChip(
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
                    onDeleted: () {
                      setState(() {
                        // Remove from assigned workers
                        assignedWorkers.remove(worker);
                        // Remove from all docket assignments
                        for (final docketId in docketAssignments.keys) {
                          docketAssignments[docketId]!.remove(worker);
                        }
                        // Add back to available workers if not already there
                        if (!availableWorkers.contains(worker)) {
                          availableWorkers.add(worker);
                          availableWorkers.sort();
                        }
                      });
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$worker removed from all assignments'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
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
                                  dockets: widget.dockets.map((d) => d.id).toList(),
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
                      'Continue to Summary',
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