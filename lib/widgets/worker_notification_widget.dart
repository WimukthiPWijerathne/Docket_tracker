import 'package:flutter/material.dart';
import '../service/assigned_docket_service.dart';
import '../models/assigned_docket.dart';
import '../models/dockets.dart';
import '../service/dockey_service.dart' as dockey;
import 'package:intl/intl.dart';
import '../pages/technicianPortal/technicianPortalPage.dart';

class WorkerNotificationWidget extends StatefulWidget {
  final String? userUUID;

  const WorkerNotificationWidget({super.key, this.userUUID});

  @override
  State<WorkerNotificationWidget> createState() =>
      _WorkerNotificationWidgetState();
}

class _WorkerNotificationWidgetState extends State<WorkerNotificationWidget> {
  final AssignedDocketService _assignedDocketService = AssignedDocketService();
  final dockey.DocketService _docketService = dockey.DocketService();

  bool _isLoading = true;
  String? _error;

  List<AssignedDocket> _todayAssignedDockets = [];
  Map<String, Docket> _docketsMap = {};

  @override
  void initState() {
    super.initState();
    _loadTodayAssignments();
  }

  Future<void> _loadTodayAssignments() async {
    final targetEmployee = widget.userUUID ?? 'W-181';

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait([
        _assignedDocketService.fetchAssignedDockets(),
        _docketService.fetchDockets(),
      ]);

      final assignedDockets = results[0] as List<AssignedDocket>;
      final dockets = results[1] as List<Docket>;

      _docketsMap.clear();
      for (final docket in dockets) {
        _docketsMap[docket.id] = docket;
      }

      final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());

      _todayAssignedDockets = assignedDockets.where((assignment) {
        final assignedList = assignment.assignedPersons
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        if (!assignedList.contains(targetEmployee)) return false;

        try {
          DateTime assignedDate;
          if (assignment.assignedTime.contains('/')) {
            final parts = assignment.assignedTime.split(' ');
            final d = parts[0].split('/');
            assignedDate = DateTime(
              int.parse(d[2]),
              int.parse(d[1]),
              int.parse(d[0]),
            );
          } else if (assignment.assignedTime.contains('-')) {
            final parts = assignment.assignedTime.split(' ');
            assignedDate = DateTime.parse(parts[0]);
          } else {
            assignedDate = DateTime.parse(assignment.assignedTime);
          }
          return DateFormat('yyyy-MM-dd').format(assignedDate) == todayString;
        } catch (e) {
          return false;
        }
      }).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load today\'s assignments: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAssignedDockets = _todayAssignedDockets.isNotEmpty;
    final gradientColors = hasAssignedDockets
        ? [const Color(0xFFD32F2F), const Color(0xFFE57373)]
        : [const Color(0xFFFFD700), const Color(0xFFFFC107)];
    return GestureDetector(
      onTap: () {
        debugPrint(
          'DEBUG: WorkerNotificationWidget tapped - opening Technician Portal',
        );
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening Technician Portal...')),
          );
        } catch (e) {}
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const TechnicianPortalPage()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasAssignedDockets
                        ? Icons.notification_important
                        : Icons.work_outline,
                    color: hasAssignedDockets
                        ? const Color(0xFF003366)
                        : Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Assignments',
                        style: TextStyle(
                          color: hasAssignedDockets
                              ? const Color(0xFF003366)
                              : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoading
                            ? 'Loading your assignments...'
                            : _error != null
                            ? 'Unable to load assignment data'
                            : 'You have ${_todayAssignedDockets.length} dockets assigned today',
                        style: TextStyle(
                          color: hasAssignedDockets
                              ? const Color(0xFF003366).withOpacity(0.8)
                              : Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMM dd').format(DateTime.now()),
                    style: TextStyle(
                      color: hasAssignedDockets
                          ? const Color(0xFF003366)
                          : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // Assigned list or empty state
            if (!_isLoading && _error == null) ...[
              const SizedBox(height: 12),
              if (_todayAssignedDockets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: const Color(0xFF003366).withOpacity(0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No dockets assigned for today',
                          style: TextStyle(
                            color: const Color(0xFF003366).withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _todayAssignedDockets.length,
                    itemBuilder: (context, index) {
                      final assignment = _todayAssignedDockets[index];
                      final docket = _docketsMap[assignment.docketID];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF003366).withOpacity(0.7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    docket?.docketType ?? 'Unknown Type',
                                    style: const TextStyle(
                                      color: Color(0xFF003366),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Docket ID: ${assignment.docketID}',
                                    style: TextStyle(
                                      color: const Color(
                                        0xFF003366,
                                      ).withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (docket?.depot != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Location: ${docket!.depot}',
                                      style: TextStyle(
                                        color: const Color(
                                          0xFF003366,
                                        ).withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Color(0xFF003366),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasAssignedDockets
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFF003366).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: hasAssignedDockets
                        ? const Color(0xFF003366).withOpacity(0.8)
                        : const Color(0xFF003366).withOpacity(0.7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use "Assigned Dockets" to view all your tasks and update progress',
                      style: TextStyle(
                        color: hasAssignedDockets
                            ? const Color(0xFF003366).withOpacity(0.8)
                            : const Color(0xFF003366).withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
