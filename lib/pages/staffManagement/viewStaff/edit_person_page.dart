import 'package:flutter/material.dart';

import '../model/httpServicePeople.dart';
import '../model/person.dart';

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

// Branches and Depots (aligned with Add Person page)
const List<String> kBranches = [
  'Head Office',
  'Kotte',
  'Nugegoda',
  'Moratuwa',
  'Kalutara',
  'Kelaniya',
  'Negombo',
  'Galle',
  'Other'
];

final Map<String, List<String>> kBranchDepots = {
  'Kelaniya': ['Wattala', 'Kandana', 'Mahara', 'Dalugama','Other'],
  'Kotte': ['Pitakotte', 'Kolonnawa', 'Kotikawatta','Other'],
  'Nugegoda': ['Boralesgamuwa', 'Nugegoda','Maharagama','Other'],
  'Moratuwa': ['Moratuwa North', 'Moratuwa South','Keselwatta','Panadura','Koralawella','Other'],
  'Kalutara': ['Payagala', 'Kalutara','Aluthgama','Other'],
  'Negombo': ['Negambo', 'Seeduwa','Ja-Ela','Other'],
  'Galle': ['Ambalangoda', 'Hikkaduwa','Galle','Other'],
  'Head Office': ['Head Office'],
};

class EditPersonPage extends StatefulWidget {
  final Person person;

  const EditPersonPage({super.key, required this.person});

  @override
  State<EditPersonPage> createState() => _EditPersonPageState();
}

class _EditPersonPageState extends State<EditPersonPage> {
  final _svc = PeopleService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _first;
  late TextEditingController _last;
  late TextEditingController _emp;
  late TextEditingController _accessLevel;
  late String _designation;
  String? _selectedDepot;
  late String _selectedBranch;
  bool _showOtherDepotField = false;
  final _otherDepotController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    _first = TextEditingController(text: p.firstName);
    _last = TextEditingController(text: p.lastName);
    _emp = TextEditingController(text: p.employeeNo);
    _designation = p.designation.isNotEmpty && kDesignations.contains(p.designation)
        ? p.designation
        : kDesignations.firstWhere((d) => d != 'All');
    // Infer branch from existing depot
    String inferredBranch = 'Other';
    if (p.depot == 'Head Office') {
      inferredBranch = 'Head Office';
    } else {
      for (final entry in kBranchDepots.entries) {
        if (entry.value.contains(p.depot)) {
          inferredBranch = entry.key;
          break;
        }
      }
    }
    _selectedBranch = inferredBranch;
    // Initialize depot based on person or inferred branch
    _selectedDepot = p.depot.isNotEmpty ? p.depot : (kBranchDepots[_selectedBranch]?.first ?? '');
    if (_selectedBranch == 'Other') {
      // Allow custom depot editing
      _showOtherDepotField = (_selectedDepot?.isNotEmpty ?? false) && _selectedDepot != 'Head Office';
      _otherDepotController.text = _selectedDepot ?? '';
    }
    final initialAccess = kDesignationAccessLevels[_designation] ?? p.accessLevel;
    _accessLevel = TextEditingController(text: initialAccess);
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _emp.dispose();
    _accessLevel.dispose();
    _otherDepotController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _changes(Person p) {
    final c = <Map<String, String>>[];
    if (_first.text.trim() != p.firstName) c.add({'field': 'First Name', 'old': p.firstName, 'new': _first.text.trim()});
    if (_last.text.trim() != p.lastName) c.add({'field': 'Last Name', 'old': p.lastName, 'new': _last.text.trim()});
    if ((_selectedDepot ?? '') != p.depot) c.add({'field': 'Depot', 'old': p.depot, 'new': _selectedDepot ?? ''});
    if (_emp.text.trim() != p.employeeNo) c.add({'field': 'Employee No', 'old': p.employeeNo, 'new': _emp.text.trim()});
    if (_designation != p.designation) c.add({'field': 'Designation', 'old': p.designation, 'new': _designation});
    if (_accessLevel.text.trim() != p.accessLevel) c.add({'field': 'Access Level', 'old': p.accessLevel, 'new': _accessLevel.text.trim()});
    return c;
  }

  Future<void> _confirmAndSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final p = widget.person;
    final changes = _changes(p);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.shade50),
                  child: Icon(Icons.save_rounded, color: Colors.blue.shade700),
                ),
                const SizedBox(height: 12),
                Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.blue.shade800)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF003366).withOpacity(0.2)),
                  ),
                  child: Text(p.fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF003366))),
                ),
                const SizedBox(height: 16),
                if (changes.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.edit_rounded, size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 6),
                        Text('Changes to be saved:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                      ]),
                      const SizedBox(height: 8),
                      ...changes.map((c) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)),
                            child: Row(children: [
                              Expanded(flex: 2, child: Text(c['field']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                              Expanded(flex: 3, child: Text(c['old']!, style: TextStyle(fontSize: 11, color: Colors.red.shade600, decoration: TextDecoration.lineThrough), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.grey),
                              Expanded(flex: 3, child: Text(c['new']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ]),
                          )),
                    ]),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                    child: Row(children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Text('No changes detected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                    ]),
                  ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade800,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm == true) {
      final result = await _svc.updatePerson(personID: widget.person.personID, fields: {
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'branch': _selectedBranch.trim(),
        'depot': (_selectedBranch == 'Other')
            ? _otherDepotController.text.trim()
            : (_selectedBranch == 'Head Office' ? 'Head Office' : _selectedDepot?.trim() ?? ''),
        'employeeNo': _emp.text.trim(),
        'designation': _designation.trim(),
        'accessLevel': _accessLevel.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _confirmCancel() async {
    final p = widget.person;
    final hasChanges = _first.text.trim() != p.firstName ||
        _last.text.trim() != p.lastName ||
        (_selectedDepot ?? '') != p.depot ||
        _emp.text.trim() != p.employeeNo ||
        _designation != p.designation ||
        _accessLevel.text.trim() != p.accessLevel;

    if (!hasChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.shade50), child: Icon(Icons.warning_rounded, color: Colors.orange.shade700)),
                const SizedBox(height: 12),
                Text('Unsaved Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                const SizedBox(height: 12),
                const Text('Discard changes and close the editor?', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Keep Editing'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade800,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Discard'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Person'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: _confirmAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF003366),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: TextFormField(controller: _first, decoration: const InputDecoration(labelText: 'First name'), validator: (v) => v == null || v.trim().isEmpty ? 'First name is required' : null)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _last, decoration: const InputDecoration(labelText: 'Last name'), validator: (v) => v == null || v.trim().isEmpty ? 'Last name is required' : null)),
              ]),
              const SizedBox(height: 12),
              // Branch selection
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedBranch,
                decoration: const InputDecoration(labelText: 'Branch *'),
                items: kBranches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedBranch = value!;
                    if (value == 'Head Office') {
                      _selectedDepot = 'Head Office';
                      _showOtherDepotField = false;
                      _otherDepotController.clear();
                    } else {
                      // For any branch, allow selecting 'Other' depot
                      _selectedDepot = '';
                      _showOtherDepotField = false;
                      _otherDepotController.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (_selectedBranch == 'Head Office') {
                          return TextFormField(
                            controller: TextEditingController(text: 'Head Office'),
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Region / Depot',
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: const OutlineInputBorder(),
                            ),
                          );
                        }

                        // Show either the custom depot field or the depot dropdown with 'Other' option
                        if (_showOtherDepotField) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Custom Depot Name *', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _otherDepotController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter custom depot name',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Please enter a depot name' : null,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDepot = value;
                                  });
                                },
                              ),
                            ],
                          );
                        }

                        final depots = kBranchDepots[_selectedBranch] ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedDepot != null && depots.contains(_selectedDepot) ? _selectedDepot : null,
                              decoration: const InputDecoration(
                                labelText: 'Select Depot *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: [
                                ...depots.map((depot) => 
                                  DropdownMenuItem(value: depot, child: Text(depot))
                                ),
                                const DropdownMenuItem<String>(
                                  value: 'Other',
                                  child: Text('Other (enter custom depot)'),
                                ),
                              ],
                              validator: (value) => value == null ? 'Please select a depot' : null,
                              onChanged: (value) {
                                if (value == 'Other') {
                                  setState(() {
                                    _showOtherDepotField = true;
                                    _selectedDepot = _otherDepotController.text.trim();
                                  });
                                } else if (value != null) {
                                  setState(() {
                                    _selectedDepot = value;
                                    _showOtherDepotField = false;
                                    _otherDepotController.clear();
                                  });
                                }
                              },
                            ),
                            if (_selectedBranch == 'Other') 
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Custom Depot'),
                                  onPressed: () {
                                    setState(() {
                                      _showOtherDepotField = true;
                                      _selectedDepot = _otherDepotController.text.trim();
                                    });
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emp,
                      decoration: const InputDecoration(labelText: 'Employee No'),
                      keyboardType: TextInputType.text,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Employee No is required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _designation.isNotEmpty ? _designation : null,
                    items: kDesignations.where((e) => e != 'All').map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _designation = v;
                          _accessLevel.text = kDesignationAccessLevels[v] ?? '';
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Designation'),
                    validator: (value) => value == null || value.isEmpty ? 'Please select a designation' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _accessLevel, decoration: const InputDecoration(labelText: 'Access level'), keyboardType: TextInputType.number, validator: (v) => v == null || v.trim().isEmpty ? 'Access level is required' : null)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF800000), // Maroon color
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmAndSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}


