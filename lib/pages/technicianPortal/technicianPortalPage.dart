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
  bool _loadingLocationDetails = false;
  bool _loadingWorkLogs = false;
  String? _error;

  /// All dockets (used to render cards)
  List<Docket> _allDockets = [];

  /// Map<docketId, List<AssignedDocket>> for all assignments (supports multiple assignments per docket)
  final Map<String, List<AssignedDocket>> _myAssignments = {};

  /// Map to store location details for each docket ID
  final Map<String, String> _locationDetails = {};

  /// Map to store WorkLog data for each docket ID
  final Map<String, WorkLog> _workLogs = {};

  late AnimationController _animationController;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Overdue',
    'Completed',
  ];

  // ================= CACHING SYSTEM =================
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Cache TTL (Time To Live) in minutes
  static const int _docketsCacheTTL = 5;
  static const int _assignmentsCacheTTL = 3;
  static const int _locationCacheTTL = 15;
  static const int _workLogCacheTTL = 2;

  static const int _criticalDays = 2;
  static const String docketDetailsApiBase =
      'https://powerprox.sltidc.lk/GETDocketDetails2.php';

  // ================= CACHE HELPER METHODS =================

  /// Check if cached data is still valid
  bool _isCacheValid(String key, int ttlMinutes) {
    if (!_cache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }

    final cacheTime = _cacheTimestamps[key]!;
    final now = DateTime.now();
    final diffMinutes = now.difference(cacheTime).inMinutes;

    return diffMinutes < ttlMinutes;
  }

  /// Store data in cache with timestamp
  void _setCacheData(String key, dynamic data, int ttlMinutes) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
    debugPrint('[Cache] Stored $key (TTL: ${ttlMinutes}min)');
  }

  /// Get data from cache if valid
  T? _getCacheData<T>(String key, int ttlMinutes) {
    if (_isCacheValid(key, ttlMinutes)) {
      debugPrint('[Cache] Hit for $key');
      return _cache[key] as T?;
    }
    debugPrint('[Cache] Miss for $key');
    return null;
  }

  /// Clear specific cache entry
  void _clearCache(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
    debugPrint('[Cache] Cleared $key');
  }

  // ================= CACHED API METHODS =================

  /// Fetch dockets with caching
  Future<List<Docket>> _fetchDocketsWithCache() async {
    const cacheKey = 'dockets';

    // Try to get from cache first
    final cachedDockets = _getCacheData<List<Docket>>(
      cacheKey,
      _docketsCacheTTL,
    );
    if (cachedDockets != null) {
      return cachedDockets;
    }

    // Fetch from API and cache
    final dockets = await _docketSvc.fetchDockets();
    _setCacheData(cacheKey, dockets, _docketsCacheTTL);
    return dockets;
  }

  /// Fetch assigned dockets with caching
  Future<List<AssignedDocket>> _fetchAssignedDocketsWithCache() async {
    const cacheKey = 'assigned_dockets';

    // Try to get from cache first
    final cachedAssignments = _getCacheData<List<AssignedDocket>>(
      cacheKey,
      _assignmentsCacheTTL,
    );
    if (cachedAssignments != null) {
      return cachedAssignments;
    }

    // Fetch from API and cache
    final assignments = await _assignedDocketSvc.fetchAssignedDockets();
    _setCacheData(cacheKey, assignments, _assignmentsCacheTTL);
    return assignments;
  }

  // status code sets (strings)
  static const Set<String> _completedCodes = {'2'};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadWithOptimizations();
    _fetchAssignedDockets();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Fetch assigned dockets for the current user
  Future<void> _fetchAssignedDockets() async {
    try {
      setState(() {
        _loading = true;
      });

      // Replace 'currentUserId' with the actual user ID of the logged-in technician
      final currentUserId =
          'current_user_id'; // You need to get this from your auth system
      final assignedDockets = await _assignedDocketSvc
          .fetchAssignedDocketsByPerson(currentUserId);

      setState(() {
        _myAssignments.clear();

        // Process assignments (supporting multiple assignments per docket)
        for (var assignment in assignedDockets) {
          final k = assignment.docketID;
          if (_myAssignments[k] == null) {
            _myAssignments[k] = [];
          }
          _myAssignments[k]!.add(assignment);
        }
      });
    } catch (e) {
      print('Error fetching assigned dockets: $e');
      // Handle error (e.g., show a snackbar or error message)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load assigned dockets: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ---------------- Optimized Load with Parallel API Calls ----------------
  Future<void> _loadWithOptimizations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Execute ALL essential API calls in parallel for maximum speed
      debugPrint('[TechPortal] Starting parallel API calls...');
      final startTime = DateTime.now();

      final results = await Future.wait([
        _fetchDocketsWithCache(),
        _fetchAssignedDocketsWithCache(),
      ], eagerError: false); // Don't fail all if one fails

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('[TechPortal] Parallel API calls completed in ${loadTime}ms');

      final dockets = results[0] as List<Docket>;
      final allAssignments = results[1] as List<AssignedDocket>;

      debugPrint('[TechPortal] fetched ${dockets.length} dockets');
      debugPrint('[TechPortal] fetched ${allAssignments.length} assignments');

      // 2) Index assignments quickly using optimized processing
      _myAssignments.clear();
      int assignmentCount = 0;

      // Use a more efficient approach for assignment processing (supporting multiple assignments per docket)
      for (final a in allAssignments) {
        final k = _normalizeAssignmentDocketId(a);
        if (k.isNotEmpty) {
          if (_myAssignments[k] == null) {
            _myAssignments[k] = [];
          }
          _myAssignments[k]!.add(a);
          assignmentCount++;
        } else {
          debugPrint('[TechPortal] WARN: assignment without docketId → $a');
        }
      }
      debugPrint('[TechPortal] total assignments indexed → $assignmentCount');

      // 3) Update UI immediately with essential data
      setState(() {
        _allDockets = dockets;
        _loading = false;
      });

      // Start animation for the cards we already have
      _animationController.reset();
      _animationController.forward();

      // 4) Load additional data in background without blocking UI
      _loadAdditionalDataInBackground();

      final totalAssigned = _allDockets.where(_hasAssignment).length;
      debugPrint(
        '[TechPortal] showing $totalAssigned assigned dockets immediately',
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

  // Load additional data without blocking the UI - Fully Parallel
  Future<void> _loadAdditionalDataInBackground() async {
    // Get assigned dockets for background loading
    final assignedDockets = _allDockets.where(_hasAssignment).toList();

    if (assignedDockets.isEmpty) {
      debugPrint(
        '[TechPortal] No assigned dockets found for background loading',
      );
      return;
    }

    debugPrint(
      '[TechPortal] Starting background data loading for ${assignedDockets.length} dockets',
    );
    final startTime = DateTime.now();

    // Execute location details and work logs loading in FULL PARALLEL
    final futures = <Future<void>>[];

    // Always load location details in background (even if we have some)
    futures.add(_fetchLocationDetailsOptimized(assignedDockets));

    // Always load work logs in background (even if we have some)
    futures.add(_fetchWorkLogsOptimized(assignedDockets));

    try {
      // Wait for both background operations to complete
      await Future.wait(futures, eagerError: false);

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint(
        '[TechPortal] ✅ Background data loading completed in ${loadTime}ms',
      );

      // Single UI update when all background data is loaded
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[TechPortal] Error in background loading: $e');
      // Don't block UI even if background loading fails
    }
  }

  // Optimized location details fetching
  Future<void> _fetchLocationDetailsOptimized(
    List<Docket> assignedDockets,
  ) async {
    if (_loadingLocationDetails) return;

    setState(() {
      _loadingLocationDetails = true;
    });

    try {
      debugPrint(
        '🔍 Fetching location details for ${assignedDockets.length} dockets',
      );

      final response = await http
          .get(Uri.parse(docketDetailsApiBase))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('🔢 Found ${data.length} location records');

        // Create a map for faster lookups
        final Map<String, dynamic> locationMap = {};
        for (final item in data) {
          final id = item['ID']?.toString();
          if (id != null && id.isNotEmpty) {
            locationMap[id] = item;
          }
        }

        // Process assigned dockets with batch updates
        final Map<String, String> newLocationDetails = {};

        for (final docket in assignedDockets) {
          final docketId = docket.id.toString();
          final record = locationMap[docketId];

          if (record != null) {
            try {
              final combinedDetails = record['locationDetails']?.toString();
              if (combinedDetails != null &&
                  combinedDetails.isNotEmpty &&
                  combinedDetails != 'null') {
                newLocationDetails[docketId] = combinedDetails;
              } else {
                // Fallback to individual fields
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
                  newLocationDetails[docketId] = details.join(' • ');
                }
              }
            } catch (e) {
              debugPrint('❌ Error processing docket $docketId: $e');
            }
          }
        }

        // Batch update location details
        _locationDetails.addAll(newLocationDetails);
        debugPrint(
          '[TechPortal] Loaded location details for ${newLocationDetails.length} dockets',
        );
      } else {
        debugPrint(
          '❌ Failed to fetch location details. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[TechPortal] Error fetching location details: $e');
    } finally {
      setState(() {
        _loadingLocationDetails = false;
      });
    }
  }

  // Highly Optimized work logs fetching with parallel processing
  Future<void> _fetchWorkLogsOptimized(List<Docket> assignedDockets) async {
    if (_loadingWorkLogs || assignedDockets.isEmpty) return;

    setState(() {
      _loadingWorkLogs = true;
    });

    try {
      debugPrint(
        '🔍 Fetching WorkLog data for ${assignedDockets.length} dockets in parallel',
      );

      final startTime = DateTime.now();

      // Create all WorkLog fetch futures at once (fully parallel)
      final workLogFutures = assignedDockets.map((docket) async {
        try {
          final assignments = _myAssignments[_docketKeyFromDocket(docket)];
          if (assignments == null || assignments.isEmpty) return null;

          // Use the first assignment for WorkLog fetching
          final firstAssignment = assignments.first;
          final workLogs = await WorkLogService.getWorkLogs(
            assignmentId: firstAssignment.docketID,
            docketId: docket.id.toString(),
          ).timeout(const Duration(seconds: 8));

          if (workLogs.isNotEmpty) {
            return MapEntry(docket.id.toString(), workLogs.first);
          }
          return null;
        } catch (e) {
          debugPrint('❌ Error fetching WorkLog for docket ${docket.id}: $e');
          return null; // Return null instead of throwing to not break other requests
        }
      }).toList();

      // Execute all requests in parallel
      final results = await Future.wait(workLogFutures);

      // Process results and update map
      final Map<String, WorkLog> newWorkLogs = {};
      int successCount = 0;

      for (final result in results) {
        if (result != null) {
          newWorkLogs[result.key] = result.value;
          successCount++;
        }
      }

      // Single batch update to minimize UI rebuilds
      _workLogs.addAll(newWorkLogs);

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint(
        '[TechPortal] ✅ Loaded WorkLog data for $successCount/${assignedDockets.length} dockets in ${loadTime}ms',
      );
    } catch (e) {
      debugPrint('[TechPortal] Error in parallel WorkLog fetch: $e');
    } finally {
      setState(() {
        _loadingWorkLogs = false;
      });
    }
  }

  // Original _load method for refresh functionality
  Future<void> _load() async {
    // Clear cache on manual refresh to ensure fresh data
    _clearCache('dockets');
    _clearCache('assigned_dockets');
    debugPrint('[TechPortal] Manual refresh - cache cleared');

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
    final assignments = _myAssignments[_docketKeyFromDocket(d)];
    if (assignments != null && assignments.isNotEmpty) {
      // Check if any assignment has a completed reassigned status
      for (final assignment in assignments) {
        final Map<String, dynamic> m = _safeToJson(assignment);
        final r = (m['reassigned'] ?? '').toString().trim();
        if (_completedCodes.contains(r)) return true;
      }
    }
    return false;
  }

  bool _isPending(Docket d) {
    // A docket is pending if it's assigned but NOT completed
    if (_isCompleted(d)) return false; // If completed, it's not pending

    // Check if it has assignment (if assigned, it's pending unless completed)
    return _hasAssignment(d);
  }

  bool _isOverdue(Docket d) {
    // A docket is overdue if it's assigned, not completed, and past the critical days
    if (_isCompleted(d)) return false;
    if (!_hasAssignment(d)) return false;

    final up = _parseLoose(d.uploadedTime);
    final days = DateTime.now().difference(up).inDays;
    return days >= _criticalDays;
  }

  List<Docket> _getFilteredDockets() {
    final assignedDockets = _allDockets.where(_hasAssignment).toList();

    switch (_selectedFilter) {
      case 'Pending':
        return assignedDockets.where(_isPending).toList()..sort(
          (a, b) => _parseLoose(
            a.uploadedTime,
          ).compareTo(_parseLoose(b.uploadedTime)),
        );
      case 'Overdue':
        return assignedDockets.where(_isOverdue).toList()..sort(
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
                          final animationDelay =
                              index *
                              0.05; // Reduced delay for faster animation
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
                                begin: const Offset(
                                  0,
                                  0.2,
                                ), // Reduced slide distance
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

    // Get assignment info for this docket (list of assignments)
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

                  // Workflow Status Indicator
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

                  // Show assigned person info from assignment data
                  _buildInfoRow(
                    Icons.person_outline,
                    'Assigned To',
                    _getAssignedPersonsDisplay(docket, assignments),
                  ),

                  // Show location details if available
                  if (_locationDetails[docket.id.toString()]?.isNotEmpty ??
                      false)
                    _buildInfoRow(
                      Icons.location_on,
                      'Location',
                      _locationDetails[docket.id.toString()]!,
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

  // Build workflow status indicator
  Widget _buildWorkflowStatusIndicator(Docket docket) {
    final workLog = _workLogs[docket.id.toString()];
    final workflowStatus = _getWorkflowStatus(workLog);

    if (workflowStatus == 'Not Started') {
      return const SizedBox.shrink(); // Don't show anything if not started
    }

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

  // Helper method to determine workflow status from WorkLog
  String _getWorkflowStatus(WorkLog? workLog) {
    if (workLog == null) return 'Not Started';

    // Skip completed status since it's already shown in top-right corner
    if (workLog.completedAt != null) return 'Not Started';
    if (workLog.startedAt != null) return 'Started';
    if (workLog.attendingAt != null) return 'Attending';
    if (workLog.acknowledgedAt != null) return 'Acknowledged';

    return 'Not Started';
  }

  // Helper method to get workflow status color
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

  // Helper method to get workflow status icon
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

  // Helper method to get assigned persons display (supports multiple assignments)
  String _getAssignedPersonsDisplay(
    Docket docket,
    List<AssignedDocket>? assignments,
  ) {
    // First try to get from assignment data (more reliable)
    if (assignments != null && assignments.isNotEmpty) {
      // Collect all assigned persons from all assignments for this docket
      final assignedPersons = <String>[];
      for (final assignment in assignments) {
        if (assignment.assignedPersons.isNotEmpty) {
          // Split by comma in case single assignment has multiple persons
          final persons = assignment.assignedPersons
              .split(',')
              .map((e) => e.trim())
              .toList();
          assignedPersons.addAll(persons);
        }
      }

      // Remove duplicates and return comma-separated list
      if (assignedPersons.isNotEmpty) {
        final uniquePersons = assignedPersons.toSet().toList();
        return uniquePersons.join(', ');
      }
    }

    // Fallback to docket data
    if (docket.assignedTo.isNotEmpty &&
        docket.assignedTo.toLowerCase() != 'null') {
      return docket.assignedTo;
    }

    return 'Not Assigned';
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
