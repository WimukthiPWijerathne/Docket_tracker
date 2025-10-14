import 'package:flutter/material.dart';
import '../service/assigned_docket_service.dart';
import '../models/assigned_docket.dart';
import '../models/WorkLog.dart';
// AssignedDocketsPage removed; navigation now goes to TechnicianPortalPage
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../pages/technicianPortal/technicianPortalPage.dart';

class TechnicianNotificationBanner extends StatefulWidget {
  final String? userUUID;
  // New optional properties: employee number and access level
  final String? employeeNo;
  final String? accessLevel;

  const TechnicianNotificationBanner({
    super.key,
    this.userUUID,
    this.employeeNo,
    this.accessLevel,
  });

  @override
  State<TechnicianNotificationBanner> createState() => _TechnicianNotificationBannerState();
}

class _TechnicianNotificationBannerState extends State<TechnicianNotificationBanner> {
  final AssignedDocketService _assignedDocketService = AssignedDocketService();
  bool _isLoading = true;
  String? _error;
  
  int _totalAssigned = 0;
  int _completedAssigned = 0;
  int _inProgressAssigned = 0;
  List<AssignedDocket> _pendingDockets = [];

  @override
  void initState() {
    super.initState();
    _loadAssignmentStats();
  }

  Future<void> _loadAssignmentStats() async {
    // Gate: if accessLevel is provided and not '*' -> don't show banner
    if (widget.accessLevel != null && widget.accessLevel != '*') {
      setState(() {
        _isLoading = false;
        _error = null;
        _totalAssigned = 0;
        _completedAssigned = 0;
        _inProgressAssigned = 0;
        _pendingDockets = [];
      });
      return;
    }

    if (widget.userUUID == null) {
      setState(() {
        _isLoading = false;
        _error = 'User UUID not available';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch assigned dockets and work logs in parallel
      final results = await Future.wait([
        _assignedDocketService.fetchAssignedDockets(),
        _fetchWorkLogs(),
      ]);

      final assignedDockets = results[0] as List<AssignedDocket>;
      final workLogs = results[1] as List<WorkLog>;

      // Create work log lookup map
      final workLogsMap = <String, WorkLog>{};
      for (final workLog in workLogs) {
        workLogsMap[workLog.docketId] = workLog;
      }

      // Filter dockets assigned to this user
      // If an employeeNo is provided, filter by that employee number (using assignedPersonsList helper)
      final userAssignedDockets = assignedDockets.where((docket) {
        final assignedList = docket.assignedPersonsList;
        final target = widget.employeeNo ?? widget.userUUID ?? '';
        return target.isNotEmpty && assignedList.contains(target);
      }).toList();

      // Reset counters first
      _totalAssigned = 0;
      _completedAssigned = 0;
      _inProgressAssigned = 0;

      // Count statistics
      _totalAssigned = userAssignedDockets.length;

      for (final docket in userAssignedDockets) {
        final workLog = workLogsMap[docket.docketID];
        final isCompleted = workLog != null &&
            workLog.completedAt != null &&
            workLog.completedAt!.isNotEmpty &&
            workLog.completedAt != '0' &&
            workLog.completedAt!.toLowerCase() != 'null';

        if (isCompleted) {
          _completedAssigned++;
        } else {
          _inProgressAssigned++;
        }
      }

      // Build list of pending (not completed) assigned dockets for quick access
      _pendingDockets = userAssignedDockets.where((d) => !d.isCompleted).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load assignment statistics: $e';
      });
    }
  }

  // Method to fetch work logs
  Future<List<WorkLog>> _fetchWorkLogs() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://powerprox.sltidc.lk/GETDocketWorkLog.php'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        if (responseBody.isEmpty) return [];

        final dynamic jsonData = json.decode(responseBody);
        if (jsonData is List) {
          return jsonData
              .map<WorkLog>((item) => WorkLog.fromJson(item))
              .toList();
        } else if (jsonData is Map<String, dynamic>) {
          return [WorkLog.fromJson(jsonData)];
        }
        return [];
      }
      return [];
    } catch (e) {
      print('Error fetching work logs: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Debug: announce tap and navigate to Technician Portal
        debugPrint('DEBUG: TechnicianNotificationBanner tapped');
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening Technician Portal...')),
          );
        } catch (e) {
          // ignore if no scaffold available
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TechnicianPortalPage(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF003366),
              Color(0xFF004080),
            ],
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Technician!',
                        style: TextStyle(
                          color: Colors.white,
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
                                : (_totalAssigned > 0
                                    ? 'You have $_totalAssigned assigned dockets' + (widget.employeeNo != null && widget.employeeNo!.isNotEmpty ? ' for ${widget.employeeNo}' : '')
                                    : 'No assigned dockets at the moment'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Small badge for incomplete dockets
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _inProgressAssigned > 0
                        ? Colors.orangeAccent
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _inProgressAssigned > 0
                        ? '$_inProgressAssigned PENDING'
                        : 'NO PENDING',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // Assignment Statistics (if loaded successfully)
            if (!_isLoading && _error == null && _totalAssigned > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('Total', _totalAssigned, Icons.assignment),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _buildStatItem('Completed', _completedAssigned, Icons.check_circle),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _buildStatItem('In Progress', _inProgressAssigned, Icons.hourglass_empty),
                    ),
                  ],
                ),
              ),
            ],

            // Help Text
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white.withOpacity(0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use "Assigned Dockets" to view your tasks and "Technician Portal" for advanced features',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Pending assigned docket chips (show up to 6)
            if (_pendingDockets.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pendingDockets.take(6).map((docket) {
                  return GestureDetector(
                    onTap: () {
                      debugPrint('DEBUG: Pending docket chip tapped: ${docket.docketID}');
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Opening Technician Portal for ${docket.docketID}...')),
                        );
                      } catch (e) {}

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TechnicianPortalPage(),
                        ),
                      );
                    },
                    child: Chip(
                      backgroundColor: Colors.white.withOpacity(0.12),
                      label: Text(
                        docket.docketID,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
