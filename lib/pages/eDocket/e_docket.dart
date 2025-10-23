import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:image_picker/image_picker.dart';

import 'e_docket_model.dart';
import 'httpPostEDocket.dart';

class EDocketPage extends StatefulWidget {
  const EDocketPage({super.key});

  @override
  State<EDocketPage> createState() => _EDocketPageState();
}

class _EDocketPageState extends State<EDocketPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _imagePicker = ImagePicker();

  // Date & time
  bool _autoDateTime = true;

  // Errors
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
  String _otherErrorText = '';

  // Submit state
  bool _isSubmitting = false;

  // Images
  final List<XFile> _selectedImages = [];
  final int _maxImages = 5;

  // ---------- Helpers ----------
  InputDecoration _dec(BuildContext c, String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(c).primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      );

  // Validators (generic to satisfy v10 types)
  FormFieldValidator<T> _req<T>(String name) =>
      FormBuilderValidators.required<T>(errorText: '$name is required');

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum 5 images allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final img = await _imagePicker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (img != null) setState(() => _selectedImages.add(img));
  }

  Future<void> _pickMultipleImages() async {
    if (_selectedImages.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum 5 images allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final imgs = await _imagePicker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (imgs.isEmpty) return;
    final remaining = _maxImages - _selectedImages.length;
    setState(() => _selectedImages.addAll(imgs.take(remaining)));
    if (imgs.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only first $remaining images were added'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _removeImage(int i) => setState(() => _selectedImages.removeAt(i));

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _autoDateTime = true;
      _otherErrorText = '';
      _selectedImages.clear();
    });
  }

  Future<void> _submitForm() async {
    final st = _formKey.currentState;
    if (st == null) return;

    if (_autoDateTime) {
      st.fields['dateTime']?.didChange(DateTime.now());
    }

    st.save();
    if (!st.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final v = st.value;

      final ts = DateTime.now().millisecondsSinceEpoch;
      final docketNo = 'DKT-$ts';

      final model = EDocket(
        docketNo: docketNo,
        year: DateTime.now().year.toString(),
        accountNumber: v['accountNumber'],
        customerName: v['customerName'],
        address: v['address'],
        meterNumber: v['meterNumber'],
        meterReading: v['meterReading'],
        date: _autoDateTime ? DateTime.now() : (v['dateTime'] as DateTime?),
        poleNumber: v['poleNumber'],
      );

      final List<String> selectedErrors =
          (_formKey.currentState?.fields['errorTypes']?.value as List?)
              ?.cast<String>() ??
          [];

      // Submit via HttpPostEDocket and wait for TRUE/FALSE
      final ok =
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => HttpPostEDocket(
                model: model,
                errorTypes: selectedErrors,
                otherError: _otherErrorText,
                remarks:
                    _formKey.currentState?.fields['remarks']?.value as String?,
                imageNames: _selectedImages.map((x) => x.name).toList(),
                imageFiles: _selectedImages.map((x) => File(x.path)).toList(),
              ),
            ),
          ) ??
          false;

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-Docket submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submit failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------- UI ----------
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
                _sectionTitle(context, 'Account Information'),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'accountNumber',
                  decoration: _dec(
                    context,
                    'Account Number',
                    Icons.account_circle,
                  ),
                  validator: _req<String>('Account number'),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),
                _sectionTitle(context, 'Date & Time'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FormBuilderDateTimePicker(
                        name: 'dateTime',
                        decoration: _dec(context, '', Icons.access_time),
                        inputType: InputType.both,
                        initialValue: DateTime.now(),
                        enabled: !_autoDateTime,
                        validator: _req<DateTime>('Date & time'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Auto'),
                      selected: _autoDateTime,
                      onSelected: (v) {
                        setState(() => _autoDateTime = v);
                        if (v) {
                          _formKey.currentState?.fields['dateTime']?.didChange(
                            DateTime.now(),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: const Text('Change Date'),
                      onPressed: _autoDateTime
                          ? null
                          : () async {
                              final field =
                                  _formKey.currentState?.fields['dateTime'];
                              final current =
                                  (field?.value as DateTime?) ?? DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: current,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                final next = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  current.hour,
                                  current.minute,
                                );
                                field?.didChange(next);
                              }
                            },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: const Text('Change Time'),
                      onPressed: _autoDateTime
                          ? null
                          : () async {
                              final field =
                                  _formKey.currentState?.fields['dateTime'];
                              final current =
                                  (field?.value as DateTime?) ?? DateTime.now();
                              final t = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(current),
                                initialEntryMode: TimePickerEntryMode.input,
                              );
                              if (t != null) {
                                final next = DateTime(
                                  current.year,
                                  current.month,
                                  current.day,
                                  t.hour,
                                  t.minute,
                                );
                                field?.didChange(next);
                              }
                            },
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _sectionTitle(context, 'Customer Details'),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'customerName',
                  decoration: _dec(context, 'Customer Name', Icons.person),
                  validator: _req<String>('Customer name'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'address',
                  decoration: _dec(
                    context,
                    'Customer Address/Location Detail',
                    Icons.location_on,
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 24),
                _sectionTitle(context, 'Meter Information'),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'meterNumber',
                  decoration: _dec(context, 'Meter Number', Icons.speed),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'meterReading',
                  decoration: _dec(context, 'Meter Reading', Icons.analytics),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'poleNumber',
                  decoration: _dec(context, 'Pole Number', Icons.cell_tower),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),
                _sectionTitle(context, 'Error Information'),
                const SizedBox(height: 12),
                FormBuilderCheckboxGroup<String>(
                  name: 'errorTypes',
                  decoration: _dec(
                    context,
                    'Select Error Type(s)',
                    Icons.error_outline,
                  ),
                  options: _errorOptions
                      .map((e) => FormBuilderFieldOption(value: e))
                      .toList(),
                  validator: (val) {
                    if (val == null || val.isEmpty)
                      return 'Select at least one error type';
                    return null;
                  },
                  onChanged: (vals) {
                    final list = (vals ?? <String>[]);
                    if (!list.contains('Other')) {
                      _otherErrorText = '';
                      _formKey.currentState?.fields['otherError']?.didChange(
                        null,
                      );
                    }
                    setState(() {}); // show/hide other field
                  },
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final list =
                        (_formKey.currentState?.fields['errorTypes']?.value
                                as List?)
                            ?.cast<String>() ??
                        <String>[];
                    final otherSelected = list.contains('Other');
                    return Visibility(
                      visible: otherSelected,
                      child: FormBuilderTextField(
                        name: 'otherError',
                        initialValue: _otherErrorText,
                        decoration: _dec(
                          context,
                          'Please specify the error',
                          Icons.edit,
                        ),
                        maxLines: 2,
                        validator: otherSelected
                            ? _req<String>('Error description')
                            : null,
                        onChanged: (t) => _otherErrorText = t?.trim() ?? '',
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),
                _sectionTitle(context, 'Additional Information'),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'remarks',
                  decoration: _dec(context, 'Remarks', Icons.note),
                  maxLines: 3,
                ),

                const SizedBox(height: 24),
                _sectionTitle(context, 'Images (Optional)'),
                const SizedBox(height: 12),
                _imagesSection(),

                const SizedBox(height: 32),
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

  Widget _imagesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera, color: Color(0xFF003366)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add up to $_maxImages images',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _selectedImages.isEmpty
                      ? Colors.grey[300]
                      : Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedImages.length}/$_maxImages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _selectedImages.isEmpty
                        ? Colors.grey[700]
                        : Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _selectedImages.length >= _maxImages
                ? null
                : _showImageSourceDialog,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add Images'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: _selectedImages.length >= _maxImages
                    ? Colors.grey[300]!
                    : const Color(0xFF003366),
              ),
            ),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Selected Images',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(_selectedImages[index].path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Images'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF003366)),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF003366),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.collections, color: Color(0xFFFFD700)),
              title: const Text('Choose Multiple'),
              onTap: () {
                Navigator.pop(context);
                _pickMultipleImages();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext c, String t) => Text(
    t,
    style: Theme.of(c).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(c).primaryColor,
    ),
  );
}

//v1
// import 'package:flutter/material.dart';
// import 'package:flutter_form_builder/flutter_form_builder.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io';
// import 'e_docket_model.dart';
// import 'e_docket_service.dart';
//
// class EDocketPage extends StatefulWidget {
//   const EDocketPage({super.key});
//
//   @override
//   State<EDocketPage> createState() => _EDocketPageState();
// }
//
// class _EDocketPageState extends State<EDocketPage> {
//   final _formKey = GlobalKey<FormBuilderState>();
//   final _imagePicker = ImagePicker();
//
//   final Set<int> _selectedErrorIndices = {};
//   bool _isOtherErrorSelected = false;
//   bool _isSubmitting = false;
//   late DateTime _currentDateTime;
//   bool _isManualDateTime = false;
//   String _otherErrorText = ''; // Store the "Other" error text
//
//   // Image handling
//   final List<XFile> _selectedImages = [];
//   final int _maxImages = 5;
//
//   final List<String> _errorOptions = const [
//     'The meter is not reachable.',
//     'The meter is locked',
//     'The meter cannot be read',
//     'The meter is fast/slow/broken.',
//     'No information on meter shifting',
//     'No entry allowed',
//     'The location cannot be found',
//     'The seal is broken.',
//     'The payment method is incorrect.',
//     'Disconnected.',
//     'The meter board is broken.',
//     'Suspected of stealing electricity.',
//     'Link has been removed',
//     'Bill refused to be accepted.',
//     'Pole bent/ broken',
//     'A hanging "D"',
//     'New supply. No details.',
//     'Cable has come off the hook.',
//     'Route not revealed.',
//     'Service/wire down.',
//     'No safety clearance.',
//     'Wires under high tension.',
//     'Closed for the third time.',
//     'Home is abandoned.',
//     'Circuit breaker missing/broken.',
//     'Unauthorized extension.',
//     'Other',
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _currentDateTime = DateTime.now();
//   }
//
//   Future<void> _submitForm() async {
//     final state = _formKey.currentState;
//     if (state == null) return;
//
//     state.save();
//     if (!state.validate()) return;
//
//     setState(() => _isSubmitting = true);
//
//     try {
//       final values = state.value;
//
//       // Generate a unique docket number with timestamp
//       final timestamp = DateTime.now().millisecondsSinceEpoch;
//       final docketNumber = 'DKT-$timestamp';
//
//       final model = EDocket(
//         docketNo: docketNumber,
//         year: DateTime.now().year.toString(),
//         accountNumber: (values['accountNumber'] as String?)?.trim(),
//         customerName: (values['customerName'] as String).trim(),
//         address: (values['address'] as String?)?.trim(),
//         meterNumber: (values['meterNumber'] as String?)?.trim(),
//         meterReading: (values['meterReading'] as String?)?.trim(),
//         date: DateTime.now(), // Auto-capture current date and time
//         poleNumber: (values['poleNumber'] as String?)?.trim(),
//         selectedErrorIndex: _selectedErrorIndices.isNotEmpty
//             ? _selectedErrorIndices.first
//             : null,
//       );
//
//       final service = EDocketService(baseUrl: 'https://your.api.base.url');
//       final response = await service.submitEDocket(model);
//
//       if (!mounted) return;
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('E-Docket submitted successfully'),
//             backgroundColor: Colors.green,
//             duration: Duration(seconds: 2),
//           ),
//         );
//         Navigator.of(context).pop();
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Submit failed: ${response.statusCode}'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isSubmitting = false);
//       }
//     }
//   }
//
//   void _resetForm() {
//     _formKey.currentState?.reset();
//     setState(() {
//       _selectedErrorIndices.clear();
//       _isOtherErrorSelected = false;
//       _otherErrorText = '';
//       _currentDateTime = DateTime.now(); // Update to current time on reset
//       _isManualDateTime = false;
//       _selectedImages.clear();
//     });
//   }
//
//   Future<void> _pickImage(ImageSource source) async {
//     try {
//       if (_selectedImages.length >= _maxImages) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Maximum $_maxImages images allowed'),
//             backgroundColor: Colors.orange,
//           ),
//         );
//         return;
//       }
//
//       final XFile? image = await _imagePicker.pickImage(
//         source: source,
//         imageQuality: 70,
//         maxWidth: 1920,
//         maxHeight: 1080,
//       );
//
//       if (image != null) {
//         setState(() {
//           _selectedImages.add(image);
//         });
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error picking image: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   Future<void> _pickMultipleImages() async {
//     try {
//       if (_selectedImages.length >= _maxImages) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Maximum $_maxImages images allowed'),
//             backgroundColor: Colors.orange,
//           ),
//         );
//         return;
//       }
//
//       final List<XFile> images = await _imagePicker.pickMultiImage(
//         imageQuality: 70,
//         maxWidth: 1920,
//         maxHeight: 1080,
//       );
//
//       if (images.isNotEmpty) {
//         final remainingSlots = _maxImages - _selectedImages.length;
//         setState(() {
//           _selectedImages.addAll(images.take(remainingSlots));
//         });
//
//         if (images.length > remainingSlots) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'Only first $remainingSlots images were added (max $_maxImages total)',
//               ),
//               backgroundColor: Colors.orange,
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error picking images: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   void _removeImage(int index) {
//     setState(() {
//       _selectedImages.removeAt(index);
//     });
//   }
//
//   void _showImageSourceDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Add Images'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.camera_alt, color: Color(0xFF003366)),
//                 title: const Text('Take Photo'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _pickImage(ImageSource.camera);
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(
//                   Icons.photo_library,
//                   color: Color(0xFF003366),
//                 ),
//                 title: const Text('Choose from Gallery'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _pickImage(ImageSource.gallery);
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(
//                   Icons.photo_library,
//                   color: Color(0xFFFFD700),
//                 ),
//                 title: const Text('Choose Multiple'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _pickMultipleImages();
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   String? _validateRequired(String? value, String fieldName) {
//     if (value == null || value.trim().isEmpty) {
//       return '$fieldName is required';
//     }
//     return null;
//   }
//
//   String _formatDateTime(DateTime dateTime) {
//     // Format: Dec 25, 2024 at 2:30 PM
//     final months = [
//       'Jan',
//       'Feb',
//       'Mar',
//       'Apr',
//       'May',
//       'Jun',
//       'Jul',
//       'Aug',
//       'Sep',
//       'Oct',
//       'Nov',
//       'Dec',
//     ];
//
//     final month = months[dateTime.month - 1];
//     final day = dateTime.day;
//     final year = dateTime.year;
//
//     final hour = dateTime.hour > 12
//         ? dateTime.hour - 12
//         : (dateTime.hour == 0 ? 12 : dateTime.hour);
//     final minute = dateTime.minute.toString().padLeft(2, '0');
//     final period = dateTime.hour >= 12 ? 'PM' : 'AM';
//
//     return '$month $day, $year at $hour:$minute $period';
//   }
//
//   Future<void> _showOtherErrorDialog() async {
//     final TextEditingController otherErrorController = TextEditingController(
//       text: _otherErrorText,
//     );
//
//     final result = await showDialog<String>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Specify Other Error'),
//           content: TextField(
//             controller: otherErrorController,
//             decoration: const InputDecoration(
//               labelText: 'Enter error description',
//               hintText: 'Type the error details here...',
//               border: OutlineInputBorder(),
//             ),
//             maxLines: 3,
//             autofocus: true,
//             textCapitalization: TextCapitalization.sentences,
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context, null),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 final text = otherErrorController.text.trim();
//                 Navigator.pop(context, text);
//               },
//               child: const Text('OK'),
//             ),
//           ],
//         );
//       },
//     );
//
//     if (result != null) {
//       setState(() {
//         _otherErrorText = result;
//       });
//       // Update the otherError field with the entered text
//       _formKey.currentState?.fields['otherError']?.didChange(result);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('E-Docket'), elevation: 2),
//       body: SafeArea(
//         child: FormBuilder(
//           key: _formKey,
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 // Account Number - First Field
//                 _buildSectionTitle('Account Information'),
//                 const SizedBox(height: 12),
//                 FormBuilderTextField(
//                   name: 'accountNumber',
//                   decoration: _buildInputDecoration(
//                     label: 'Account Number',
//                     icon: Icons.account_circle,
//                   ),
//                   validator: (value) =>
//                       _validateRequired(value, 'Account number'),
//                   textInputAction: TextInputAction.next,
//                 ),
//
//                 const SizedBox(height: 12),
//                 // Date and Time Display/Selector
//                 Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: _isManualDateTime
//                         ? Colors.orange.shade50
//                         : Colors.blue.shade50,
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(
//                       color: _isManualDateTime
//                           ? Colors.orange.shade200
//                           : Colors.blue.shade200,
//                     ),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Icon(
//                             Icons.access_time,
//                             color: _isManualDateTime
//                                 ? Colors.orange.shade700
//                                 : Colors.blue.shade700,
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   'Date & Time',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.grey.shade700,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   _formatDateTime(_currentDateTime),
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     color: _isManualDateTime
//                                         ? Colors.orange.shade900
//                                         : Colors.blue.shade900,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 12,
//                               vertical: 6,
//                             ),
//                             decoration: BoxDecoration(
//                               color: _isManualDateTime
//                                   ? Colors.orange.shade100
//                                   : Colors.green.shade100,
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             child: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Icon(
//                                   _isManualDateTime
//                                       ? Icons.edit
//                                       : Icons.check_circle,
//                                   size: 16,
//                                   color: _isManualDateTime
//                                       ? Colors.orange.shade700
//                                       : Colors.green.shade700,
//                                 ),
//                                 const SizedBox(width: 4),
//                                 Text(
//                                   _isManualDateTime ? 'Manual' : 'Auto',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: _isManualDateTime
//                                         ? Colors.orange.shade700
//                                         : Colors.green.shade700,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 12),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: OutlinedButton.icon(
//                               onPressed: () async {
//                                 final pickedDate = await showDatePicker(
//                                   context: context,
//                                   initialDate: _currentDateTime,
//                                   firstDate: DateTime(2000),
//                                   lastDate: DateTime(2100),
//                                 );
//                                 if (pickedDate != null) {
//                                   setState(() {
//                                     _currentDateTime = DateTime(
//                                       pickedDate.year,
//                                       pickedDate.month,
//                                       pickedDate.day,
//                                       _currentDateTime.hour,
//                                       _currentDateTime.minute,
//                                     );
//                                     _isManualDateTime = true;
//                                   });
//                                 }
//                               },
//                               icon: const Icon(Icons.calendar_today, size: 18),
//                               label: const Text('Change Date'),
//                               style: OutlinedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 12,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: OutlinedButton.icon(
//                               onPressed: () async {
//                                 final pickedTime = await showTimePicker(
//                                   context: context,
//                                   initialTime: TimeOfDay.fromDateTime(
//                                     _currentDateTime,
//                                   ),
//                                   initialEntryMode: TimePickerEntryMode.input,
//                                 );
//                                 if (pickedTime != null) {
//                                   setState(() {
//                                     _currentDateTime = DateTime(
//                                       _currentDateTime.year,
//                                       _currentDateTime.month,
//                                       _currentDateTime.day,
//                                       pickedTime.hour,
//                                       pickedTime.minute,
//                                     );
//                                     _isManualDateTime = true;
//                                   });
//                                 }
//                               },
//                               icon: const Icon(Icons.schedule, size: 18),
//                               label: const Text('Change Time'),
//                               style: OutlinedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 12,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       if (_isManualDateTime) ...[
//                         const SizedBox(height: 8),
//                         Center(
//                           child: TextButton.icon(
//                             onPressed: () {
//                               setState(() {
//                                 _currentDateTime = DateTime.now();
//                                 _isManualDateTime = false;
//                               });
//                             },
//                             icon: const Icon(Icons.refresh, size: 18),
//                             label: const Text('Reset to Current Time'),
//                             style: TextButton.styleFrom(
//                               foregroundColor: Colors.blue.shade700,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//
//                 const SizedBox(height: 24),
//                 _buildSectionTitle('Customer Details'),
//                 const SizedBox(height: 12),
//
//                 FormBuilderTextField(
//                   name: 'customerName',
//                   decoration: _buildInputDecoration(
//                     label: 'Customer Name',
//                     icon: Icons.person,
//                   ),
//                   validator: (value) =>
//                       _validateRequired(value, 'Customer name'),
//                   textInputAction: TextInputAction.next,
//                 ),
//
//                 const SizedBox(height: 12),
//                 FormBuilderTextField(
//                   name: 'address',
//                   decoration: _buildInputDecoration(
//                     label: 'Customer Address/Location Detail',
//                     icon: Icons.location_on,
//                   ),
//                   maxLines: 2,
//                   textInputAction: TextInputAction.next,
//                 ),
//
//                 const SizedBox(height: 24),
//                 _buildSectionTitle('Meter Information'),
//                 const SizedBox(height: 12),
//
//                 FormBuilderTextField(
//                   name: 'meterNumber',
//                   decoration: _buildInputDecoration(
//                     label: 'Meter Number',
//                     icon: Icons.speed,
//                   ),
//                   textInputAction: TextInputAction.next,
//                 ),
//
//                 const SizedBox(height: 12),
//                 FormBuilderTextField(
//                   name: 'meterReading',
//                   decoration: _buildInputDecoration(
//                     label: 'Meter Reading',
//                     icon: Icons.analytics,
//                   ),
//                   keyboardType: TextInputType.number,
//                   textInputAction: TextInputAction.next,
//                 ),
//
//                 const SizedBox(height: 12),
//                 FormBuilderTextField(
//                   name: 'poleNumber',
//                   decoration: _buildInputDecoration(
//                     label: 'Pole Number',
//                     icon: Icons.cell_tower,
//                   ),
//                   textInputAction: TextInputAction.next,
//                 ),
//
//                 const SizedBox(height: 24),
//                 _buildSectionTitle('Error Information'),
//                 const SizedBox(height: 12),
//
//                 // Multi-select dropdown with checkboxes
//                 InkWell(
//                   onTap: () async {
//                     await showDialog(
//                       context: context,
//                       builder: (BuildContext context) {
//                         return StatefulBuilder(
//                           builder: (context, setDialogState) {
//                             return AlertDialog(
//                               title: const Text('Select Error Type(s)'),
//                               content: SizedBox(
//                                 width: double.maxFinite,
//                                 child: ListView.builder(
//                                   shrinkWrap: true,
//                                   itemCount: _errorOptions.length,
//                                   itemBuilder: (context, index) {
//                                     final isSelected = _selectedErrorIndices
//                                         .contains(index);
//                                     final isOtherOption =
//                                         index == _errorOptions.length - 1;
//
//                                     return CheckboxListTile(
//                                       value: isSelected,
//                                       onChanged: (bool? value) async {
//                                         if (value == true && isOtherOption) {
//                                           // Show popup dialog for "Other" option when checking
//                                           await _showOtherErrorDialog();
//                                         }
//
//                                         setDialogState(() {
//                                           setState(() {
//                                             if (value == true) {
//                                               _selectedErrorIndices.add(index);
//                                             } else {
//                                               _selectedErrorIndices.remove(
//                                                 index,
//                                               );
//                                               // Clear the otherError field if unchecking "Other"
//                                               if (isOtherOption) {
//                                                 _otherErrorText = '';
//                                                 _formKey
//                                                     .currentState
//                                                     ?.fields['otherError']
//                                                     ?.didChange(null);
//                                               }
//                                             }
//                                             _isOtherErrorSelected =
//                                                 _selectedErrorIndices.contains(
//                                                   _errorOptions.length - 1,
//                                                 );
//                                           });
//                                         });
//                                       },
//                                       title: Row(
//                                         children: [
//                                           Expanded(
//                                             child: Text(
//                                               '${index + 1}. ${_errorOptions[index]}',
//                                               style: TextStyle(
//                                                 fontWeight: isSelected
//                                                     ? FontWeight.w600
//                                                     : FontWeight.normal,
//                                               ),
//                                             ),
//                                           ),
//                                           if (isOtherOption && isSelected)
//                                             IconButton(
//                                               icon: Icon(
//                                                 Icons.edit,
//                                                 size: 20,
//                                                 color: Theme.of(
//                                                   context,
//                                                 ).primaryColor,
//                                               ),
//                                               padding: EdgeInsets.zero,
//                                               constraints:
//                                                   const BoxConstraints(),
//                                               onPressed: () async {
//                                                 // Allow editing when "Other" is already selected
//                                                 await _showOtherErrorDialog();
//                                                 setDialogState(() {
//                                                   setState(() {});
//                                                 });
//                                               },
//                                               tooltip: 'Edit other error',
//                                             ),
//                                         ],
//                                       ),
//                                       controlAffinity:
//                                           ListTileControlAffinity.leading,
//                                       activeColor: Theme.of(
//                                         context,
//                                       ).primaryColor,
//                                       dense: true,
//                                     );
//                                   },
//                                 ),
//                               ),
//                               actions: [
//                                 TextButton(
//                                   onPressed: () {
//                                     setState(() {
//                                       _selectedErrorIndices.clear();
//                                       _isOtherErrorSelected = false;
//                                       _otherErrorText = '';
//                                       _formKey
//                                           .currentState
//                                           ?.fields['otherError']
//                                           ?.didChange(null);
//                                     });
//                                     Navigator.pop(context);
//                                   },
//                                   child: const Text('Clear All'),
//                                 ),
//                                 TextButton(
//                                   onPressed: () => Navigator.pop(context),
//                                   child: const Text('Done'),
//                                 ),
//                               ],
//                             );
//                           },
//                         );
//                       },
//                     );
//                   },
//                   child: InputDecorator(
//                     decoration: _buildInputDecoration(
//                       label: 'Select Error Type(s)',
//                       icon: Icons.error_outline,
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Expanded(
//                           child: _selectedErrorIndices.isEmpty
//                               ? const Text(
//                                   'Tap to select error types',
//                                   style: TextStyle(color: Colors.grey),
//                                 )
//                               : Wrap(
//                                   spacing: 4,
//                                   runSpacing: 4,
//                                   children: _selectedErrorIndices.map((index) {
//                                     return Chip(
//                                       label: Text(
//                                         _errorOptions[index].length > 20
//                                             ? '${_errorOptions[index].substring(0, 20)}...'
//                                             : _errorOptions[index],
//                                         style: const TextStyle(fontSize: 11),
//                                       ),
//                                       deleteIcon: const Icon(
//                                         Icons.close,
//                                         size: 16,
//                                       ),
//                                       onDeleted: () {
//                                         setState(() {
//                                           _selectedErrorIndices.remove(index);
//                                           _isOtherErrorSelected =
//                                               _selectedErrorIndices.contains(
//                                                 _errorOptions.length - 1,
//                                               );
//                                           if (!_isOtherErrorSelected) {
//                                             _formKey
//                                                 .currentState
//                                                 ?.fields['otherError']
//                                                 ?.didChange(null);
//                                           }
//                                         });
//                                       },
//                                       materialTapTargetSize:
//                                           MaterialTapTargetSize.shrinkWrap,
//                                       padding: const EdgeInsets.symmetric(
//                                         horizontal: 4,
//                                       ),
//                                     );
//                                   }).toList(),
//                                 ),
//                         ),
//                         Icon(
//                           Icons.arrow_drop_down,
//                           color: Theme.of(context).primaryColor,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//
//                 // Show custom error input when "Other" is selected
//                 if (_isOtherErrorSelected) ...[
//                   const SizedBox(height: 12),
//                   FormBuilderTextField(
//                     name: 'otherError',
//                     initialValue: _otherErrorText,
//                     decoration: _buildInputDecoration(
//                       label: 'Please specify the error',
//                       icon: Icons.edit,
//                     ),
//                     validator: (value) {
//                       if (_isOtherErrorSelected) {
//                         return _validateRequired(value, 'Error description');
//                       }
//                       return null;
//                     },
//                     maxLines: 2,
//                     textInputAction: TextInputAction.next,
//                   ),
//                 ],
//
//                 const SizedBox(height: 24),
//                 _buildSectionTitle('Additional Information'),
//                 const SizedBox(height: 12),
//
//                 FormBuilderTextField(
//                   name: 'remarks',
//                   decoration: _buildInputDecoration(
//                     label: 'Remarks',
//                     icon: Icons.note,
//                   ),
//                   maxLines: 3,
//                   textInputAction: TextInputAction.done,
//                 ),
//
//                 const SizedBox(height: 24),
//                 _buildSectionTitle('Images (Optional)'),
//                 const SizedBox(height: 12),
//
//                 // Image Upload Section
//                 Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.grey[50],
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: Colors.grey[300]!),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       Row(
//                         children: [
//                           const Icon(
//                             Icons.photo_camera,
//                             color: Color(0xFF003366),
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               'Add up to $_maxImages images',
//                               style: TextStyle(
//                                 color: Colors.grey[700],
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 10,
//                               vertical: 4,
//                             ),
//                             decoration: BoxDecoration(
//                               color: _selectedImages.isEmpty
//                                   ? Colors.grey[300]
//                                   : Colors.blue[100],
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Text(
//                               '${_selectedImages.length}/$_maxImages',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                                 color: _selectedImages.isEmpty
//                                     ? Colors.grey[700]
//                                     : Colors.blue[900],
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 12),
//
//                       // Add Image Button
//                       OutlinedButton.icon(
//                         onPressed: _selectedImages.length >= _maxImages
//                             ? null
//                             : _showImageSourceDialog,
//                         icon: const Icon(Icons.add_photo_alternate),
//                         label: const Text('Add Images'),
//                         style: OutlinedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           side: BorderSide(
//                             color: _selectedImages.length >= _maxImages
//                                 ? Colors.grey[300]!
//                                 : const Color(0xFF003366),
//                           ),
//                         ),
//                       ),
//
//                       // Display Selected Images
//                       if (_selectedImages.isNotEmpty) ...[
//                         const SizedBox(height: 16),
//                         const Divider(),
//                         const SizedBox(height: 12),
//                         Text(
//                           'Selected Images',
//                           style: TextStyle(
//                             fontWeight: FontWeight.w600,
//                             color: Colors.grey[700],
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                         GridView.builder(
//                           shrinkWrap: true,
//                           physics: const NeverScrollableScrollPhysics(),
//                           gridDelegate:
//                               const SliverGridDelegateWithFixedCrossAxisCount(
//                                 crossAxisCount: 3,
//                                 crossAxisSpacing: 8,
//                                 mainAxisSpacing: 8,
//                                 childAspectRatio: 1,
//                               ),
//                           itemCount: _selectedImages.length,
//                           itemBuilder: (context, index) {
//                             return Stack(
//                               children: [
//                                 Container(
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(8),
//                                     border: Border.all(
//                                       color: Colors.grey[300]!,
//                                       width: 2,
//                                     ),
//                                   ),
//                                   child: ClipRRect(
//                                     borderRadius: BorderRadius.circular(6),
//                                     child: Image.file(
//                                       File(_selectedImages[index].path),
//                                       fit: BoxFit.cover,
//                                       width: double.infinity,
//                                       height: double.infinity,
//                                     ),
//                                   ),
//                                 ),
//                                 Positioned(
//                                   top: 4,
//                                   right: 4,
//                                   child: GestureDetector(
//                                     onTap: () => _removeImage(index),
//                                     child: Container(
//                                       padding: const EdgeInsets.all(4),
//                                       decoration: BoxDecoration(
//                                         color: Colors.red,
//                                         shape: BoxShape.circle,
//                                         boxShadow: [
//                                           BoxShadow(
//                                             color: Colors.black.withOpacity(
//                                               0.3,
//                                             ),
//                                             blurRadius: 4,
//                                           ),
//                                         ],
//                                       ),
//                                       child: const Icon(
//                                         Icons.close,
//                                         size: 16,
//                                         color: Colors.white,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 // Image number badge
//                                 Positioned(
//                                   bottom: 4,
//                                   left: 4,
//                                   child: Container(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 6,
//                                       vertical: 2,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: Colors.black.withOpacity(0.7),
//                                       borderRadius: BorderRadius.circular(8),
//                                     ),
//                                     child: Text(
//                                       '${index + 1}',
//                                       style: const TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 10,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             );
//                           },
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//
//                 const SizedBox(height: 32),
//
//                 // Action Buttons
//                 Row(
//                   children: [
//                     Expanded(
//                       child: OutlinedButton.icon(
//                         onPressed: _isSubmitting ? null : _resetForm,
//                         icon: const Icon(Icons.refresh),
//                         label: const Text('Reset'),
//                         style: OutlinedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       flex: 2,
//                       child: ElevatedButton.icon(
//                         onPressed: _isSubmitting ? null : _submitForm,
//                         icon: _isSubmitting
//                             ? const SizedBox(
//                                 width: 20,
//                                 height: 20,
//                                 child: CircularProgressIndicator(
//                                   strokeWidth: 2,
//                                   valueColor: AlwaysStoppedAnimation<Color>(
//                                     Colors.white,
//                                   ),
//                                 ),
//                               )
//                             : const Icon(Icons.save),
//                         label: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
//                         style: ElevatedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//
//                 const SizedBox(height: 16),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSectionTitle(String title) {
//     return Text(
//       title,
//       style: Theme.of(context).textTheme.titleMedium?.copyWith(
//         fontWeight: FontWeight.bold,
//         color: Theme.of(context).primaryColor,
//       ),
//     );
//   }
//
//   InputDecoration _buildInputDecoration({
//     required String label,
//     required IconData icon,
//   }) {
//     return InputDecoration(
//       labelText: label,
//       prefixIcon: Icon(icon),
//       border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(color: Colors.grey.shade300),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
//       ),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//     );
//   }
// }
