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
  List<Docket> _allDockets = [];
  final Map<String, AssignedDocket> _myAssignments = {};

  late AnimationController _refreshController;
  late TabController _tabController;

  static const int _criticalDays = 2;
  static const Set<String> _completedCodes = {'2'};
  static const Set<String> _pendingCodes = {'0', '1', '4', '', 'null'};

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_loading) {
      _refreshController.forward();
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dockets = await _docketSvc.fetchDockets();
      debugPrint('[TechPortal] fetched ${dockets.length} dockets');

      final allAssignments = await _assignedDocketSvc.fetchAssignedDockets();
      debugPrint(
        '[TechPortal] fetched ${allAssignments.length} assignments (unfiltered)',
      );

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

      setState(() {
        _allDockets = dockets;
        _loading = false;
      });

      if (!_loading) {
        _refreshController.reset();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
        _allDockets = [];
        _myAssignments.clear();
      });
      _refreshController.reset();
    }
  }

  // Helper methods (same as original)
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
      : DateFormat('MMM dd, yyyy • HH:mm').format(d);

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

  @override
  Widget build(BuildContext context) {
    final summary = _summary();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Removed the SliverAppBar and replaced with custom sliver to avoid back button overlap
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF003366),
                    Color(0xFF004080),
                    Color(0xFF0066CC),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isSmallScreen ? 16 : 24,
                    16, // Reduced top padding to prevent overlap
                    isSmallScreen ? 16 : 24,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.engineering,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Technician Portal',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          RotationTransition(
                            turns: _refreshController,
                            child: IconButton(
                              onPressed: _load,
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.white,
                              ),
                              tooltip: 'Refresh',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.15),
                                padding: const EdgeInsets.all(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCards(summary, isSmallScreen),
                      const SizedBox(height: 8), // Added spacing before tab bar
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabController: _tabController,
              summary: summary,
              isSmallScreen: isSmallScreen,
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _pendingAssignedList().isEmpty
                      ? _buildEmptyState(
                          Icons.assignment,
                          'No assigned jobs',
                          'All assigned jobs will appear here',
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          itemCount: _pendingAssignedList().length,
                          itemBuilder: (context, index) {
                            final d = _pendingAssignedList()[index];
                            final up = _parseLoose(d.uploadedTime);
                            final days = DateTime.now().difference(up).inDays;
                            final critical = days >= _criticalDays;

                            return _buildDocketCard(
                              docket: d,
                              status: critical ? 'Critical' : 'Pending',
                              statusColor: critical
                                  ? Colors.red
                                  : Colors.orange,
                              icon: Icons.assignment,
                              iconColor: critical
                                  ? Colors.red
                                  : const Color(0xFF003366),
                              onTap: () => _openDetail(
                                d,
                                _myAssignments[_docketKeyFromDocket(d)]!,
                              ),
                              subtitle: 'Uploaded: ${_pretty(up)}',
                              isCritical: critical,
                            );
                          },
                        ),
                  _completedAssignedList().isEmpty
                      ? _buildEmptyState(
                          Icons.check_circle,
                          'No completed jobs',
                          'Completed jobs will appear here',
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          itemCount: _completedAssignedList().length,
                          itemBuilder: (context, index) {
                            final d = _completedAssignedList()[index];
                            final cAt = _parseLoose(d.completedTime);

                            return _buildDocketCard(
                              docket: d,
                              status: 'Completed',
                              statusColor: Colors.green,
                              icon: Icons.check_circle,
                              iconColor: Colors.green,
                              onTap: () => _openDetail(
                                d,
                                _myAssignments[_docketKeyFromDocket(d)]!,
                              ),
                              subtitle: 'Completed: ${_pretty(cAt)}',
                            );
                          },
                        ),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryCards(
    ({int total, int completed, int pending}) summary,
    bool isSmallScreen,
  ) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Total',
            value: summary.total,
            icon: Icons.folder_outlined,
            color: Colors.blue.shade100,
            textColor: Colors.blue.shade800,
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: 'Pending',
            value: summary.pending,
            icon: Icons.pending_actions,
            color: Colors.orange.shade100,
            textColor: Colors.orange.shade800,
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: 'Completed',
            value: summary.completed,
            icon: Icons.check_circle,
            color: Colors.green.shade100,
            textColor: Colors.green.shade800,
            isSmallScreen: isSmallScreen,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocketCard({
    required Docket docket,
    required String status,
    required Color statusColor,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required String subtitle,
    bool isCritical = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docket.docketType,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Depot: ${docket.depot} • Serial: ${docket.docketSerial}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    final detailAssignment = _convertToDetailAssignment(a);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AssignmentDetailPage(
              docket: d,
              assignment: detailAssignment,
              employeeNo: '',
              onChanged: _load,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final Color textColor;
  final bool isSmallScreen;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: isSmallScreen ? 20 : 24),
                const SizedBox(width: 8),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 12,
                color: textColor.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final ({int total, int completed, int pending}) summary;
  final bool isSmallScreen;

  _TabBarDelegate({
    required this.tabController,
    required this.summary,
    required this.isSmallScreen,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFF003366),
      child: TabBar(
        controller: tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.7),
        labelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isSmallScreen ? 14 : 16,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.assignment, size: 18),
                const SizedBox(width: 6),
                const Text('Assigned'),
                if (summary.pending > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${summary.pending}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 18),
                const SizedBox(width: 6),
                const Text('Completed'),
                if (summary.completed > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${summary.completed}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
