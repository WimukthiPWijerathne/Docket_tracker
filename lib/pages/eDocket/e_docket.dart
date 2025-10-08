import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'e_docket_model.dart';
import 'e_docket_service.dart';

class EDocketPage extends StatefulWidget {
  const EDocketPage({super.key});

  @override
  State<EDocketPage> createState() => _EDocketPageState();
}

class _EDocketPageState extends State<EDocketPage> {
  final _formKey = GlobalKey<FormBuilderState>();

  Set<int> _selectedErrorIndices = {};
  bool _isOtherErrorSelected = false;
  bool _isSubmitting = false;
  late DateTime _currentDateTime;
  bool _isManualDateTime = false;
  String _otherErrorText = ''; // Store the "Other" error text

  final List<String> _errorOptions = const [
    'The meter is not reachable.',
    'The meter is locked',
    'The meter cannot be read',
    'The meter is fast/slow/broken.',
    'No information on meter shifting',
    'No entry allowed',
    'The location cannot be found',
    'The seal is broken.',
    'The payment method is incorrect.',
    'Disconnected.',
    'The meter board is broken.',
    'Suspected of stealing electricity.',
    'Link has been removed',
    'Bill refused to be accepted.',
    'Pole bent/ broken',
    'A hanging "D"',
    'New supply. No details.',
    'Cable has come off the hook.',
    'Route not revealed.',
    'Service/wire down.',
    'No safety clearance.',
    'Wires under high tension.',
    'Closed for the third time.',
    'Home is abandoned.',
    'Circuit breaker missing/broken.',
    'Unauthorized extension.',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _currentDateTime = DateTime.now();
  }

  Future<void> _submitForm() async {
    final state = _formKey.currentState;
    if (state == null) return;

    state.save();
    if (!state.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final values = state.value;

      // Generate a unique docket number with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final docketNumber = 'DKT-$timestamp';

      final model = EDocket(
        docketNo: docketNumber,
        year: DateTime.now().year.toString(),
        accountNumber: (values['accountNumber'] as String?)?.trim(),
        customerName: (values['customerName'] as String).trim(),
        address: (values['address'] as String?)?.trim(),
        meterNumber: (values['meterNumber'] as String?)?.trim(),
        meterReading: (values['meterReading'] as String?)?.trim(),
        date: DateTime.now(), // Auto-capture current date and time
        poleNumber: (values['poleNumber'] as String?)?.trim(),
        selectedErrorIndex: _selectedErrorIndices.isNotEmpty
            ? _selectedErrorIndices.first
            : null,
      );

      final service = EDocketService(baseUrl: 'https://your.api.base.url');
      final response = await service.submitEDocket(model);

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-Docket submitted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submit failed: ${response.statusCode}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedErrorIndices.clear();
      _isOtherErrorSelected = false;
      _otherErrorText = '';
      _currentDateTime = DateTime.now(); // Update to current time on reset
      _isManualDateTime = false;
    });
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String _formatDateTime(DateTime dateTime) {
    // Format: Dec 25, 2024 at 2:30 PM
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;

    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year at $hour:$minute $period';
  }

  Future<void> _showOtherErrorDialog() async {
    final TextEditingController otherErrorController = TextEditingController(
      text: _otherErrorText,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Specify Other Error'),
          content: TextField(
            controller: otherErrorController,
            decoration: const InputDecoration(
              labelText: 'Enter error description',
              hintText: 'Type the error details here...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = otherErrorController.text.trim();
                Navigator.pop(context, text);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _otherErrorText = result;
      });
      // Update the otherError field with the entered text
      _formKey.currentState?.fields['otherError']?.didChange(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Docket'), elevation: 2),
      body: SafeArea(
        child: FormBuilder(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Account Number - First Field
                _buildSectionTitle('Account Information'),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'accountNumber',
                  decoration: _buildInputDecoration(
                    label: 'Account Number',
                    icon: Icons.account_circle,
                  ),
                  validator: (value) =>
                      _validateRequired(value, 'Account number'),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 12),
                // Date and Time Display/Selector
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isManualDateTime
                        ? Colors.orange.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isManualDateTime
                          ? Colors.orange.shade200
                          : Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: _isManualDateTime
                                ? Colors.orange.shade700
                                : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date & Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDateTime(_currentDateTime),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _isManualDateTime
                                        ? Colors.orange.shade900
                                        : Colors.blue.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isManualDateTime
                                  ? Colors.orange.shade100
                                  : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isManualDateTime
                                      ? Icons.edit
                                      : Icons.check_circle,
                                  size: 16,
                                  color: _isManualDateTime
                                      ? Colors.orange.shade700
                                      : Colors.green.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isManualDateTime ? 'Manual' : 'Auto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _isManualDateTime
                                        ? Colors.orange.shade700
                                        : Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: _currentDateTime,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (pickedDate != null) {
                                  setState(() {
                                    _currentDateTime = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      _currentDateTime.hour,
                                      _currentDateTime.minute,
                                    );
                                    _isManualDateTime = true;
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: const Text('Change Date'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                    _currentDateTime,
                                  ),
                                  initialEntryMode: TimePickerEntryMode.input,
                                );
                                if (pickedTime != null) {
                                  setState(() {
                                    _currentDateTime = DateTime(
                                      _currentDateTime.year,
                                      _currentDateTime.month,
                                      _currentDateTime.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                    _isManualDateTime = true;
                                  });
                                }
                              },
                              icon: const Icon(Icons.schedule, size: 18),
                              label: const Text('Change Time'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isManualDateTime) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentDateTime = DateTime.now();
                                _isManualDateTime = false;
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reset to Current Time'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Customer Details'),
                const SizedBox(height: 12),

                FormBuilderTextField(
                  name: 'customerName',
                  decoration: _buildInputDecoration(
                    label: 'Customer Name',
                    icon: Icons.person,
                  ),
                  validator: (value) =>
                      _validateRequired(value, 'Customer name'),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'address',
                  decoration: _buildInputDecoration(
                    label: 'Customer Address/Location Detail',
                    icon: Icons.location_on,
                  ),
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Meter Information'),
                const SizedBox(height: 12),

                FormBuilderTextField(
                  name: 'meterNumber',
                  decoration: _buildInputDecoration(
                    label: 'Meter Number',
                    icon: Icons.speed,
                  ),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'meterReading',
                  decoration: _buildInputDecoration(
                    label: 'Meter Reading',
                    icon: Icons.analytics,
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'poleNumber',
                  decoration: _buildInputDecoration(
                    label: 'Pole Number',
                    icon: Icons.cell_tower,
                  ),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Error Information'),
                const SizedBox(height: 12),

                // Multi-select dropdown with checkboxes
                InkWell(
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return StatefulBuilder(
                          builder: (context, setDialogState) {
                            return AlertDialog(
                              title: const Text('Select Error Type(s)'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _errorOptions.length,
                                  itemBuilder: (context, index) {
                                    final isSelected = _selectedErrorIndices
                                        .contains(index);
                                    final isOtherOption =
                                        index == _errorOptions.length - 1;

                                    return CheckboxListTile(
                                      value: isSelected,
                                      onChanged: (bool? value) async {
                                        if (value == true && isOtherOption) {
                                          // Show popup dialog for "Other" option when checking
                                          await _showOtherErrorDialog();
                                        }

                                        setDialogState(() {
                                          setState(() {
                                            if (value == true) {
                                              _selectedErrorIndices.add(index);
                                            } else {
                                              _selectedErrorIndices.remove(
                                                index,
                                              );
                                              // Clear the otherError field if unchecking "Other"
                                              if (isOtherOption) {
                                                _otherErrorText = '';
                                                _formKey
                                                    .currentState
                                                    ?.fields['otherError']
                                                    ?.didChange(null);
                                              }
                                            }
                                            _isOtherErrorSelected =
                                                _selectedErrorIndices.contains(
                                                  _errorOptions.length - 1,
                                                );
                                          });
                                        });
                                      },
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${index + 1}. ${_errorOptions[index]}',
                                              style: TextStyle(
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          if (isOtherOption && isSelected)
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit,
                                                size: 20,
                                                color: Theme.of(
                                                  context,
                                                ).primaryColor,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () async {
                                                // Allow editing when "Other" is already selected
                                                await _showOtherErrorDialog();
                                                setDialogState(() {
                                                  setState(() {});
                                                });
                                              },
                                              tooltip: 'Edit other error',
                                            ),
                                        ],
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      activeColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                      dense: true,
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedErrorIndices.clear();
                                      _isOtherErrorSelected = false;
                                      _otherErrorText = '';
                                      _formKey
                                          .currentState
                                          ?.fields['otherError']
                                          ?.didChange(null);
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Clear All'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Done'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                  child: InputDecorator(
                    decoration: _buildInputDecoration(
                      label: 'Select Error Type(s)',
                      icon: Icons.error_outline,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _selectedErrorIndices.isEmpty
                              ? const Text(
                                  'Tap to select error types',
                                  style: TextStyle(color: Colors.grey),
                                )
                              : Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: _selectedErrorIndices.map((index) {
                                    return Chip(
                                      label: Text(
                                        _errorOptions[index].length > 20
                                            ? '${_errorOptions[index].substring(0, 20)}...'
                                            : _errorOptions[index],
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      deleteIcon: const Icon(
                                        Icons.close,
                                        size: 16,
                                      ),
                                      onDeleted: () {
                                        setState(() {
                                          _selectedErrorIndices.remove(index);
                                          _isOtherErrorSelected =
                                              _selectedErrorIndices.contains(
                                                _errorOptions.length - 1,
                                              );
                                          if (!_isOtherErrorSelected) {
                                            _formKey
                                                .currentState
                                                ?.fields['otherError']
                                                ?.didChange(null);
                                          }
                                        });
                                      },
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),

                // Show custom error input when "Other" is selected
                if (_isOtherErrorSelected) ...[
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'otherError',
                    initialValue: _otherErrorText,
                    decoration: _buildInputDecoration(
                      label: 'Please specify the error',
                      icon: Icons.edit,
                    ),
                    validator: (value) {
                      if (_isOtherErrorSelected) {
                        return _validateRequired(value, 'Error description');
                      }
                      return null;
                    },
                    maxLines: 2,
                    textInputAction: TextInputAction.next,
                  ),
                ],

                const SizedBox(height: 24),
                _buildSectionTitle('Additional Information'),
                const SizedBox(height: 12),

                FormBuilderTextField(
                  name: 'remarks',
                  decoration: _buildInputDecoration(
                    label: 'Remarks',
                    icon: Icons.note,
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),

                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _resetForm,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitForm,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
