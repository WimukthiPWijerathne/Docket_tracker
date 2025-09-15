import 'package:flutter/material.dart';

import '../model/httpServicePeople.dart';

const List<String> kDesignations = [
  'Admin', 'CE', 'SEE', 'EE', 'TO', 'CSS', 'RO', 'Technician'
];

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
  final _depot = TextEditingController();
  final _branch = TextEditingController();
  final _empNo = TextEditingController();
  final _uuid = TextEditingController();

  String _designation = 'Technician';
  String _accessLevel = '7';
  bool _active = true;
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _depot.dispose();
    _branch.dispose();
    _empNo.dispose();
    _uuid.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    
    final personData = {
      'firstName': _first.text.trim(),
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
        const SnackBar(content: Text('Person added'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add'), backgroundColor: Colors.red),
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _first,
                      decoration: const InputDecoration(labelText: 'First name'),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _last,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _branch,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  hintText: 'Enter branch',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _depot,
                decoration: const InputDecoration(labelText: 'Region / Depot'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _empNo,
                decoration: const InputDecoration(labelText: 'Employee No'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _designation,
                      items: kDesignations
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => _designation = v ?? _designation),
                      decoration: const InputDecoration(labelText: 'Designation'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _accessLevel,
                      decoration: const InputDecoration(labelText: 'Access level'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _accessLevel = v,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _uuid,
                decoration: const InputDecoration(labelText: 'UUID (optional)'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Active (available = Yes)'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
