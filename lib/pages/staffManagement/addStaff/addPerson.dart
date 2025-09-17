import 'package:flutter/material.dart';

import '../model/httpServicePeople.dart';

const List<String> kDesignations = [
  'Admin', 'CE', 'SEE', 'EE', 'TO', 'CSS', 'RO', 'Technician'
];

const List<String> kBranches = [
  'HQ',
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
  'Kelaniya': ['Wattala', 'Kandana', 'Mahara', 'Dalugama'],
  'Kotte': ['Depot 1', 'Depot 2', 'Depot 3'],
  'Nugegoda': ['Depot 4', 'Depot 5'],
  'Moratuwa': ['Depot 6', 'Depot 7'],
  'Kalutara': ['Depot 8', 'Depot 9'],
  'Negombo': ['Depot 10', 'Depot 11'],
  'Galle': ['Depot 12', 'Depot 13'],
  'HQ': ['Head Office'],
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

  String _designation = 'Technician';
  String _accessLevel = '7';
  bool _active = true;
  bool _saving = false;
  String _selectedBranch = 'Kelaniya';
  String? _selectedDepot;
  bool _showOtherDepotField = false;
  final _otherDepotController = TextEditingController();

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
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    
    final personData = {
      'firstName': '$_salutation ${_first.text.trim()}',
      'lastName': _last.text.trim(),
      'depot': _depot.text.trim(),
      'branch': _branch.text.trim(),
      'employeeNo': _empNo.text.trim(),
      'designation': _designation.trim(),
      'accessLevel': _accessLevel.trim(),
      'available': _active ? 'Yes' : 'No',
      'uuid': _uuid.text.trim(),
    };
    
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
                        labelText: 'Employee Number *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // Branch
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedBranch,
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
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedBranch = value;
                            _branch.text = value;
                            _selectedDepot = null;
                            _depot.clear();
                            _showOtherDepotField = value == 'Other';
                            if (!_showOtherDepotField) {
                              _otherDepotController.clear();
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // Depot
                    if (_showOtherDepotField)
                      TextFormField(
                        controller: _otherDepotController,
                        decoration: InputDecoration(
                          labelText: 'Enter Depot Name *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          _depot.text = value;
                        },
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      )
                    else
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
                        items: (kBranchDepots[_selectedBranch] ?? []).map((depot) => DropdownMenuItem(
                              value: depot,
                              child: Text(depot),
                            )).toList(),
                        validator: (value) => value == null ? 'Required' : null,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedDepot = value;
                              _depot.text = value;
                            });
                          }
                        },
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
                            onChanged: (v) => setState(() => _designation = v ?? _designation),
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
                            initialValue: _accessLevel,
                            decoration: InputDecoration(
                              labelText: 'Access Level *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _accessLevel = v,
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