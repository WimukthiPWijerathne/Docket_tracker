import 'package:flutter/material.dart';
import '../../service/assigned_docket_service.dart';
import '../../models/assigned_docket.dart';
import '../AssignedDockets/assigned_docket_details.dart';

class AssignedDocketsPage extends StatefulWidget {
  final String userRole;
  
  const AssignedDocketsPage({
    super.key,
    required this.userRole,
  });

  @override
  State<AssignedDocketsPage> createState() => _AssignedDocketsPageState();
}

class _AssignedDocketsPageState extends State<AssignedDocketsPage>
    with TickerProviderStateMixin {
  late Future<List<AssignedDocket>> _assignedDocketsFuture;
  final AssignedDocketService _assignedDocketService = AssignedDocketService();
  late AnimationController _animationController;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'In Progress', 'Completed'];

  @override
  void initState() {
    super.initState();
    _assignedDocketsFuture = _assignedDocketService.fetchAssignedDockets();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _assignedDocketsFuture = _assignedDocketService.fetchAssignedDockets();
    });
    _animationController.reset();
    _animationController.forward();
  }

  List<AssignedDocket> _filterDockets(List<AssignedDocket> dockets) {
    switch (_selectedFilter) {
      case 'In Progress':
        return dockets.where((d) => d.isOngoing).toList();
      case 'Completed':
        return dockets.where((d) => d.isCompleted).toList();
      default:
        return dockets;
    }
  }

  Map<String, List<AssignedDocket>> _groupDocketsByID(List<AssignedDocket> dockets) {
    final Map<String, List<AssignedDocket>> groupedDockets = {};
    
    for (var docket in dockets) {
      final docketID = docket.docketID;
      if (!groupedDockets.containsKey(docketID)) {
        groupedDockets[docketID] = [];
      }
      groupedDockets[docketID]!.add(docket);
    }
    
    return groupedDockets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "Assigned Dockets",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: "Filter",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: FutureBuilder<List<AssignedDocket>>(
        future: _assignedDocketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                  ),
                  SizedBox(height: 24),
                  Text(
                    "Loading assigned dockets...",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
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
                      "Unable to load assigned dockets",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refreshData,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Try Again"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
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
                ),
              ),
            );
          }

          final allDockets = snapshot.data ?? [];
          final filteredDockets = _filterDockets(allDockets);

          if (allDockets.isEmpty) {
            return Center(
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
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "No assigned dockets",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "There are no assigned dockets available at the moment",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Group dockets by ID before displaying
          final groupedDockets = _groupDocketsByID(
            _selectedFilter == "Completed"
                ? filteredDockets
                : filteredDockets.where((d) => !d.isCompleted).toList(),
          );
          
          // Get a list of docket groups (each group has the same docketID)
          final docketGroups = groupedDockets.entries.toList();

          return RefreshIndicator(
            onRefresh: () async {
              _refreshData();
            },
            color: Colors.indigo,
            child: Column(
              children: [
                // Summary Cards Section
                Container(
                  margin: const EdgeInsets.all(16),
                  child: _buildSummarySection(allDockets),
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
                          selectedColor: Colors.indigo[100],
                          checkmarkColor: Colors.indigo[700],
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.indigo[700]
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

                // Dockets List
                Expanded(
                  child: docketGroups.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.filter_list_off,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedFilter == "Completed"
                                      ? "No completed dockets"
                                      : "No ongoing dockets",
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
                              itemCount: docketGroups.length,
                              itemBuilder: (context, index) {
                                final docketGroup = docketGroups[index];
                                final docket = docketGroup.value.first; // Get first docket for card details
                                // Get all unique assigned persons from all dockets in the group
                                final assignedPersons = docketGroup.value
                                    .expand((d) => d.assignedPersonsList)
                                    .toSet()
                                    .toList();
                                
                                final animationDelay = index * 0.1;
                                final animation = Tween<double>(begin: 0, end: 1).animate(
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
                                    child: _buildDocketCard(docket, index, assignedPersons: assignedPersons),
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
        },
      ),
    );
  }

  Widget _buildSummarySection(List<AssignedDocket> dockets) {
    // Group dockets by ID to count unique dockets
    final groupedDockets = _groupDocketsByID(dockets);
    final uniqueDockets = groupedDockets.values.map((list) => list.first).toList();
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: "Total Dockets",
            count: uniqueDockets.length,
            icon: Icons.assignment,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: "In Progress",
            count: uniqueDockets.where((d) => d.isOngoing).length,
            icon: Icons.hourglass_empty,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: "Completed",
            count: uniqueDockets.where((d) => d.isCompleted).length,
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

  Widget _buildDocketCard(AssignedDocket docket, int index, {List<String> assignedPersons = const []}) {
    // Use the assignedPersons parameter if provided, otherwise use the docket's assignedPersonsList
    final personsToShow = assignedPersons.isNotEmpty ? assignedPersons : docket.assignedPersonsList;
    final isCompleted = docket.isCompleted;
    final isOverdue = docket.isOverdue();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToDetails(docket),
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
                          : Colors.blue.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isCompleted
                    ? Colors.green.withOpacity(0.3)
                    : isOverdue
                        ? Colors.red.withOpacity(0.3)
                        : Colors.blue.withOpacity(0.2),
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
                      // Docket ID Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.indigo[600]!, Colors.indigo[700]!],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "ID: ${docket.docketID}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
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
                              isOverdue
                                  ? "OVERDUE"
                                  : docket.displayStatus.toUpperCase(),
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

                  // Assigned Persons
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Assigned to (${personsToShow.length}):",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: personsToShow.map((person) => 
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Colors.indigo[400],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                person,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        )
                      ).toList(),
                    ),
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
                              "Assigned",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              docket.formattedAssignedTime,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (docket.isCompleted)
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
                                docket.formattedCompletedTime,
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
                                docket.timeSinceAssignment,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
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

  void _navigateToDetails(AssignedDocket docket) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignedDocketDetailsPage(
          docket: docket,
          userRole: 'user', // Default role, adjust as needed based on your auth system
        ),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Filter Dockets",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ..._filterOptions.map((filter) {
                return RadioListTile<String>(
                  title: Text(filter),
                  value: filter,
                  groupValue: _selectedFilter,
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
            ],
          ),
        );
      },
    );
  }
}