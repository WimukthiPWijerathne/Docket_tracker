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

// Mapping of designations to their corresponding access levels
const Map<String, String> kDesignationAccessLevels = {
  'Admin': '1',
  'CE': '2',
  'SEE': '3',
  'EE': '4',
  'TO': '5',
  'CSS': '6',
  'RO': '7',
  'Technician': '8',
};

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

  // Helper function to generate changes list
  List<Map<String, String>> _generateChangesList(Person p, String firstName, String lastName, String depot, String empNo, String designation, String accessLevel) {
    List<Map<String, String>> changes = [];
    
    if (firstName.trim() != p.firstName) {
      changes.add({
        'field': 'First Name',
        'old': p.firstName,
        'new': firstName.trim(),
      });
    }
    
    if (lastName.trim() != p.lastName) {
      changes.add({
        'field': 'Last Name',
        'old': p.lastName,
        'new': lastName.trim(),
      });
    }
    
    if (depot != p.depot) {
      changes.add({
        'field': 'Depot',
        'old': p.depot,
        'new': depot,
      });
    }
    
    if (empNo.trim() != p.employeeNo) {
      changes.add({
        'field': 'Employee No',
        'old': p.employeeNo,
        'new': empNo.trim(),
      });
    }
    
    if (designation != p.designation) {
      changes.add({
        'field': 'Designation',
        'old': p.designation,
        'new': designation,
      });
    }
    
    if (accessLevel.trim() != p.accessLevel) {
      changes.add({
        'field': 'Access Level',
        'old': p.accessLevel,
        'new': accessLevel.trim(),
      });
    }
    
    return changes;
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
    final emp = TextEditingController(text: p.employeeNo);
    
    // Ensure designation is valid, fallback to first available option
    String designation = p.designation;
    if (designation.isEmpty || !kDesignations.contains(designation)) {
      designation = kDesignations.firstWhere((d) => d != 'All');
    }
    
    // Ensure depot is valid, fallback to first available option
    String selectedDepot = p.depot;
    if (selectedDepot.isEmpty || !kDepots.contains(selectedDepot)) {
      selectedDepot = kDepots.firstWhere((d) => d != 'All');
    }
    
    // Initialize access level based on designation
    String accessLevel = kDesignationAccessLevels[designation] ?? p.accessLevel;
    final accessLevelController = TextEditingController(text: accessLevel);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final formKey = GlobalKey<FormState>();
        return Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
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
                          child: TextFormField(
                              controller: first,
                              decoration: const InputDecoration(
                                  labelText: 'First name'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'First name is required';
                                }
                                return null;
                              })),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextFormField(
                              controller: last,
                              decoration: const InputDecoration(
                                  labelText: 'Last name'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Last name is required';
                                }
                                return null;
                              })),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedDepot.isNotEmpty ? selectedDepot : null,
                          items: kDepots
                              .where((e) => e != 'All')
                              .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              selectedDepot = v;
                            }
                          },
                          decoration: const InputDecoration(
                              labelText: 'Region / Depot'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a depot';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextFormField(
                            controller: emp,
                            decoration:
                            const InputDecoration(labelText: 'Employee No'),
                            keyboardType: TextInputType.text,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Employee No is required';
                              }
                              return null;
                            },
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: designation.isNotEmpty ? designation : null,
                          items: kDesignations
                              .where((e) => e != 'All')
                              .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              designation = v;
                              // Auto-fill access level based on designation
                              final newAccessLevel = kDesignationAccessLevels[v] ?? '';
                              accessLevel = newAccessLevel;
                              accessLevelController.text = newAccessLevel;
                            }
                          },
                          decoration: const InputDecoration(
                              labelText: 'Designation'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a designation';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: accessLevelController,
                          onChanged: (v) => accessLevel = v,
                          decoration: const InputDecoration(
                            labelText: 'Access level',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Access level is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            // Check if there are any changes before showing confirmation
                            bool hasChanges = first.text.trim() != p.firstName ||
                                last.text.trim() != p.lastName ||
                                selectedDepot != p.depot ||
                                emp.text.trim() != p.employeeNo ||
                                designation != p.designation ||
                                accessLevelController.text.trim() != p.accessLevel;

                            if (hasChanges) {
                              // Show confirmation dialog only if there are changes
                              final bool? confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white,
                                            const Color(0xFFF8FAFC),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.15),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Icon
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: RadialGradient(
                                                  colors: [
                                                    Colors.orange.shade100.withOpacity(0.3),
                                                    Colors.orange.shade200.withOpacity(0.1),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.orange.shade300.withOpacity(0.4),
                                                    blurRadius: 15,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.warning_rounded,
                                                size: 30,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                            
                                            const SizedBox(height: 16),
                                            
                                            // Title
                                            Text(
                                              'Unsaved Changes',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.orange.shade800,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            
                                            const SizedBox(height: 12),
                                            
                                            // Content
                                            Text(
                                              'You have unsaved changes. Do you want to discard them and close the editor?',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            
                                            const SizedBox(height: 24),
                                            
                                            // Action buttons
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                      gradient: LinearGradient(
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                        colors: [
                                                          Colors.green.shade500,
                                                          Colors.green.shade700,
                                                        ],
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.green.shade400.withOpacity(0.4),
                                                          blurRadius: 12,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: InkWell(
                                                        onTap: () => Navigator.of(context).pop(false),
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(
                                                                Icons.edit_rounded,
                                                                color: Colors.white,
                                                                size: 18,
                                                              ),
                                                              const SizedBox(width: 6),
                                                              Text(
                                                                'KEEP EDITING',
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.w700,
                                                                  fontSize: 12,
                                                                  letterSpacing: 0.5,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                
                                                const SizedBox(width: 12),
                                                
                                                Expanded(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.grey.shade300, width: 2),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.grey.shade200,
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Material(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: InkWell(
                                                        onTap: () => Navigator.of(context).pop(true),
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(
                                                                Icons.close_rounded,
                                                                color: Colors.grey.shade600,
                                                                size: 18,
                                                              ),
                                                              const SizedBox(width: 6),
                                                              Text(
                                                                'DISCARD',
                                                                style: TextStyle(
                                                                  color: Colors.grey.shade600,
                                                                  fontWeight: FontWeight.w600,
                                                                  fontSize: 12,
                                                                  letterSpacing: 0.5,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
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

                              if (confirm == true) {
                                Navigator.pop(ctx, false);
                              }
                            } else {
                              // No changes, close directly
                              Navigator.pop(ctx, false);
                            }
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState?.validate() ?? false) {
                              // Generate changes list
                              final changes = _generateChangesList(p, first.text, last.text, selectedDepot, emp.text, designation, accessLevelController.text);
                              
                              // Show confirmation dialog
                              final bool? confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    child: Container(
                                      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white,
                                            const Color(0xFFF8FAFC),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.15),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Icon
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: RadialGradient(
                                                  colors: [
                                                    Colors.blue.shade100.withOpacity(0.3),
                                                    Colors.blue.shade200.withOpacity(0.1),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.blue.shade300.withOpacity(0.4),
                                                    blurRadius: 15,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.save_rounded,
                                                size: 30,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                            
                                            const SizedBox(height: 16),
                                            
                                            // Title
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.blue.shade200,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                'Save Changes',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.blue.shade800,
                                                  letterSpacing: 0.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            
                                            const SizedBox(height: 12),
                                            
                                            // Person name
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF003366).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFF003366).withOpacity(0.2)),
                                              ),
                                              child: Text(
                                                p.fullName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF003366),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            
                                            const SizedBox(height: 16),
                                            
                                            // Changes section
                                            if (changes.isNotEmpty) ...[
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.grey.shade200),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.edit_rounded,
                                                          size: 16,
                                                          color: Colors.blue.shade600,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'Changes to be saved:',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.blue.shade700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    ...changes.map((change) => Container(
                                                      margin: const EdgeInsets.only(bottom: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: Colors.grey.shade300),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                              change['field']!,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.grey.shade700,
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 3,
                                                            child: Text(
                                                              change['old']!,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors.red.shade600,
                                                                decoration: TextDecoration.lineThrough,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          Icon(
                                                            Icons.arrow_forward_rounded,
                                                            size: 12,
                                                            color: Colors.grey.shade500,
                                                          ),
                                                          Expanded(
                                                            flex: 3,
                                                            child: Text(
                                                              change['new']!,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.green.shade600,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    )).toList(),
                                                  ],
                                                ),
                                              ),
                                            ] else ...[
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.green.shade200),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.check_circle_rounded,
                                                      size: 16,
                                                      color: Colors.green.shade600,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'No changes detected',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.green.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            
                                            const SizedBox(height: 20),
                                            
                                            // Action buttons
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.grey.shade300, width: 2),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.grey.shade200,
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Material(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: InkWell(
                                                        onTap: () => Navigator.of(context).pop(false),
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(
                                                                Icons.close_rounded,
                                                                color: Colors.grey.shade600,
                                                                size: 18,
                                                              ),
                                                              const SizedBox(width: 6),
                                                              Text(
                                                                'CANCEL',
                                                                style: TextStyle(
                                                                  color: Colors.grey.shade600,
                                                                  fontWeight: FontWeight.w600,
                                                                  fontSize: 12,
                                                                  letterSpacing: 0.5,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                
                                                const SizedBox(width: 12),
                                                
                                                Expanded(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                      gradient: LinearGradient(
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                        colors: [
                                                          Colors.blue.shade500,
                                                          Colors.blue.shade700,
                                                        ],
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.blue.shade400.withOpacity(0.4),
                                                          blurRadius: 12,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: InkWell(
                                                        onTap: () => Navigator.of(context).pop(true),
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(
                                                                Icons.save_rounded,
                                                                color: Colors.white,
                                                                size: 18,
                                                              ),
                                                              const SizedBox(width: 6),
                                                              Text(
                                                                'SAVE',
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.w700,
                                                                  fontSize: 12,
                                                                  letterSpacing: 0.5,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
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

                              if (confirm == true) {
                                final result = await _svc.updatePerson(
                                  personID: p.personID,
                                  fields: {
                                    'firstName': first.text.trim(),
                                    'lastName': last.text.trim(),
                                    'depot': selectedDepot.trim(),
                                    'employeeNo': emp.text.trim(),
                                    'designation': designation.trim(),
                                    'accessLevel': accessLevelController.text.trim(),
                                  },
                                );
                                if (!mounted) return;
                                Navigator.pop(ctx, result);
                              }
                            }
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
          ),
        );
      },
    );

    if (saved != null && saved != false) {
      await _load();
      if (!mounted) return;
      
      // Handle different response types
      if (saved is Map<String, dynamic>) {
        final status = saved['status'] as String?;
        final message = saved['message'] as String?;
        final affectedRows = saved['affected_rows'] as int?;
        
        if (status == 'success' || affectedRows != null && affectedRows > 0) {
          // Success case
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Successful!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        message ?? 'Person details updated successfully',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            elevation: 8,
          ));
        } else if (status == 'warning') {
          // Warning case (like "No changes made")
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No Changes Made',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        message ?? 'No changes were detected',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            elevation: 8,
          ));
        } else {
          // Error case
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Failed!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        message ?? 'Failed to update person details',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            elevation: 8,
          ));
        }
      } else if (saved == true) {
        // Fallback for boolean true response
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update Successful!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Person details updated successfully',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
          elevation: 8,
        ));
      }
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