import 'package:flutter/material.dart';
import '../service/assigned_docket_service.dart';
import '../models/assigned_docket.dart';
import '../models/WorkLog.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TechnicianNotificationBanner extends StatefulWidget {
  final String? userUUID;

  const TechnicianNotificationBanner({super.key, this.userUUID});

  @override
  State<TechnicianNotificationBanner> createState() =>
      _TechnicianNotificationBannerState();
}

class _TechnicianNotificationBannerState
    extends State<TechnicianNotificationBanner> {
  final AssignedDocketService _assignedDocketService = AssignedDocketService();
  bool _isLoading = true;
  String? _error;

  int _totalAssigned = 0;
  int _completedAssigned = 0;
  int _inProgressAssigned = 0;

  @override
  void initState() {
    super.initState();
    _loadAssignmentStats();
  }

  Future<void> _loadAssignmentStats() async {
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
      final userAssignedDockets = assignedDockets.where((docket) {
        final assignedPersons = docket.assignedPersons
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return assignedPersons.contains(widget.userUUID);
      }).toList();

      // Count statistics
      _totalAssigned = userAssignedDockets.length;

      for (final docket in userAssignedDockets) {
        final workLog = workLogsMap[docket.docketID];
        final isCompleted =
            workLog != null &&
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF003366), Color(0xFF004080)],
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
                          : 'You have $_totalAssigned assigned dockets',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
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
                    child: _buildStatItem(
                      'Total',
                      _totalAssigned,
                      Icons.assignment,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Completed',
                      _completedAssigned,
                      Icons.check_circle,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'In Progress',
                      _inProgressAssigned,
                      Icons.hourglass_empty,
                    ),
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
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
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
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
        ),
      ],
    );
  }
}
