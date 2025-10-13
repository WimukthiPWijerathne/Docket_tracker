// lib/pages/viewDockets/showDocketDetailsX.dart
import 'package:flutter/material.dart';

import '../../models/docketsX.dart';
import '../../service/dockey_serviceX.dart';

class DocketDetailsXPage extends StatefulWidget {
  final Docket docket;

  const DocketDetailsXPage({super.key, required this.docket});

  @override
  State<DocketDetailsXPage> createState() => _DocketDetailsXPageState();
}

class _DocketDetailsXPageState extends State<DocketDetailsXPage> {
  late String
  _docketType; // local, so we can update UI after a successful change
  bool _updating = false;
  final DocketServiceX _docketService = DocketServiceX();

  // Keep it consistent with your app
  static const List<String> _allDocketTypes = [
    'Service Line Maintenance',
    'Meter Testing',
    'Estimate',
    'Per Visit',
    'Pole Disconnection',
    'Material Remove',
    'Meter Replacement Only',
    'Visit with Contractor',
    'Pole Top Maintenance',
  ];

  /// ---- Status helpers (status is a STRING from DB) ----
  int get _status {
    final s = widget.docket.status.trim();
    return int.tryParse(s) ?? 0;
  }

  String get _statusLabel {
    switch (_status) {
      case 0:
        return 'Unassigned';
      case 1:
        return 'Assigned';
      case 2:
        return 'Completed';
      case 3:
        return 'Reassigned';
      case 4:
        return 'Issue';
      default:
        return 'Unknown';
    }
  }

  @override
  void initState() {
    super.initState();
    _docketType = widget.docket.docketType;
  }

  @override
  Widget build(BuildContext context) {
    // Comment out UserAccess dependency
    // final ua = context.read<UserAccess>();

    // Instead of relying on UserAccess, we'll grant edit access to everyone

    // Parse location details
    String transformerNumber = '';
    String poleNumber = '';
    String meterShiftDetails = '';

    if (widget.docket.locationDetails != null) {
      final details = widget.docket.locationDetails!;

      // Parse in format "Transformer: 1, Pole: e, Meter Shift: t"
      if (details.contains('Transformer:')) {
        transformerNumber = details
            .split('Transformer:')[1]
            .split(',')
            .first
            .trim();
      }

      if (details.contains('Pole:')) {
        poleNumber = details.split('Pole:')[1].split(',').first.trim();
      }

      if (details.contains('Meter Shift:')) {
        meterShiftDetails = details.split('Meter Shift:')[1].trim();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Docket Details'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _buildFAB(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section with ID and status
                _buildHeaderSection(),

                const Divider(height: 32),

                // Type section with dropdown for all users
                _buildTypeSection(),

                const Divider(height: 32),

                // Basic info section
                _buildBasicInfoSection(
                  transformerNumber: transformerNumber,
                  poleNumber: poleNumber,
                  meterShiftDetails: meterShiftDetails,
                ),

                const SizedBox(height: 100), // Bottom padding for FAB
              ],
            ),
          ),
          if (_updating)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ID: ${widget.docket.id}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text('Status: $_statusLabel'),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _statusLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSection() {
    // Grant edit access to all users

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Docket Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _docketType,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
          items: _allDocketTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _docketType = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection({
    required String transformerNumber,
    required String poleNumber,
    required String meterShiftDetails,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Basic Information',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.home_work,
                  label: 'Depot',
                  value: widget.docket.depot,
                ),
                const Divider(height: 24),
                _InfoRow(
                  icon: Icons.photo,
                  label: 'Image',
                  value: widget.docket.imageName,
                ),
                if (widget.docket.docketSerial != null)
                  Column(
                    children: [
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.tag,
                        label: 'Serial',
                        value: widget.docket.docketSerial ?? 'N/A',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Timeline',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.upload,
                  label: 'Uploaded',
                  value: widget.docket.uploadedTime,
                ),
                if (widget.docket.uploadedBy != null)
                  Column(
                    children: [
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'By',
                        value: widget.docket.uploadedBy ?? 'N/A',
                      ),
                    ],
                  ),
                if (widget.docket.assignedTo != null)
                  Column(
                    children: [
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.assignment_ind_outlined,
                        label: 'Assigned To',
                        value: widget.docket.assignedTo ?? 'N/A',
                      ),
                    ],
                  ),
                if (widget.docket.assignTime != null)
                  Column(
                    children: [
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.schedule,
                        label: 'Assigned At',
                        value: widget.docket.assignTime ?? 'N/A',
                      ),
                    ],
                  ),
                if (widget.docket.completedTime != null)
                  Column(
                    children: [
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.check_circle_outline,
                        label: 'Completed',
                        value: widget.docket.completedTime ?? 'N/A',
                      ),
                    ],
                  ),
                if (widget.docket.locationDetails != null)
                  Column(
                    children: [
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value: widget.docket.locationDetails ?? 'N/A',
                      ),
                    ],
                  ),
                if (transformerNumber.isNotEmpty ||
                    poleNumber.isNotEmpty ||
                    meterShiftDetails.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 24),
                      const Text(
                        'Location Details',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (transformerNumber.isNotEmpty)
                        _ChipInfo(
                          icon: Icons.electric_bolt,
                          label: 'Transformer',
                          value: transformerNumber,
                        ),
                      if (poleNumber.isNotEmpty)
                        _ChipInfo(
                          icon: Icons.lightbulb_outline,
                          label: 'Pole',
                          value: poleNumber,
                        ),
                      if (meterShiftDetails.isNotEmpty)
                        _ChipInfo(
                          icon: Icons.speed,
                          label: 'Meter Shift',
                          value: meterShiftDetails,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (_status) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget? _buildFAB() {
    // Grant edit access to all users
    final canEdit = true;

    if (!canEdit) return null;

    return FloatingActionButton(
      backgroundColor: const Color(0xFF003366),
      foregroundColor: Colors.white,
      onPressed: _showActionMenu,
      child: const Icon(Icons.edit),
    );
  }

  void _showActionMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Update Docket',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.update),
                title: const Text('Update Status'),
                onTap: () {
                  Navigator.pop(context);
                  _showStatusUpdateDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Update Location Details'),
                onTap: () {
                  Navigator.pop(context);
                  _showLocationUpdateDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusUpdateDialog() {
    int selectedStatus = _status;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 5; i++)
                RadioListTile<int>(
                  title: Text(
                    [
                      'Unassigned',
                      'Assigned',
                      'Completed',
                      'Reassigned',
                      'Issue',
                    ][i],
                  ),
                  value: i,
                  groupValue: selectedStatus,
                  onChanged: (value) {
                    setDialogState(() => selectedStatus = value!);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(selectedStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showLocationUpdateDialog() {
    final transformerController = TextEditingController();
    final poleController = TextEditingController();
    final meterShiftController = TextEditingController();

    // Pre-populate from existing data if available
    if (widget.docket.locationDetails != null) {
      final details = widget.docket.locationDetails!;

      if (details.contains('Transformer:')) {
        transformerController.text = details
            .split('Transformer:')[1]
            .split(',')
            .first
            .trim();
      }

      if (details.contains('Pole:')) {
        poleController.text = details.split('Pole:')[1].split(',').first.trim();
      }

      if (details.contains('Meter Shift:')) {
        meterShiftController.text = details.split('Meter Shift:')[1].trim();
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Location Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: transformerController,
                decoration: const InputDecoration(
                  labelText: 'Transformer Number',
                ),
              ),
              TextField(
                controller: poleController,
                decoration: const InputDecoration(labelText: 'Pole Number'),
              ),
              TextField(
                controller: meterShiftController,
                decoration: const InputDecoration(
                  labelText: 'Meter Shift Details',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Format the location details
              final locationDetails =
                  'Transformer: ${transformerController.text}, '
                  'Pole: ${poleController.text}, '
                  'Meter Shift: ${meterShiftController.text}';
              _updateLocationDetails(locationDetails);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(int newStatus) async {
    setState(() => _updating = true);

    try {
      final success = await _docketService.updateDocketStatus(
        widget.docket.id,
        newStatus.toString(),
      );

      if (success) {
        // The API doesn't return the updated docket, so navigate back
        // and let the parent page refresh the data
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update status')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _updateLocationDetails(String newDetails) async {
    setState(() => _updating = true);

    try {
      final success = await _docketService.updateLocationDetails(
        widget.docket.id,
        newDetails,
      );

      if (success) {
        // The API doesn't return the updated docket, so navigate back
        // and let the parent page refresh the data
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update location details')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChipInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ChipInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text('$label: $value'),
        backgroundColor: Colors.grey[200],
      ),
    );
  }
}
