import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leco_docket_tracker/pages/technicianPortal/technicianAssignmentDetailPage.dart';

// --- Models
import '../../models/dockets.dart';
import '../../models/assigned_docket.dart';
import '../../models/docketAssignment.dart' as models;

// --- Services
import '../../service/dockey_service.dart' as dockey;
import '../../service/assigned_docket_service.dart';

// --- Detail page

class TechnicianPortalPage extends StatefulWidget {
  const TechnicianPortalPage({super.key});

  @override
  State<TechnicianPortalPage> createState() => _TechnicianPortalPageState();
}

class _TechnicianPortalPageState extends State<TechnicianPortalPage> {
  final _docketSvc = dockey.DocketService();
  final _assignedDocketSvc = AssignedDocketService();

  bool _loading = true;
  String? _error;

  /// All dockets (used to render cards)
  List<Docket> _allDockets = [];

  /// Map<docketId, AssignedDocket> for all assignments
  final Map<String, AssignedDocket> _myAssignments = {};

  static const int _criticalDays = 2;

  // status code sets (strings)
  static const Set<String> _completedCodes = {'2'};
  static const Set<String> _pendingCodes = {'0', '1', '4', '', 'null'};

  @override
  void initState() {
    super.initState();
    _load();
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
      });
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
      : DateFormat('yyyy-MM-dd HH:mm').format(d);

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

  List<Docket> _pendingAssignedList() =>
      _allDockets.where((d) => _hasAssignment(d) && _isPending(d)).toList()
        ..sort(
          (a, b) => _parseLoose(
            a.uploadedTime,
          ).compareTo(_parseLoose(b.uploadedTime)),
        );

  List<Docket> _completedAssignedList() =>
      _allDockets.where((d) => _hasAssignment(d) && _isCompleted(d)).toList()
        ..sort(
          (a, b) => _parseLoose(
            b.completedTime,
          ).compareTo(_parseLoose(a.completedTime)),
        );

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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Technician'),
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Assigned'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _load)
            : TabBarView(
                children: [
                  _AssignedTab(
                    summary: _summary(),
                    items: _pendingAssignedList(),
                    onTap: (d) => _openDetail(
                      d,
                      _myAssignments[_docketKeyFromDocket(d)]!,
                    ),
                  ),
                  _CompletedTab(
                    summary: _summary(),
                    items: _completedAssignedList(),
                    onTap: (d) => _openDetail(
                      d,
                      _myAssignments[_docketKeyFromDocket(d)]!,
                    ),
                  ),
                ],
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
          employeeNo:
              'TEMP_USER_001', // Use fallback since no specific employee
          onChanged: _load,
        ),
      ),
    );
  }
}

// ---------------- Assigned Tab with summary ----------------
class _AssignedTab extends StatelessWidget {
  final ({int total, int completed, int pending}) summary;
  final List<Docket> items;
  final void Function(Docket) onTap;

  const _AssignedTab({
    required this.summary,
    required this.items,
    required this.onTap,
  });

  static DateTime _p(String? s) => _TechnicianPortalPageState._parseLoose(s);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _SummaryChips(
            total: summary.total,
            completed: summary.completed,
            pending: summary.pending,
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const _Empty(icon: Icons.inbox, title: 'No assigned jobs')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemBuilder: (_, i) {
                    final d = items[i];
                    final up = _p(d.uploadedTime);
                    final days = DateTime.now().difference(up).inDays;
                    final critical =
                        days >= _TechnicianPortalPageState._criticalDays;
                    final isOverdue = critical;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        gradient: LinearGradient(
                          colors: isOverdue
                              ? [
                                  Colors.red[50]!,
                                  Colors.red[50]!.withOpacity(0.3),
                                ]
                              : [
                                  Colors.blue[50]!,
                                  Colors.blue[50]!.withOpacity(0.3),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: isOverdue
                              ? Colors.red[200]!
                              : Colors.blue[100]!,
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => onTap(d),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row with type and status
                              Row(
                                children: [
                                  Icon(
                                    Icons.assignment,
                                    color: Colors.blue[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      d.docketType,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  _DueBadge(days: days, critical: critical),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Info rows
                              _buildInfoRow(Icons.business, 'Depot', d.depot),
                              _buildInfoRow(
                                Icons.numbers,
                                'Docket ID',
                                d.docketSerial,
                              ),
                              _buildInfoRow(
                                Icons.person,
                                'Assigned To',
                                d.assignedTo.isNotEmpty ? d.assignedTo : 'N/A',
                              ),

                              const SizedBox(height: 8),

                              // Footer with uploaded time
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Uploaded: ${_TechnicianPortalPageState._pretty(up)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (days > 0)
                                    Text(
                                      '$days ${days == 1 ? 'day' : 'days'} pending',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: critical
                                            ? Colors.red
                                            : Colors.orange[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: items.length,
                ),
        ),
      ],
    );
  }
}

// ---------------- Completed Tab with summary ----------------
class _CompletedTab extends StatelessWidget {
  final ({int total, int completed, int pending}) summary;
  final List<Docket> items;
  final void Function(Docket) onTap;

  const _CompletedTab({
    required this.summary,
    required this.items,
    required this.onTap,
  });

  static DateTime _p(String? s) => _TechnicianPortalPageState._parseLoose(s);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _SummaryChips(
            total: summary.total,
            completed: summary.completed,
            pending: summary.pending,
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const _Empty(icon: Icons.inbox, title: 'No completed jobs')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemBuilder: (_, i) {
                    final d = items[i];
                    final cAt = _p(d.completedTime);
                    final up = _p(d.uploadedTime);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        gradient: LinearGradient(
                          colors: [
                            Colors.green[50]!,
                            Colors.green[50]!.withOpacity(0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.green[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => onTap(d),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      d.docketType,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Completed',
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(Icons.business, 'Depot', d.depot),
                              _buildInfoRow(
                                Icons.numbers,
                                'Docket ID',
                                d.docketSerial,
                              ),
                              _buildInfoRow(
                                Icons.person,
                                'Assigned To',
                                d.assignedTo.isNotEmpty ? d.assignedTo : 'N/A',
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Uploaded: ${_TechnicianPortalPageState._pretty(up)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    'Completed: ${_TechnicianPortalPageState._pretty(cAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: items.length,
                ),
        ),
      ],
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

class _SummaryChips extends StatelessWidget {
  final int total, completed, pending;
  const _SummaryChips({
    required this.total,
    required this.completed,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String title, int count, Color color) => Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Total', total, Colors.blueGrey),
          chip('Completed', completed, Colors.green.shade700),
          chip('Pending', pending, const Color(0xFF003366)),
        ],
      ),
    );
  }
}

class _DueBadge extends StatelessWidget {
  final int days;
  final bool critical;
  const _DueBadge({required this.days, required this.critical});

  @override
  Widget build(BuildContext context) {
    final dueText = days <= 0 ? 'Due today' : 'Pending $days d';
    final c = critical ? Colors.red : const Color(0xFF003366);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        border: Border.all(color: c.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        dueText,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  const _Empty({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Icon(icon, size: 64, color: Colors.black26),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;
  const _ErrorView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

//v1
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:leco_docket_tracker/pages/technicianPortal/technicianAssignmentDetailPage.dart';
// import 'package:provider/provider.dart';
//
// // --- Models
// import '../../models/dockets.dart';
// import '../../models/docketAssignment.dart' as models;
//
// // --- Services
// // Hide the conflicting DocketAssignment class that exists inside this service file.
// import '../../service/dockey_service.dart' as dockey hide DocketAssignment;
// import '../../service/assignment_service.dart';
//
// // --- Auth / user
// import '../loginScreen/fetchUserAccess.dart';
//
// class TechnicianPortalPage extends StatefulWidget {
//   const TechnicianPortalPage({super.key});
//
//   @override
//   State<TechnicianPortalPage> createState() => _TechnicianPortalPageState();
// }
//
// class _TechnicianPortalPageState extends State<TechnicianPortalPage> {
//   final _docketSvc = dockey.DocketService();
//
//   bool _loading = true;
//   String? _error;
//
//   /// All dockets (used to render cards)
//   List<Docket> _allDockets = [];
//
//   /// Map<docketId, models.DocketAssignment> for the logged-in tech
//   final Map<String, models.DocketAssignment> _myAssignments = {};
//
//   static const int _criticalDays = 2;
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }
//
//   Future<void> _load() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//
//     final ua = Provider.of<UserAccess>(context, listen: false);
//     final me = (ua.employeeNumber ?? '').trim();
//
//     try {
//       // 1) Docket details (for card data)
//       final dockets = await _docketSvc.fetchDockets();
//
//       // 2) Assignments for this employee (any reassigned state)
//       final mine = await AssignmentService.fetchAssignments(employeeNo: me);
//
//       _myAssignments
//         ..clear()
//         ..addEntries(mine.map((a) => MapEntry(a.docketId, a)));
//
//       setState(() {
//         _allDockets = dockets;
//         _loading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _error = 'Failed to load: $e';
//         _loading = false;
//         _allDockets = [];
//         _myAssignments.clear();
//       });
//     }
//   }
//
//   // ---------- helpers ----------
//   static DateTime _parseLoose(String? s) {
//     if (s == null || s.trim().isEmpty || s.toUpperCase() == 'NULL') {
//       return DateTime.fromMillisecondsSinceEpoch(0);
//     }
//     try {
//       return DateTime.parse(s.replaceAll('/', '-'));
//     } catch (_) {
//       try {
//         return DateFormat('yyyy-MM-dd HH:mm:ss').parse(s);
//       } catch (_) {
//         return DateTime.fromMillisecondsSinceEpoch(0);
//       }
//     }
//   }
//
//   static String _pretty(DateTime d) =>
//       d.millisecondsSinceEpoch == 0 ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(d);
//
//   bool _assignedToMe(Docket d) => _myAssignments.containsKey('${d.id}');
//
//   List<Docket> _pendingMine() => _allDockets.where((d) {
//     final status = (d.AssignedTime ?? '0').trim();
//     return status == '1' && _assignedToMe(d);
//   }).toList()
//     ..sort((a, b) => _parseLoose(a.uploadedTime).compareTo(_parseLoose(b.uploadedTime)));
//
//   List<Docket> _completedMine() => _allDockets.where((d) {
//     final status = (d.AssignedTime ?? '0').trim();
//     return status == '2' && _assignedToMe(d);
//   }).toList()
//     ..sort((a, b) => _parseLoose(b.completedTime).compareTo(_parseLoose(a.completedTime)));
//
//   // ---------- UI ----------
//   @override
//   Widget build(BuildContext context) {
//     final me = Provider.of<UserAccess>(context, listen: false).employeeNumber ?? '';
//
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Technician'),
//           backgroundColor: const Color(0xFF003366),
//           foregroundColor: Colors.white,
//           actions: [
//             IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
//           ],
//           bottom: const TabBar(tabs: [
//             Tab(text: 'Assigned'),
//             Tab(text: 'Completed'),
//           ]),
//         ),
//         body: _loading
//             ? const Center(child: CircularProgressIndicator())
//             : _error != null
//             ? _ErrorView(message: _error!, onRetry: _load)
//             : me.trim().isEmpty
//             ? const _ErrorView(
//           message:
//           'Your employee number is missing. Please sign in again or contact admin.',
//         )
//             : TabBarView(
//           children: [
//             _AssignedList(
//               items: _pendingMine(),
//               getAssignment: (d) => _myAssignments['${d.id}']!,
//               onTap: (d) => _openDetail(d, _myAssignments['${d.id}']!),
//             ),
//             _CompletedList(
//               items: _completedMine(),
//               getAssignment: (d) => _myAssignments['${d.id}']!,
//               onTap: (d) => _openDetail(d, _myAssignments['${d.id}']!),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _openDetail(Docket d, models.DocketAssignment a) {
//     final empNo = Provider.of<UserAccess>(context, listen: false).employeeNumber!;
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => AssignmentDetailPage(
//           docket: d,
//           assignment: a,
//           employeeNo: empNo,
//           onChanged: _load,
//         ),
//       ),
//     );
//   }
// }
//
// // ---------- Assigned list ----------
// class _AssignedList extends StatelessWidget {
//   final List<Docket> items;
//   final models.DocketAssignment Function(Docket) getAssignment;
//   final void Function(Docket) onTap;
//
//   const _AssignedList({
//     required this.items,
//     required this.getAssignment,
//     required this.onTap,
//   });
//
//   static DateTime _p(String? s) => _TechnicianPortalPageState._parseLoose(s);
//
//   @override
//   Widget build(BuildContext context) {
//     if (items.isEmpty) {
//       return const _Empty(icon: Icons.inbox, title: 'No assigned jobs');
//     }
//     return ListView.separated(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//       itemBuilder: (_, i) {
//         final d = items[i];
//         final up = _p(d.uploadedTime);
//         final days = DateTime.now().difference(up).inDays;
//         final critical = days >= _TechnicianPortalPageState._criticalDays;
//
//         return Card(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//           child: ListTile(
//             leading: const CircleAvatar(
//               backgroundColor: Color(0xFFE8EEF6),
//               child: Icon(Icons.assignment, color: Color(0xFF003366)),
//             ),
//             title: Text(d.docketType,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF003366))),
//             subtitle: Text(
//               'Depot: ${d.depot} • Serial: ${d.docketSerial}\nUploaded: ${_TechnicianPortalPageState._pretty(up)}',
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//             ),
//             trailing: _DueBadge(days: days, critical: critical),
//             onTap: () => onTap(d),
//           ),
//         );
//       },
//       separatorBuilder: (_, __) => const SizedBox(height: 10),
//       itemCount: items.length,
//     );
//   }
// }
//
// // ---------- Completed list ----------
// class _CompletedList extends StatelessWidget {
//   final List<Docket> items;
//   final models.DocketAssignment Function(Docket) getAssignment;
//   final void Function(Docket) onTap;
//
//   const _CompletedList({
//     required this.items,
//     required this.getAssignment,
//     required this.onTap,
//   });
//
//   static DateTime _p(String? s) => _TechnicianPortalPageState._parseLoose(s);
//
//   @override
//   Widget build(BuildContext context) {
//     if (items.isEmpty) {
//       return const _Empty(icon: Icons.inbox, title: 'No completed jobs');
//     }
//     return ListView.separated(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//       itemBuilder: (_, i) {
//         final d = items[i];
//         final cAt = _p(d.completedTime);
//
//         return Card(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           child: ListTile(
//             leading: const CircleAvatar(
//               backgroundColor: Color(0xFFE8EEF6),
//               child: Icon(Icons.check, color: Color(0xFF003366)),
//             ),
//             title: Text(d.docketType,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF003366))),
//             subtitle: Text(
//               'Depot: ${d.depot} • Serial: ${d.docketSerial}\nCompleted: ${_TechnicianPortalPageState._pretty(cAt)}',
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//             ),
//             onTap: () => onTap(d),
//           ),
//         );
//       },
//       separatorBuilder: (_, __) => const SizedBox(height: 10),
//       itemCount: items.length,
//     );
//   }
// }
//
// // ---------- small UI bits ----------
// class _DueBadge extends StatelessWidget {
//   final int days;
//   final bool critical;
//   const _DueBadge({required this.days, required this.critical});
//
//   @override
//   Widget build(BuildContext context) {
//     final dueText = days <= 0 ? 'Due today' : 'Pending $days d';
//     final c = critical ? Colors.red : const Color(0xFF003366);
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: c.withOpacity(0.1),
//         border: Border.all(color: c.withOpacity(0.3)),
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Text(dueText, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
//     );
//   }
// }
//
// class _Empty extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   const _Empty({required this.icon, required this.title});
//
//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       physics: const AlwaysScrollableScrollPhysics(),
//       children: [
//         SizedBox(height: MediaQuery.of(context).size.height * 0.2),
//         Icon(icon, size: 64, color: Colors.black26),
//         const SizedBox(height: 12),
//         Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
//       ],
//     );
//   }
// }
//
// class _ErrorView extends StatelessWidget {
//   final String message;
//   final Future<void> Function()? onRetry;
//   const _ErrorView({required this.message, this.onRetry});
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
//             const SizedBox(height: 12),
//             Text(message, textAlign: TextAlign.center),
//             if (onRetry != null) ...[
//               const SizedBox(height: 12),
//               ElevatedButton(
//                 onPressed: onRetry,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF003366),
//                   foregroundColor: Colors.white,
//                 ),
//                 child: const Text('Retry'),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
