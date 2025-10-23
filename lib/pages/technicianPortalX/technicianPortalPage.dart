import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:leco_docket_tracker/pages/technicianPortal/technicianAssignmentDetailPage.dart';

// --- Models
import '../../models/dockets.dart';
import '../../models/assigned_docket.dart';
import '../../models/docketAssignment.dart' as models;
import '../../models/WorkLog.dart';

// --- Services
import '../../service/dockey_service.dart' as dockey;
import '../../../service/assignment_service.dart';
import '../loginScreen/fetchUserAccess.dart';
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
  bool _loadingLocationDetails = false;
  bool _loadingWorkLogs = false;
  String? _error;
  String? _currentUserId;

  // first-load guard
  bool _bootstrapped = false;

  /// All dockets (used to render cards)
  List<Docket> _allDockets = [];

  /// Map<docketId, List<AssignedDocket>> for this user
  final Map<String, List<AssignedDocket>> _myAssignments = {};

  /// Map to store location details for each docket ID
  final Map<String, String> _locationDetails = {};

  /// Map to store WorkLog data for each docket ID
  final Map<String, WorkLog> _workLogs = {};

  late AnimationController _animationController;

  // chip filter
  String _selectedFilter = 'pending';
  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Overdue',
    'Completed',
  ];

  // type dropdown
  String _selectedType = 'All';
  List<String> _typeOptions = const ['All'];

  // ================= CACHING SYSTEM =================
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  static const int _docketsCacheTTL = 5;
  static const int _assignmentsCacheTTL = 3;
  static const int _locationCacheTTL = 15;
  static const int _workLogCacheTTL = 2;

  static const int _criticalDays = 2;
  static const String docketDetailsApiBase =
      'https://powerprox.sltidc.lk/GETDocketDetailsX.php';

  bool _isCacheValid(String key, int ttlMinutes) {
    if (!_cache.containsKey(key) || !_cacheTimestamps.containsKey(key))
      return false;
    final cacheTime = _cacheTimestamps[key]!;
    return DateTime.now().difference(cacheTime).inMinutes < ttlMinutes;
  }

  void _setCacheData(String key, dynamic data, int ttlMinutes) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  T? _getCacheData<T>(String key, int ttlMinutes) {
    if (_isCacheValid(key, ttlMinutes)) return _cache[key] as T?;
    return null;
  }

  void _clearCache(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }

  // ================= CACHED API METHODS =================
  Future<List<Docket>> _fetchDocketsWithCache() async {
    const cacheKey = 'dockets';
    final cached = _getCacheData<List<Docket>>(cacheKey, _docketsCacheTTL);
    if (cached != null) return cached;

    final dockets = await _docketSvc.fetchDockets();
    _setCacheData(cacheKey, dockets, _docketsCacheTTL);
    return dockets;
  }

  Future<List<AssignedDocket>> _fetchMyAssignedDocketsWithCache(
    String userId,
  ) async {
    final cacheKey = 'assigned_dockets_$userId';
    final cached = _getCacheData<List<AssignedDocket>>(
      cacheKey,
      _assignmentsCacheTTL,
    );
    if (cached != null) return cached;

    final list = await _assignedDocketSvc.fetchAssignedDocketsByPerson(userId);
    final List2 = list.where((docket) => docket.status == "0").toList();
    _setCacheData(cacheKey, List2, _assignmentsCacheTTL);
    return List2;
    // _setCacheData(cacheKey, list, _assignmentsCacheTTL);
    // return list;
  }

  static const Set<String> _completedCodes = {'2'};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    final ua = Provider.of<UserAccess>(context, listen: false);
    _currentUserId = ua.employeeNumber?.trim();
    debugPrint('[TechPortal] employeeNumber="${_currentUserId ?? 'null'}"');
    _bootstrapped = true;
    _loadWithOptimizations(); // start after we have employeeNumber
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ---------------- Optimized Load with Parallel API Calls ----------------
  Future<void> _loadWithOptimizations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = (_currentUserId ?? '').trim();
      if (userId.isEmpty) {
        throw Exception('Missing technician ID');
      }

      final results = await Future.wait([
        _fetchDocketsWithCache(),
        _fetchMyAssignedDocketsWithCache(userId),
      ], eagerError: false);

      final dockets = results[0] as List<Docket>;
      final myAssignments = results[1] as List<AssignedDocket>;
      // final myAssignments = (results[1] as List<AssignedDocket>)
      //     .where((a) => a.status != '1' && a.status != 1)
      //     .toList();

      _myAssignments.clear();
      for (final a in myAssignments) {
        final k = _normalizeAssignmentDocketId(a);
        if (k.isEmpty) continue;
        (_myAssignments[k] ??= []).add(a);
      }

      setState(() {
        _allDockets = dockets;
        _loading = false;
      });

      _rebuildTypeOptions(); // build type dropdown after data load

      _animationController
        ..reset()
        ..forward();

      _loadAdditionalDataInBackground();
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

  void _rebuildTypeOptions() {
    final types = <String>{};
    for (final d in _allDockets) {
      if (_hasAssignment(d)) {
        final t = d.docketType.trim();
        if (t.isNotEmpty) types.add(t);
      }
    }
    final list = ['All', ...types.toList()..sort()];
    setState(() {
      _typeOptions = list;
      if (!_typeOptions.contains(_selectedType)) _selectedType = 'All';
    });
  }

  // Load additional data in background
  Future<void> _loadAdditionalDataInBackground() async {
    final assignedDockets = _allDockets.where(_hasAssignment).toList();
    if (assignedDockets.isEmpty) return;

    final futures = <Future<void>>[
      _fetchLocationDetailsOptimized(assignedDockets),
      _fetchWorkLogsOptimized(assignedDockets),
    ];

    try {
      await Future.wait(futures, eagerError: false);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // Optimized location details fetching
  Future<void> _fetchLocationDetailsOptimized(
    List<Docket> assignedDockets,
  ) async {
    if (_loadingLocationDetails) return;
    setState(() => _loadingLocationDetails = true);

    try {
      final response = await http
          .get(Uri.parse(docketDetailsApiBase))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        final Map<String, dynamic> locationMap = {};
        for (final item in data) {
          final id = item['ID']?.toString();
          if (id != null && id.isNotEmpty) locationMap[id] = item;
        }

        final Map<String, String> newLocationDetails = {};
        for (final docket in assignedDockets) {
          final docketId = docket.id.toString();
          final record = locationMap[docketId];
          if (record == null) continue;

          final combinedDetails = record['locationDetails']?.toString();
          if (combinedDetails != null &&
              combinedDetails.isNotEmpty &&
              combinedDetails != 'null') {
            newLocationDetails[docketId] = combinedDetails;
          } else {
            final transformer = record['Transformer']?.toString() ?? '';
            final pole = record['Pole']?.toString() ?? '';
            final meterShift = record['MeterShift']?.toString() ?? '';
            final details = <String>[];
            if (transformer.isNotEmpty && transformer != 'null') {
              details.add('Transformer: $transformer');
            }
            if (pole.isNotEmpty && pole != 'null') details.add('Pole: $pole');
            if (meterShift.isNotEmpty && meterShift != 'null') {
              details.add('Meter Shift: $meterShift');
            }
            if (details.isNotEmpty) {
              newLocationDetails[docketId] = details.join(' • ');
            }
          }
        }

        _locationDetails.addAll(newLocationDetails);
      }
    } catch (_) {
    } finally {
      setState(() => _loadingLocationDetails = false);
    }
  }

  // Work logs fetching
  Future<void> _fetchWorkLogsOptimized(List<Docket> assignedDockets) async {
    if (_loadingWorkLogs || assignedDockets.isEmpty) return;
    setState(() => _loadingWorkLogs = true);

    try {
      final workLogFutures = assignedDockets.map((docket) async {
        try {
          final assignments = _myAssignments[_docketKeyFromDocket(docket)];
          if (assignments == null || assignments.isEmpty) return null;

          final firstAssignment = assignments.first;
          final workLogs = await WorkLogService.getWorkLogs(
            assignmentId: firstAssignment.docketID,
            docketId: docket.id.toString(),
          ).timeout(const Duration(seconds: 8));

          if (workLogs.isNotEmpty) {
            return MapEntry(docket.id.toString(), workLogs.first);
          }
          return null;
        } catch (_) {
          return null;
        }
      }).toList();

      final results = await Future.wait(workLogFutures);
      final Map<String, WorkLog> newWorkLogs = {};
      for (final r in results) {
        if (r != null) newWorkLogs[r.key] = r.value;
      }
      _workLogs.addAll(newWorkLogs);
    } catch (_) {
    } finally {
      setState(() => _loadingWorkLogs = false);
    }
  }

  // Manual refresh
  Future<void> _load() async {
    _clearCache('dockets');
    if (_currentUserId != null) {
      _clearCache('assigned_dockets_${_currentUserId!}');
    }
    await _loadWithOptimizations();
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

  String _docketKeyFromDocket(Docket d) => d.id.toString().trim();

  String _normalizeAssignmentDocketId(AssignedDocket a) => a.docketID.trim();

  Map<String, dynamic> _safeToJson(AssignedDocket a) {
    try {
      return a.toJson();
    } catch (_) {
      return const {};
    }
  }

  bool _hasAssignment(Docket d) =>
      _myAssignments.containsKey(_docketKeyFromDocket(d));

  bool _isCompleted(Docket d) {
    final workLog = _workLogs[d.id.toString()];
    if (workLog != null) {
      return workLog.completedAt != null && workLog.completedAt!.isNotEmpty;
    }
    final s = d.AssignedTime.trim();
    if (_completedCodes.contains(s)) return true;
    final assignments = _myAssignments[_docketKeyFromDocket(d)];
    if (assignments != null && assignments.isNotEmpty) {
      for (final assignment in assignments) {
        final Map<String, dynamic> m = _safeToJson(assignment);
        final r = (m['reassigned'] ?? '').toString().trim();
        if (_completedCodes.contains(r)) return true;
      }
    }
    return false;
  }

  bool _isPending(Docket d) {
    if (_isCompleted(d)) return false;
    return _hasAssignment(d);
  }

  bool _isOverdue(Docket d) {
    if (_isCompleted(d)) return false;
    if (!_hasAssignment(d)) return false;
    final up = _parseLoose(d.uploadedTime);
    final days = DateTime.now().difference(up).inDays;
    return days >= _criticalDays;
  }

  // --- ASSIGNEE FILTER HELPERS ---
  bool _isAssignedToMe(List<AssignedDocket>? rows) {
    final id = (_currentUserId ?? '').trim();
    if (id.isEmpty || rows == null || rows.isEmpty) return false;

    for (final r in rows) {
      final csv = (r.assignedPersons ?? '').trim();
      if (csv.isEmpty) continue;
      final hits = csv.split(',').map((s) => s.trim());
      if (hits.contains(id)) return true;
    }
    return false;
  }

  List<Docket> _myDocketsBase() {
    final out = <Docket>[];
    for (final d in _allDockets) {
      final rows = _myAssignments[_docketKeyFromDocket(d)];
      if (_isAssignedToMe(rows)) {
        out.add(d);
      } else {
        // debug
        // ignore: avoid_print
        print('[TechPortal] Exclude ${d.id} (not assigned to $_currentUserId)');
      }
    }
    // debug
    // ignore: avoid_print
    print(
      '[TechPortal] Base user-filtered dockets = ${out.length} for $_currentUserId',
    );
    return out;
  }

  List<Docket> _getFilteredDockets() {
    final base =
        _myDocketsBase(); // only dockets where assignedPersons contains this user

    // Apply docket type filter first
    List<Docket> typeFiltered = base;
    if (_selectedType != 'All') {
      typeFiltered = base.where((d) {
        final type = d.docketType.trim();
        return type == _selectedType;
      }).toList();
    }

    // Then apply status filter
    switch (_selectedFilter) {
      case 'Pending':
        return typeFiltered.where(_isPending).toList()..sort(
          (a, b) => _parseLoose(
            a.uploadedTime,
          ).compareTo(_parseLoose(b.uploadedTime)),
        );
      case 'Overdue':
        return typeFiltered.where(_isOverdue).toList()..sort(
          (a, b) => _parseLoose(
            a.uploadedTime,
          ).compareTo(_parseLoose(b.uploadedTime)),
        );
      case 'Completed':
        return typeFiltered.where(_isCompleted).toList()..sort(
          (a, b) => _parseLoose(
            b.completedTime,
          ).compareTo(_parseLoose(a.completedTime)),
        );
      default:
        return typeFiltered..sort((a, b) {
          if (_isPending(a) && _isCompleted(b)) return -1;
          if (_isCompleted(a) && _isPending(b)) return 1;
          return _parseLoose(
            a.uploadedTime,
          ).compareTo(_parseLoose(b.uploadedTime));
        });
    }
  }

  ({int total, int completed, int pending}) _summary() {
    final base = _myDocketsBase();
    int total = base.length, completed = 0, pending = 0;
    for (final d in base) {
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
        title: Row(
          children: [
            const Text(
              'Technician Portal',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_loadingLocationDetails || _loadingWorkLogs) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
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
      onRefresh: _load,
      color: const Color(0xFF003366),
      child: Column(
        children: [
          // Summary Cards
          Container(
            margin: const EdgeInsets.all(16),
            child: _buildSummarySection(summary),
          ),

          // Filter chips
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
                    onSelected: (_) => setState(() => _selectedFilter = filter),
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

          // Docket Type Filter Dropdown
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  'Type:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF003366).withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF003366),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                        items: _typeOptions.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedType = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                // Reset filters button (shown only when filters are active)
                if (_selectedType != 'All' || _selectedFilter != 'All')
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      icon: const Icon(Icons.clear),
                      iconSize: 20,
                      color: Colors.red[700],
                      tooltip: 'Clear filters',
                      onPressed: () {
                        setState(() {
                          _selectedType = 'All';
                          _selectedFilter = 'All';
                        });
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // List
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
                                : _selectedFilter == 'Pending'
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
                          final animationDelay = index * 0.05;
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
                                begin: const Offset(0, 0.2),
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
            title: "Pending",
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

    final assignments = _myAssignments[_docketKeyFromDocket(docket)];

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
            _myAssignments[_docketKeyFromDocket(docket)]!.first,
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
                      // type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF003366), Color(0xFF004488)],
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
                            const Icon(
                              Icons.assignment,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              docket.docketType.isNotEmpty
                                  ? docket.docketType
                                  : 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // status badge
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
                                  ? "OVERDUE (${DateTime.now().difference(up).inHours}h)"
                                  : "PENDING",
                              style: TextStyle(
                                fontSize: 11,
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

                  _buildWorkflowStatusIndicator(docket),

                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.business,
                    'Depot',
                    docket.depot.isNotEmpty ? docket.depot : 'N/A',
                  ),
                  _buildInfoRow(
                    Icons.receipt_long,
                    'Docket ID',
                    docket.docketSerial.isNotEmpty
                        ? docket.docketSerial
                        : docket.id,
                  ),
                  _buildInfoRow(
                    Icons.person_outline,
                    'Assigned To',
                    _getAssignedPersonsDisplay(docket, assignments),
                  ),

                  if (_locationDetails[docket.id.toString()]?.isNotEmpty ??
                      false)
                    _buildInfoRow(
                      Icons.location_on,
                      'Location',
                      _locationDetails[docket.id.toString()]!,
                    ),

                  const SizedBox(height: 12),

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
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _pretty(_parseLoose(docket.completedTime)),
                                style: TextStyle(
                                  fontSize: 13,
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
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$days ${days == 1 ? 'day' : 'days'}',
                                style: TextStyle(
                                  fontSize: 13,
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

  // Workflow status pill
  Widget _buildWorkflowStatusIndicator(Docket docket) {
    final workLog = _workLogs[docket.id.toString()];
    final workflowStatus = _getWorkflowStatus(workLog);
    if (workflowStatus == 'Not Started') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getWorkflowStatusColor(workflowStatus).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getWorkflowStatusColor(workflowStatus).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getWorkflowStatusIcon(workflowStatus),
                  size: 12,
                  color: _getWorkflowStatusColor(workflowStatus),
                ),
                const SizedBox(width: 4),
                Text(
                  workflowStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getWorkflowStatusColor(workflowStatus),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getWorkflowStatus(WorkLog? workLog) {
    if (workLog == null) return 'Not Started';
    if (workLog.completedAt != null) return 'Not Started';
    if (workLog.startedAt != null) return 'Started';
    if (workLog.attendingAt != null) return 'Attending';
    if (workLog.acknowledgedAt != null) return 'Acknowledged';
    return 'Not Started';
  }

  Color _getWorkflowStatusColor(String status) {
    switch (status) {
      case 'Acknowledged':
        return Colors.blue;
      case 'Attending':
        return Colors.orange;
      case 'Started':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getWorkflowStatusIcon(String status) {
    switch (status) {
      case 'Acknowledged':
        return Icons.visibility;
      case 'Attending':
        return Icons.directions_walk;
      case 'Started':
        return Icons.build;
      default:
        return Icons.help_outline;
    }
  }

  String _getAssignedPersonsDisplay(
    Docket docket,
    List<AssignedDocket>? assignments,
  ) {
    if (assignments != null && assignments.isNotEmpty) {
      final assignedPersons = <String>[];
      for (final assignment in assignments) {
        if (assignment.assignedPersons.isNotEmpty) {
          assignedPersons.addAll(
            assignment.assignedPersons.split(',').map((e) => e.trim()),
          );
        }
      }
      if (assignedPersons.isNotEmpty) {
        final uniquePersons = assignedPersons.toSet().toList();
        return uniquePersons.join(', ');
      }
    }
    if (docket.assignedTo.isNotEmpty &&
        docket.assignedTo.toLowerCase() != 'null') {
      return docket.assignedTo;
    }
    return 'Not Assigned';
  }

  models.DocketAssignment _convertToDetailAssignment(
    AssignedDocket assignedDocket,
  ) {
    return models.DocketAssignment(
      docketId: assignedDocket.docketID,
      assignedPersons: assignedDocket.assignedPersons,
      assignedTime: assignedDocket.assignedTime,
      status: assignedDocket.status,
      uploadedBy: assignedDocket.uploadedBy,
      uploadedTime: assignedDocket.uploadedTime,
    );
  }

  void _openDetail(Docket d, AssignedDocket a) {
    final detailAssignment = _convertToDetailAssignment(a);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignmentDetailPage(
          docket: d,
          assignment: detailAssignment,
          employeeNo: _currentUserId ?? 'UNKNOWN',
          onChanged: _load,
        ),
      ),
    );
  }
}

// ---------------- Shared UI ----------------
Widget _buildInfoRow(
  IconData icon,
  String label,
  String value, {
  Color? textColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: textColor ?? Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: textColor ?? Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor ?? Colors.black87,
            ),
            maxLines: 2,
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
