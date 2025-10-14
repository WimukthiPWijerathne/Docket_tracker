import 'package:flutter/material.dart';
import '../service/assigned_docket_serviceX.dart';
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
    // Gate: if accessLevel is provided and not '*' -> don't show banner
    if (widget.accessLevel != null && widget.accessLevel != '*') {
      setState(() {
        _isLoading = false;
        _error = null;
        _totalAssigned = 0;
        _completedAssigned = 0;
        _inProgressAssigned = 0;
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
      // Hardcoded employee number to "1238" to match assignedPersons from API
      String target = widget.employeeNo ?? '1238';

      bool _matchesTarget(List<String> assignedList, String target) {
        if (target.isEmpty) return false;
        final t = target.trim();

        // exact match (case-insensitive)
        for (final a in assignedList) {
          if (a.toLowerCase() == t.toLowerCase()) return true;
        }

        // normalized alphanumeric comparison (remove non-alphanum)
        final normalize = (String s) =>
            s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
        final nt = normalize(t);
        for (final a in assignedList) {
          if (normalize(a) == nt) return true;
        }

        // numeric-only comparison: compare digit sequences (helps when assignedPersons is numeric but employeeNo has prefix like 'W-181')
        final digits = (String s) {
          final m = RegExp(r"(\d+)").firstMatch(s);
          return m == null ? null : m.group(0);
        };
        final tDigits = digits(t);
        if (tDigits != null) {
          for (final a in assignedList) {
            final aDigits = digits(a);
            if (aDigits != null && aDigits == tDigits) return true;
          }
        }

        return false;
      }

      final userAssignedDockets = assignedDockets.where((docket) {
        final assignedList = docket.assignedPersonsList;
        return _matchesTarget(assignedList, target);
      }).toList();

      // Reset counters first
      _totalAssigned = 0;
      _completedAssigned = 0;
      _inProgressAssigned = 0;

      // Count statistics
      _totalAssigned = userAssignedDockets.length;

      // Check WorkLog completedAt field to determine completion status
      // Similar logic to TechnicianPortalPage._isCompleted()
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
          _inProgressAssigned++; // Remaining dockets (not yet completed)
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

        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const TechnicianPortalPage()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _inProgressAssigned > 0
                ? [
                    const Color(
                      0xFF1976D2,
                    ), // Brighter blue for pending assignments
                    const Color(0xFF2196F3),
                  ]
                : [
                    const Color(0xFF00796B), // Teal for no pending assignments
                    const Color(0xFF26A69A),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _inProgressAssigned > 0
                        ? Icons.assignment_late
                        : Icons.assignment_turned_in,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Assignments',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                                  ? 'You have $_totalAssigned assigned docket${_totalAssigned > 1 ? 's' : ''}'
                                  : 'No assigned dockets at the moment'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Small badge for incomplete dockets
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _inProgressAssigned > 0
                        ? const Color(0xFFFF6B6B) // Bright red for pending
                        : Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _inProgressAssigned > 0
                        ? '$_inProgressAssigned PENDING'
                        : 'ALL DONE',
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
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
                        'Remaining',
                        _inProgressAssigned,
                        Icons.pending_actions,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Help Text
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    color: Colors.white.withOpacity(0.95),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tap to view and manage your assigned dockets',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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

  Widget _buildStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
