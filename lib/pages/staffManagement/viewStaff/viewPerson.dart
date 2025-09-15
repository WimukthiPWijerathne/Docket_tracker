import 'package:flutter/material.dart';

import '../model/httpServicePeople.dart';
import '../model/person.dart';
import 'personDetail.dart'; // Add this import


const List<String> kDesignations = [
  'All',
  'Admin', 'CE', 'SEE', 'EE', 'TO', 'CSS', 'RO', 'Technician',
];

const List<String> kDepots = [
  'All',
  'Kadana',
  'Wattala',
  'Mahara',
  'Paliyagoda',
];

class ViewPeoplePage extends StatefulWidget {
  const ViewPeoplePage({super.key});

  @override
  State<ViewPeoplePage> createState() => _ViewPeoplePageState();
}

class _ViewPeoplePageState extends State<ViewPeoplePage> {
  final _svc = PeopleService();
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Person> _all = [];

  String _category = 'All';
  String _selectedDepot = 'All';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final people = await _svc.fetchPeople();
      setState(() {
        _all = people;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
        _all = [];
      });
    }
  }

  // Helper function to check if a person matches the search query
  bool _matchesSearchQuery(Person p, String query) {
    if (query.isEmpty) return true;
    
    final searchableFields = [
      p.firstName,
      p.lastName,
      p.fullName,
      p.employeeNo,
      p.depot,
      p.designation,
      p.accessLevel,
      p.uuid,
      p.available,
    ];
    
    // Check if any field contains the query (case insensitive)
    return searchableFields.any((field) => 
      field.toLowerCase().contains(query)
    );
  }

  List<Person> _applyFilters(bool activeTab) {
    Iterable<Person> list = _all.where((p) => p.isActive == activeTab);
    
    // Apply category filter
    if (_category != 'All') {
      list = list.where(
        (p) => p.designation.toLowerCase() == _category.toLowerCase(),
      );
    }
    
    // Apply depot filter
    if (_selectedDepot != 'All') {
      list = list.where(
        (p) => p.depot.toLowerCase() == _selectedDepot.toLowerCase(),
      );
    }
    
    // Apply search filter
    final searchQuery = _search.text.trim().toLowerCase();
    if (searchQuery.isNotEmpty) {
      list = list.where((p) => _matchesSearchQuery(p, searchQuery));
    }
    
    return list.toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  // Navigate to person detail page
  void _navigateToPersonDetail(Person person) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonDetailPage(person: person),
      ),
    ).then((_) {
      // Refresh the list when coming back from detail page
      _load();
    });
  }

  // ---------- UI helpers ----------

Widget _summaryPanel() {
  final total = _all.length;
  final active = _all.where((p) => p.isActive).length;
  final inactive = total - active;

  // Minimal stat chip
  Widget buildStatChip(String title, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 2),
    child: Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Minimal header
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: const Color(0xFF003366),
                  size: 14,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                if (total > 0)
                  Text(
                    '${((active / total) * 100).toStringAsFixed(0)}% active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Compact stats row
            Row(
              children: [
                buildStatChip('Total', total, Colors.blueGrey.shade700),
                buildStatChip('Active', active, Colors.green.shade700),
                buildStatChip('Inactive', inactive, Colors.red.shade700),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
  Future<void> _toggleActive(Person p) async {
    final ok =
    await _svc.setAvailability(personID: p.personID, active: !p.isActive);
    if (ok) {
      setState(() {
        final idx = _all.indexWhere((x) => x.personID == p.personID);
        if (idx >= 0) _all[idx] = p.copyWith(available: p.isActive ? 'No' : 'Yes');
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${p.fullName} marked ${p.isActive ? "Inactive" : "Active"}'),
      ));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Update failed'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _edit(Person p) async {
    final first = TextEditingController(text: p.firstName);
    final last = TextEditingController(text: p.lastName);
    final depot = TextEditingController(text: p.depot);
    final emp = TextEditingController(text: p.employeeNo);
    String designation = p.designation;
    String accessLevel = p.accessLevel;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Edit Person',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: first,
                              decoration: const InputDecoration(
                                  labelText: 'First name'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: last,
                              decoration: const InputDecoration(
                                  labelText: 'Last name'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: depot,
                              decoration: const InputDecoration(
                                  labelText: 'Region / Depot'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                            controller: emp,
                            decoration:
                            const InputDecoration(labelText: 'Employee No'),
                            keyboardType: TextInputType.number,
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: designation,
                          items: kDesignations
                              .where((e) => e != 'All')
                              .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) => designation = v ?? designation,
                          decoration: const InputDecoration(
                              labelText: 'Designation'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller:
                          TextEditingController(text: accessLevel),
                          onChanged: (v) => accessLevel = v,
                          decoration: const InputDecoration(
                              labelText: 'Access level'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final ok = await _svc.updatePerson(
                              personID: p.personID,
                              fields: {
                                'firstName': first.text.trim(),
                                'lastName': last.text.trim(),
                                'depot': depot.text.trim(),
                                'employeeNo': emp.text.trim(),
                                'designation': designation.trim(),
                                'accessLevel': accessLevel.trim(),
                              },
                            );
                            if (!mounted) return;
                            Navigator.pop(ctx, ok);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003366),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save'),
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
    );

    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Updated'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Widget _personCard(Person p) {
    // Build initials for avatar
    String initials() {
      final fn = p.firstName.trim();
      final ln = p.lastName.trim();
      final a = fn.isNotEmpty ? fn[0] : '';
      final b = ln.isNotEmpty ? ln[0] : '';
      return (a + b).toUpperCase();
    }
    
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Format meta information
    final meta1 = '${p.designation.isNotEmpty ? p.designation : 'No Designation'}';
    final meta2 = 'ID: ${p.employeeNo.isNotEmpty ? p.employeeNo : 'N/A'}';
    final meta3 = 'Region: ${p.depot.isNotEmpty ? p.depot : 'Not Assigned'}';
    final meta4 = 'Access: ${p.accessLevel.isNotEmpty ? p.accessLevel : 'No Access'}';
    
    // Determine if we need to show compact layout
    final showCompactLayout = MediaQuery.of(context).size.width < 400;

    final activeColor =
    p.isActive ? Colors.green.shade700 : Colors.red.shade700;
    final activeBg =
    p.isActive ? Colors.green.shade100 : Colors.red.shade100;

    return Card(
      elevation: 1.5,
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: 4,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToPersonDetail(p),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 12, 
            vertical: isMobile ? 8 : 10
          ),
          child: LayoutBuilder(
            builder: (ctx, c) {
              final isVeryNarrow = c.maxWidth < 400;
              final isExtraNarrow = c.maxWidth < 320;
              final showIconOnly = isExtraNarrow;

              final editButton = IconButton(
                tooltip: 'Edit',
                onPressed: () => _edit(p),
                icon: Icon(Icons.edit, size: showIconOnly ? 18 : 20),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              );

              // Only show edit button, no more toggle active button
              final actions = editButton;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // avatar + status
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: isMobile ? 20 : 22,
                        backgroundColor: const Color(0xFFE8EEF6),
                        child: Text(
                          initials(),
                          style: TextStyle(
                            color: const Color(0xFF003366),
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: activeBg,
                          child: Icon(
                            p.isActive ? Icons.check : Icons.close,
                            size: 14,
                            color: activeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700, 
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // First row: Designation and ID
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                meta1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF003366),
                                  fontWeight: FontWeight.w500,
                                  fontSize: isMobile ? 13 : 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                meta2,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: isMobile ? 11 : 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Second row: Region and Access Level
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                meta3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: isMobile ? 11.5 : 12.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                meta4,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: isMobile ? 11 : 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // actions (width-limited & wrapping)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? 150 : 240,
                    ),
                    child: actions,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Helper method to determine screen orientation
  bool get isPortrait => MediaQuery.of(context).orientation == Orientation.portrait;
  
  // Helper method to determine if the screen is in mobile layout
  bool get isMobile => MediaQuery.of(context).size.width < 600;
  
  // Helper method to determine if the screen is in tablet layout
  bool get isTablet => 
      MediaQuery.of(context).size.width >= 600 && 
      MediaQuery.of(context).size.width < 1200;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final activeList = _applyFilters(true);
    final inactiveList = _applyFilters(false);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('People'),
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Inactive'),
            ],
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 56, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
              : Column(
            children: [
              // Summary
              Padding(
                padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _summaryPanel(),
              ),
              // Filters
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16, 
                  0, 
                  16, 
                  isMobile ? 8 : 10
                ),
                child: isMobile && isPortrait
                    ? Column(
                        children: [
                          // First row: Category and Depot dropdowns
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _category,
                                  items: kDesignations
                                      .map((d) => DropdownMenuItem(
                                          value: d, 
                                          child: Text(d, overflow: TextOverflow.ellipsis)
                                      ))
                                      .toList(),
                                  onChanged: (v) => setState(() => _category = v ?? 'All'),
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  isExpanded: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedDepot,
                                  items: kDepots
                                      .map((d) => DropdownMenuItem(
                                          value: d, 
                                          child: Text(d, overflow: TextOverflow.ellipsis)
                                      ))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedDepot = v ?? 'All'),
                                  decoration: const InputDecoration(
                                    labelText: 'Depot',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  isExpanded: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Second row: Search field
                          TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              hintText: 'Search any field',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Dropdown
                          if (!isMobile || !isPortrait) ...[
                            SizedBox(
                              width: isTablet ? 200 : 260,
                              child: DropdownButtonFormField<String>(
                                value: _category,
                                items: kDesignations
                                    .map((d) => DropdownMenuItem(
                                        value: d, 
                                        child: Text(d, overflow: TextOverflow.ellipsis)
                                    ))
                                    .toList(),
                                onChanged: (v) => setState(() => _category = v ?? 'All'),
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                isExpanded: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          
                          // Depot Dropdown
                          if (!isMobile || !isPortrait) ...[
                            SizedBox(
                              width: isTablet ? 180 : 220,
                              child: DropdownButtonFormField<String>(
                                value: _selectedDepot,
                                items: kDepots
                                    .map((d) => DropdownMenuItem(
                                        value: d, 
                                        child: Text(d, overflow: TextOverflow.ellipsis)
                                    ))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedDepot = v ?? 'All'),
                                decoration: const InputDecoration(
                                  labelText: 'Depot',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                isExpanded: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          
                          // Search Field
                          Expanded(
                            child: TextField(
                              controller: _search,
                              decoration: InputDecoration(
                                hintText: isMobile && !isPortrait 
                                    ? 'Search...' 
                                    : 'Search any field (name, ID, depot, etc.)',
                                prefixIcon: const Icon(Icons.search),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                isDense: isMobile && !isPortrait,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              // Lists
              Expanded(
                child: TabBarView(
                  children: [
                    // Active
                    RefreshIndicator(
                      onRefresh: _load,
                      color: const Color(0xFF003366),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 16),
                        itemCount: activeList.length,
                        itemBuilder: (_, i) =>
                            _personCard(activeList[i]),
                      ),
                    ),
                    // Inactive
                    RefreshIndicator(
                      onRefresh: _load,
                      color: const Color(0xFF003366),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 16),
                        itemCount: inactiveList.length,
                        itemBuilder: (_, i) =>
                            _personCard(inactiveList[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}