import 'package:flutter/material.dart';
import '../../service/dockey_service.dart';
import '../../models/dockets.dart';

class AssignedDocketsPage extends StatefulWidget {
  const AssignedDocketsPage({super.key});

  @override
  State<AssignedDocketsPage> createState() => _AssignedDocketsPageState();
}

class _AssignedDocketsPageState extends State<AssignedDocketsPage> {
  late Future<List<Docket>> _assignedDocketsFuture;
  final DocketService _docketService = DocketService();

  @override
  void initState() {
    super.initState();
    _assignedDocketsFuture = _fetchAssignedDockets();
  }

  // Fetch assigned dockets (filter from all dockets)
  Future<List<Docket>> _fetchAssignedDockets() async {
    try {
      final allDockets = await _docketService.fetchDockets();
      
      // Filter only assigned dockets (dockets with assignedTo field)
      final assignedDockets = allDockets.where((docket) {
        return docket.assignedTo.isNotEmpty &&
               docket.assignTime.isNotEmpty;
      }).toList();
      
      return assignedDockets;
    } catch (e) {
      print('Error fetching assigned dockets: $e');
      rethrow;
    }
  }

  void _refreshData() {
    setState(() {
      _assignedDocketsFuture = _fetchAssignedDockets();
    });
  }

  // Helper method to format date/time for display
  String formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return "N/A";
    }
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateTimeString; // Return original string if parsing fails
    }
  }

  // Get status based on completed time
  String _getStatus(Docket docket) {
    return docket.completedTime.isNotEmpty ? "Completed" : "Ongoing";
  }

  Color _getStatusColor(Docket docket) {
    return docket.completedTime.isNotEmpty ? Colors.green : Colors.orange;
  }

  // Get docket type color
  Color _getDocketTypeColor(String docketType) {
    switch (docketType.toLowerCase()) {
      case 'urgent':
      case 'priority':
      case 'high':
        return Colors.red;
      case 'normal':
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getWorkDuration(Docket docket) {
    if (docket.completedTime.isNotEmpty) {
      final completedTime = DateTime.parse(docket.completedTime);
      final assignTime = DateTime.parse(docket.assignTime);
      final duration = completedTime.difference(assignTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return "$hours hours $minutes minutes";
    } else {
      return "In Progress";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assigned Dockets"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: FutureBuilder<List<Docket>>(
        future: _assignedDocketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Loading assigned dockets..."),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Error loading data",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          final assignedDockets = snapshot.data ?? [];

          if (assignedDockets.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "No assigned dockets available",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Total Assigned",
                        count: assignedDockets.length,
                        color: Colors.blue,
                        icon: Icons.assignment,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Ongoing",
                        count: assignedDockets.where((d) => d.completedTime.isEmpty).length,
                        color: Colors.orange,
                        icon: Icons.hourglass_empty,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Completed",
                        count: assignedDockets.where((d) => d.completedTime.isNotEmpty).length,
                        color: Colors.green,
                        icon: Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Reassigned",
                        count: 0, // Reassignment count is not available in the Docket model
                        color: Colors.purple,
                        icon: Icons.repeat,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DataTable(
                        columnSpacing: 20,
                        headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                        columns: const [
                          DataColumn(label: Text("Docket ID", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Type", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Assigned To", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Assigned Time", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Reassigned", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Duration", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: assignedDockets.map((docket) {
                          return DataRow(
                            color: MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                return null; // No reassignment color available
                              },
                            ),
                            cells: [
                              // DataCell(Text(docket.docketID.isNotEmpty ? docket.docketID : "N/A", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getDocketTypeColor(docket.docketType).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  docket.docketType.isNotEmpty ? docket.docketType : "N/A",
                                  style: TextStyle(
                                    color: _getDocketTypeColor(docket.docketType),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              )),
                              DataCell(Text(docket.assignedTo.isNotEmpty ? docket.assignedTo : "N/A", style: const TextStyle(fontSize: 14))),
                              DataCell(Text(formatDateTime(docket.assignTime), style: const TextStyle(fontSize: 12))),
                              // <-- Updated reassigned column
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "No",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              )),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(docket).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _getStatusColor(docket).withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      docket.completedTime.isNotEmpty ? Icons.check_circle : Icons.schedule, 
                                      size: 12, 
                                      color: _getStatusColor(docket)
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getStatus(docket), 
                                      style: TextStyle(
                                        color: _getStatusColor(docket), 
                                        fontWeight: FontWeight.w500, 
                                        fontSize: 12
                                      )
                                    ),
                                  ],
                                ),
                              )),
                              DataCell(Text(
                                _getWorkDuration(docket), 
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: docket.completedTime.isNotEmpty ? Colors.green.shade700 : Colors.orange.shade700, 
                                  fontWeight: FontWeight.w500
                                )
                              )),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.visibility, size: 18), onPressed: () => _viewDocketDetails(docket), tooltip: "View Details"),
                                  if (docket.completedTime.isEmpty) ...[
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, size: 18), 
                                      onPressed: () => _markAsCompleted(docket), 
                                      tooltip: "Mark as Completed", 
                                      color: Colors.green
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.repeat, size: 18), 
                                      onPressed: () => _reassignDocket(docket), 
                                      tooltip: "Reassign", 
                                      color: Colors.purple
                                    ),
                                  ],
                                ],
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: color.shade50!,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: color.shade200!),
  ),
  child: Column(
    children: [
      Icon(icon, color: color.shade600!, size: 24),
      const SizedBox(height: 8),
      Text("$count", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color.shade700!)),
      Text(title, style: TextStyle(fontSize: 12, color: color.shade700!, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
    ],
  ),
);
  }

  void _viewDocketDetails(Docket docket) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Expanded(child: Text("Docket Details - ${docket.id}")),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow("Docket ID", docket.id),
                _buildDetailRow("Type", docket.docketType),
                _buildDetailRow("Assigned To", docket.assignedTo),
                _buildDetailRow("Assigned Time", formatDateTime(docket.assignTime)),
                _buildDetailRow("Status", _getStatus(docket)),
                if (docket.completedTime.isNotEmpty) ...[
                  _buildDetailRow("Completed Time", formatDateTime(docket.completedTime)),
                  _buildDetailRow("Work Duration", _getWorkDuration(docket)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), 
              child: const Text("Close")
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value?.isNotEmpty == true ? value! : "N/A", style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _markAsCompleted(Docket docket) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Mark as Completed"),
          content: Text("Are you sure you want to mark docket ${docket.id} as completed?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), 
              child: const Text("Cancel")
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performMarkAsCompleted(docket);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Mark Completed"),
            ),
          ],
        );
      },
    );
  }

  void _performMarkAsCompleted(Docket docket) {
    // In a real app, you would call an API to update the docket status
    // For now, we'll just show a snackbar and refresh the data
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text("Docket ${docket.id} marked as completed"),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
    _refreshData();
  }

  void _reassignDocket(Docket docket) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Reassign Docket"),
          content: Text("Are you sure you want to reassign docket ${docket.id}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), 
              child: const Text("Cancel")
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performReassignment(docket);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text("Reassign"),
            ),
          ],
        );
      },
    );
  }

  void _performReassignment(Docket docket) {
    // In a real app, you would call an API to reassign the docket
    // For now, we'll just show a snackbar and refresh the data
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.repeat, color: Colors.white),
            const SizedBox(width: 8),
            Text("Docket ${docket.id} has been reassigned"),
          ],
        ),
        backgroundColor: Colors.purple,
      ),
    );
    _refreshData();
  }
}

extension on Color {
  Color? get shade700 => null;
  
  Color? get shade600 => null;
  
  // Color get shade200 => null;
  
  Color? get shade50 => null;
  
  Color? get shade200 => null;
}
