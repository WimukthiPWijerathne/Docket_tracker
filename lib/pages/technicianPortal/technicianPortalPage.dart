import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:leco_docket_tracker/pages/technicianPortal/technicianAssignmentDetailPage.dart';

// --- Models
import '../../models/dockets.dart';
import '../../models/assigned_docket.dart';
import '../../models/docketAssignment.dart' as models;
import '../../models/WorkLog.dart';

// --- Services
import '../../service/dockey_service.dart' as dockey;
import '../../service/assigned_docket_service.dart';
import 'services/workLogService.dart';

class TechnicianPortalPage extends StatefulWidget {
  const TechnicianPortalPage({super.key});

  @override
  State<TechnicianPortalPage> createState() => _TechnicianPortalPageState();
}

class _TechnicianPortalPageState extends State<TechnicianPortalPage>
    with TickerProviderStateMixin {
  final _docketSvc = dockey.DocketService();
  final _assignedDocketSvc = AssignedDocketService();

  bool _loading = true;
  String? _error;

  /// All dockets (used to render cards)
  List<Docket> _allDockets = [];

  /// Map<docketId, AssignedDocket> for all assignments
  final Map<String, AssignedDocket> _myAssignments = {};

  /// Map to store location details for each docket ID
  final Map<String, String> _locationDetails = {};

  /// Map to store WorkLog data for each docket ID
  final Map<String, WorkLog> _workLogs = {};

  late AnimationController _animationController;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Assigned', 'Completed'];

  static const int _criticalDays = 2;
  static const String docketDetailsApiBase =
      'https://powerprox.sltidc.lk/GETDocketDetails2.php';

  // status code sets (strings)
  static const Set<String> _completedCodes = {'2'};
  static const Set<String> _pendingCodes = {'0', '1', '4', '', 'null'};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ---------------- Load ----------------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Docket details (for card data)
      final dockets = await _docketSvc.fetchDockets();
      debugPrint('[TechPortal] fetched ${dockets.length} dockets');

      // 2) Fetch ALL assignments (do NOT rely on server filter)
      final allAssignments = await _assignedDocketSvc.fetchAssignedDockets();
      debugPrint(
        '[TechPortal] fetched ${allAssignments.length} assignments (unfiltered)',
      );

      // 3) Index all assignments by docketId (string) - no user filtering
      _myAssignments.clear();
      int assignmentCount = 0;
      for (final a in allAssignments) {
        final k = _normalizeAssignmentDocketId(a);
        if (k.isEmpty) {
          debugPrint('[TechPortal] WARN: assignment without docketId → $a');
          continue;
        }
        _myAssignments[k] = a;
        assignmentCount++;
      }
      debugPrint('[TechPortal] total assignments indexed → $assignmentCount');

      setState(() {
        _allDockets = dockets;
        _loading = false;
      });

      // 4) Fetch location details for assigned dockets
      await _fetchLocationDetails();

      // 5) Fetch WorkLog data for assigned dockets
      await _fetchWorkLogs();

      _animationController.reset();
      _animationController.forward();

      final totalAssigned = _allDockets.where(_hasAssignment).length;
      final completedAssigned = _allDockets
          .where((d) => _hasAssignment(d) && _isCompleted(d))
          .length;
      final pendingAssigned = _allDockets
          .where((d) => _hasAssignment(d) && _isPending(d))
          .length;

      debugPrint(
        '[TechPortal] all assigned: total=$totalAssigned, pending=$pendingAssigned, completed=$completedAssigned',
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
        _allDockets = [];
        _myAssignments.clear();
        _locationDetails.clear();
        _workLogs.clear();
      });
    }
  }

  // Method to fetch location details for assigned dockets using the same API as AssignedDocketDetailsPage
  Future<void> _fetchLocationDetails() async {
    try {
      debugPrint('🔍 Fetching docket details from: $docketDetailsApiBase');
      final response = await http.get(Uri.parse(docketDetailsApiBase));

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('🔢 Found ${data.length} docket records');

        // Get assigned dockets that we need location details for
        final assignedDockets = _allDockets.where(_hasAssignment).toList();

        for (final docket in assignedDockets) {
          final docketId = docket.id.toString();

          // Find the matching record in the API response
          try {
            final record = data.firstWhere((item) {
              final id = item['ID']?.toString();
              return id == docketId;
            }, orElse: () => null);

            if (record != null) {
              // Parse location details similar to AssignedDocketDetailsPage
              final combinedDetails = record['locationDetails']?.toString();
              if (combinedDetails != null &&
                  combinedDetails.isNotEmpty &&
                  combinedDetails != 'null') {
                _locationDetails[docketId] = combinedDetails;
              } else {
                // Fallback to individual fields if locationDetails is not available
                final transformer = record['Transformer']?.toString() ?? '';
                final pole = record['Pole']?.toString() ?? '';
                final meterShift = record['MeterShift']?.toString() ?? '';

                final details = <String>[];
                if (transformer.isNotEmpty && transformer != 'null')
                  details.add('Transformer: $transformer');
                if (pole.isNotEmpty && pole != 'null')
                  details.add('Pole: $pole');
                if (meterShift.isNotEmpty && meterShift != 'null')
                  details.add('Meter Shift: $meterShift');

                if (details.isNotEmpty) {
                  _locationDetails[docketId] = details.join(' • ');
                }
              }

              debugPrint(
                '📍 Location details for docket $docketId: ${_locationDetails[docketId]}',
              );
            }
          } catch (e) {
            debugPrint('❌ Error processing docket $docketId: $e');
          }
        }

        debugPrint(
          '[TechPortal] Fetched location details for ${_locationDetails.length} dockets',
        );

        // Update the UI if we're still on this screen
        if (mounted) {
          setState(() {});
        }
      } else {
        debugPrint(
          '❌ Failed to fetch docket details. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[TechPortal] Error fetching location details: $e');
    }
  }

  // Method to fetch WorkLog data for assigned dockets to check completion status
  Future<void> _fetchWorkLogs() async {
    try {
      debugPrint('🔍 Fetching WorkLog data for assigned dockets');

      // Get assigned dockets that we need WorkLog data for
      final assignedDockets = _allDockets.where(_hasAssignment).toList();
      _workLogs.clear();

      for (final docket in assignedDockets) {
        try {
          final assignment = _myAssignments[_docketKeyFromDocket(docket)];
          if (assignment == null) continue;

          // Get WorkLog for this docket assignment
          final workLogs = await WorkLogService.getWorkLogs(
            assignmentId: assignment.docketID,
            docketId: docket.id.toString(),
          );

          if (workLogs.isNotEmpty) {
            // Use the first (most recent) WorkLog
            final workLog = workLogs.first;
            _workLogs[docket.id.toString()] = workLog;

            debugPrint(
              '📋 WorkLog for docket ${docket.id}: completedAt=${workLog.completedAt}',
            );
          }
        } catch (e) {
          debugPrint('❌ Error fetching WorkLog for docket ${docket.id}: $e');
        }
      }

      debugPrint(
        '[TechPortal] Fetched WorkLog data for ${_workLogs.length} dockets',
      );

      // Update the UI if we're still on this screen
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[TechPortal] Error fetching WorkLog data: $e');
    }
  }

  // ---------------- Helpers ----------------
  static DateTime _parseLoose(String? s) {
    if (s == null || s.trim().isEmpty || s.toUpperCase() == 'NULL') {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      return DateTime.parse(s.replaceAll('/', '-'));
    } catch (_) {
      try {
        return DateFormat('yyyy-MM-dd HH:mm:ss').parse(s);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
  }

  static String _pretty(DateTime d) => d.millisecondsSinceEpoch == 0
      ? '-'
      : DateFormat('MMM dd, HH:mm').format(d);

  // Robust docketId normalization
  String _docketKeyFromDocket(Docket d) => d.id.toString().trim();

  // Try to read either docketId or docketID from the model (strings everywhere)
  String _normalizeAssignmentDocketId(AssignedDocket a) {
    // Use the docketID field from AssignedDocket
    return a.docketID.trim();
  }

  Map<String, dynamic> _safeToJson(AssignedDocket a) {
    try {
      return a.toJson();
    } catch (_) {
      return const {};
    }
  }

  bool _hasAssignment(Docket d) =>
      _myAssignments.containsKey(_docketKeyFromDocket(d));

  // Decide pending/completed from DocketDetails.assignTime,
  // fall back to AssignedDocket.reassigned if needed.
  bool _isCompleted(Docket d) {
    // First check if we have WorkLog data for this docket
    final workLog = _workLogs[d.id.toString()];
    if (workLog != null) {
      // Use WorkLog's completedAt field for accurate completion status
      return workLog.completedAt != null && workLog.completedAt!.isNotEmpty;
    }

    // Fallback to old status code logic if no WorkLog data available
    final s = d.assignTime.trim();
    if (_completedCodes.contains(s)) return true;
    final a = _myAssignments[_docketKeyFromDocket(d)];
    if (a != null) {
      final Map<String, dynamic> m = _safeToJson(a);
      final r = (m['reassigned'] ?? '').toString().trim();
      if (_completedCodes.contains(r)) return true;
    }
    return false;
  }

  bool _isPending(Docket d) {
    final s = d.assignTime.trim();
    if (_pendingCodes.contains(s)) return true;
    final a = _myAssignments[_docketKeyFromDocket(d)];
    if (a != null) {
      final Map<String, dynamic> m = _safeToJson(a);
      final r = (m['reassigned'] ?? '').toString().trim();
      if (_pendingCodes.contains(r)) return true;
    }
    return false;
  }

  List<Docket> _getFilteredDockets() {
    final assignedDockets = _allDockets.where(_hasAssignment).toList();

    switch (_selectedFilter) {
      case 'Assigned':
        return assignedDockets.where(_isPending).toList()..sort(
          (a, b) => _parseLoose(
            a.uploadedTime,
          ).compareTo(_parseLoose(b.uploadedTime)),
        );
      case 'Completed':
        return assignedDockets.where(_isCompleted).toList()..sort(
          (a, b) => _parseLoose(
            b.completedTime,
          ).compareTo(_parseLoose(a.completedTime)),
        );
      default:
        return assignedDockets..sort((a, b) {
          if (_isPending(a) && _isCompleted(b)) return -1;
          if (_isCompleted(a) && _isPending(b)) return 1;
          return _parseLoose(
            a.uploadedTime,
          ).compareTo(_parseLoose(b.uploadedTime));
        });
    }
  }

  ({int total, int completed, int pending}) _summary() {
    int total = 0, completed = 0, pending = 0;
    for (final d in _allDockets) {
      if (!_hasAssignment(d)) continue;
      total++;
      if (_isCompleted(d)) {
        completed++;
      } else if (_isPending(d)) {
        pending++;
      }
    }
    return (total: total, completed: completed, pending: pending);
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Technician Portal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notification system
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: "Notifications",
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: "Filter",
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF003366),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    "Loading assignments...",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final summary = _summary();
    final filteredDockets = _getFilteredDockets();

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
      },
      color: const Color(0xFF003366),
      child: Column(
        children: [
          // Summary Cards Section
          Container(
            margin: const EdgeInsets.all(16),
            child: _buildSummarySection(summary),
          ),

          // Filter Chips
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final filter = _filterOptions[index];
                final isSelected = _selectedFilter == filter;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    selectedColor: const Color(0xFF003366).withOpacity(0.1),
                    checkmarkColor: const Color(0xFF003366),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFF003366)
                          : Colors.grey[700],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Assignments List
          Expanded(
            child: filteredDockets.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _selectedFilter == 'Completed'
                                  ? Icons.check_circle_outline
                                  : Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _selectedFilter == 'Completed'
                                ? "No completed assignments"
                                : _selectedFilter == 'Assigned'
                                ? "No pending assignments"
                                : "No assignments found",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredDockets.length,
                        itemBuilder: (context, index) {
                          final docket = filteredDockets[index];
                          final animationDelay = index * 0.1;
                          final animation = Tween<double>(begin: 0, end: 1)
                              .animate(
                                CurvedAnimation(
                                  parent: _animationController,
                                  curve: Interval(
                                    animationDelay,
                                    1.0,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                              );

                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(animation),
                              child: _buildDocketCard(docket, index),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    ({int total, int completed, int pending}) summary,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: "Total",
            count: summary.total,
            icon: Icons.assignment,
            color: const Color(0xFF003366),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: "Assigned",
            count: summary.pending,
            icon: Icons.schedule,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: "Completed",
            count: summary.completed,
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            "$count",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDocketCard(Docket docket, int index) {
    final isCompleted = _isCompleted(docket);
    final up = _parseLoose(docket.uploadedTime);
    final days = DateTime.now().difference(up).inDays;
    final isOverdue = days >= _criticalDays && !isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetail(
            docket,
            _myAssignments[_docketKeyFromDocket(docket)]!,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  isCompleted
                      ? Colors.green.withOpacity(0.05)
                      : isOverdue
                      ? Colors.red.withOpacity(0.05)
                      : const Color(0xFF003366).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isCompleted
                    ? Colors.green.withOpacity(0.3)
                    : isOverdue
                    ? Colors.red.withOpacity(0.3)
                    : const Color(0xFF003366).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Docket Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF003366),
                              const Color(0xFF004488),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF003366).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.assignment,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              docket.docketType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.withOpacity(0.2)
                              : isOverdue
                              ? Colors.red.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCompleted
                                ? Colors.green
                                : isOverdue
                                ? Colors.red
                                : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : isOverdue
                                  ? Icons.warning
                                  : Icons.schedule,
                              size: 12,
                              color: isCompleted
                                  ? Colors.green[700]
                                  : isOverdue
                                  ? Colors.red[700]
                                  : Colors.orange[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isCompleted
                                  ? "COMPLETED"
                                  : isOverdue
                                  ? "OVERDUE"
                                  : "PENDING",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCompleted
                                    ? Colors.green[700]
                                    : isOverdue
                                    ? Colors.red[700]
                                    : Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Info rows
                  _buildInfoRow(Icons.business, 'Depot', docket.depot),
                  _buildInfoRow(
                    Icons.numbers,
                    'Docket ID',
                    docket.docketSerial,
                  ),
                  // Show location details if available
                  if (_locationDetails[docket.id.toString()]?.isNotEmpty ??
                      false)
                    _buildInfoRow(
                      Icons.location_on,
                      'Location',
                      _locationDetails[docket.id.toString()]!,
                    ),
                  _buildInfoRow(
                    Icons.person,
                    'Assigned To',
                    docket.assignedTo.isNotEmpty ? docket.assignedTo : 'N/A',
                  ),

                  const SizedBox(height: 12),

                  // Time Information
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Uploaded",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _pretty(up),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCompleted)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Completed",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _pretty(_parseLoose(docket.completedTime)),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Duration",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$days ${days == 1 ? 'day' : 'days'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isOverdue
                                      ? Colors.red[700]
                                      : Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Convert AssignedDocket to DocketAssignment for the detail page
  models.DocketAssignment _convertToDetailAssignment(
    AssignedDocket assignedDocket,
  ) {
    return models.DocketAssignment(
      docketId: assignedDocket.docketID,
      assignedPersons: assignedDocket.assignedPersons,
      assignedTime: assignedDocket.assignedTime,
      reassigned:
          assignedDocket.reassigned == '1' ||
          assignedDocket.reassigned.toLowerCase() == 'true',
      uploadedBy: assignedDocket.uploadedBy,
      uploadedTime: assignedDocket.uploadedTime,
    );
  }

  void _openDetail(Docket d, AssignedDocket a) {
    // Convert AssignedDocket to DocketAssignment for the detail page
    final detailAssignment = _convertToDetailAssignment(a);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignmentDetailPage(
          docket: d,
          assignment: detailAssignment,
          employeeNo: 'TEMP_USER_001',
          onChanged: _load,
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Filter Assignments",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ..._filterOptions.map((filter) {
                return RadioListTile<String>(
                  title: Text(filter),
                  value: filter,
                  groupValue: _selectedFilter,
                  activeColor: const Color(0xFF003366),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedFilter = value;
                      });
                      Navigator.pop(context);
                    }
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ---------------- Shared UI ----------------
Widget _buildInfoRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;
  const _ErrorView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Oops! Something went wrong",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text("Try Again"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
