import 'package:flutter/material.dart';

import '../model/httpServicePeople.dart';

const List<String> kDesignations = [
  'Admin', 'CE', 'SEE', 'EE', 'TO', 'CSS', 'RO', 'Technician'
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
  
class AddPersonPage extends StatefulWidget {
  const AddPersonPage({super.key});

  @override
  State<AddPersonPage> createState() => _AddPersonPageState();
}

class _AddPersonPageState extends State<AddPersonPage> {
  final _form = GlobalKey<FormState>();
  final _svc = PeopleService();

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _depot = TextEditingController(text: '');
  final _branch = TextEditingController();
  String _salutation = 'Mr';
  final _empNo = TextEditingController();
  final _uuid = TextEditingController();
  final _accessLevelController = TextEditingController(text: kDesignationAccessLevels['Technician']);

  String _designation = 'Technician';
  String get _accessLevel => _accessLevelController.text;
  bool _active = true;
  bool _saving = false;
  String _selectedBranch = 'Kelaniya';
  String? _selectedDepot;
  bool _showOtherDepotField = false;
  bool _showOtherBranchField = false;
  final _otherDepotController = TextEditingController();
  final _otherBranchController = TextEditingController();

  Future<void> _showCustomBranchDialog() async {
    final TextEditingController customBranchController = TextEditingController();
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Branch Name'),
          content: TextField(
            controller: customBranchController,
            decoration: const InputDecoration(
              hintText: 'Enter custom branch name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (customBranchController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true && customBranchController.text.trim().isNotEmpty) {
      setState(() {
        _selectedBranch = customBranchController.text.trim();
        _branch.text = _selectedBranch;
        _showOtherBranchField = true;
        _otherBranchController.text = _selectedBranch;
        
        // Reset depot when branch changes to custom
        _selectedDepot = null;
        _depot.clear();
        _showOtherDepotField = false;
        _otherDepotController.clear();
      });
    } else {
      // Reset to previous selection if user cancels or enters empty text
      setState(() {
        _selectedBranch = 'Kelaniya'; // or keep previous valid selection
        _branch.text = _selectedBranch;
        _showOtherBranchField = false;
      });
    }
  }

  Future<void> _showCustomDepotDialog() async {
    final TextEditingController customDepotController = TextEditingController();
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Depot Name'),
          content: TextField(
            controller: customDepotController,
            decoration: const InputDecoration(
              hintText: 'Enter custom depot name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (customDepotController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true && customDepotController.text.trim().isNotEmpty) {
      setState(() {
        _selectedDepot = customDepotController.text.trim();
        _depot.text = _selectedDepot!;
        _showOtherDepotField = true;
        _otherDepotController.text = _selectedDepot!;
      });
    } else {
      // Reset to null if user cancels or enters empty text
      setState(() {
        _selectedDepot = null;
        _depot.clear();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _branch.text = _selectedBranch;
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _depot.dispose();
    _branch.dispose();
    _empNo.dispose();
    _uuid.dispose();
    _otherDepotController.dispose();
    _otherBranchController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    
    final isHeadOffice = _branch.text.trim() == 'Head Office';
    final personData = {
      'firstName': '$_salutation ${_first.text.trim()}',
      'lastName': _last.text.trim(),
      'depot': isHeadOffice ? 'Head Office' : _depot.text.trim(),
      'branch': _branch.text.trim(),
      'employeeNo': _empNo.text.trim(),
      'designation': _designation.trim(),
      'accessLevel': _accessLevel.trim(),
      'available': _active ? 'Yes' : 'No',
      'uuid': _uuid.text.trim(),
    };
    
    debugPrint('Is Head Office: $isHeadOffice');
    debugPrint('Original Depot: ${_depot.text.trim()}');
    debugPrint('Final Depot: ${personData['depot']}');
    
    debugPrint('Saving person data: $personData');
    final ok = await _svc.createPerson(
      firstName: personData['firstName']!,
      lastName: personData['lastName']!,
      depot: personData['depot']!,
      employeeNo: personData['employeeNo']!,
      designation: personData['designation']!,
      accessLevel: personData['accessLevel']!,
      available: personData['available']!,
      uuid: personData['uuid']!,
    );
    setState(() => _saving = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Person added successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add person'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Person'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Title and First Name row
                    Row(
                      children: [
                        SizedBox(
                          width: 100, // Increased from 80 to 100
                          child: DropdownButtonFormField<String>(
                            isExpanded: true, // Ensure text doesn't overflow
                            value: _salutation,
                            decoration: InputDecoration(
                              labelText: 'Title',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Mr', child: Text('Mr')),
                              DropdownMenuItem(value: 'Mrs', child: Text('Mrs')),
                              DropdownMenuItem(value: 'Ms', child: Text('Ms')),  
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _salutation = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _first,
                            decoration: InputDecoration(
                              labelText: 'First Name *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Last Name row
                    TextFormField(
                      controller: _last,
                      decoration: InputDecoration(
                        labelText: 'Last Name *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // Employee number
                    TextFormField(
                      controller: _empNo,
                      decoration: InputDecoration(
                        labelText: 'Employee ID *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'Enter Employee ID',
                      ),
                      keyboardType: TextInputType.text,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // Branch
                    if (_showOtherBranchField && !kBranches.contains(_selectedBranch))
                      TextFormField(
                        controller: _otherBranchController,
                        decoration: InputDecoration(
                          labelText: 'Enter Branch Name *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          _branch.text = value;
                          _selectedBranch = value;
                        },
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      )
                    else
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: kBranches.contains(_selectedBranch) ? _selectedBranch : null,
                        decoration: InputDecoration(
                          labelText: 'Branch *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: kBranches
                            .map((branch) => DropdownMenuItem(
                                  value: branch,
                                  child: Text(branch),
                                ))
                            .toList(),
                        onChanged: (value) async {
                          if (value == 'Other') {
                            await _showCustomBranchDialog();
                          } else if (value != null) {
                            setState(() {
                              _selectedBranch = value;
                              _branch.text = value;
                              _showOtherBranchField = false;
                              
                              if (value == 'Head Office') {
                                _selectedDepot = 'Head Office';
                                _depot.text = 'Head Office';
                                _showOtherDepotField = false;
                              } else {
                                _selectedDepot = null;
                                _depot.clear();
                                _showOtherDepotField = false;
                                _otherDepotController.clear();
                              }
                            });
                          }
                        },
                      ),
                    const SizedBox(height: 20),
                    
                    // Depot
                    if (_selectedBranch == 'Head Office')
                      TextFormField(
                        controller: TextEditingController(text: 'Head Office'),
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Region / Depot',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      )
                    else if (_showOtherDepotField && _selectedDepot != null)
                      TextFormField(
                        controller: _otherDepotController,
                        decoration: InputDecoration(
                          labelText: 'Enter Depot Name *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          _depot.text = value!;
                        },
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      )
                    else if (kBranchDepots.containsKey(_selectedBranch))
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedDepot,
                        decoration: InputDecoration(
                          labelText: 'Region / Depot *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        hint: const Text('Select depot'),
                        items: (kBranchDepots[_selectedBranch] ?? []).map((depot) {
                          return DropdownMenuItem(
                            value: depot,
                            child: Text(depot == 'Other' ? 'Other' : depot),
                          );
                        }).toList(),
                        validator: (value) => value == null ? 'Required' : null,
                        onChanged: (value) async {
                          if (value == 'Other') {
                            await _showCustomDepotDialog();
                          } else if (value != null) {
                            setState(() {
                              _selectedDepot = value;
                              _depot.text = value;
                              _showOtherDepotField = false;
                            });
                          }
                        },
                      )
                    else
                      // For custom branches, show a text field for depot entry
                      TextFormField(
                        controller: _depot,
                        decoration: InputDecoration(
                          labelText: 'Region / Depot *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          hintText: 'Enter depot name',
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    const SizedBox(height: 20),
                    
                    // Designation and Access Level
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _designation,
                            items: kDesignations
                                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _designation = v;
                                  _accessLevelController.text = kDesignationAccessLevels[v] ?? '8';
                                });
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Designation *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _accessLevelController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Access Level *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _accessLevelController.text = v ?? '',
                            validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // UUID
                    TextFormField(
                      controller: _uuid,
                      decoration: InputDecoration(
                        labelText: 'UUID (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Active status
                    Card(
                      child: SwitchListTile(
                        title: const Text('Active Status'),
                        subtitle: Text(_active ? 'Available' : 'Not Available'),
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                        activeColor: const Color(0xFF003366),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom save button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Saving...' : 'Save Person'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}