// lib/pages/viewDockets/showDocketDetailsX.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/docketsX.dart';
import '../../service/dockey_serviceX.dart';
import './updateDockets/httpUpdateDockets.dart';

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

  // All docket images now come from a single subdirectory
  int _dirForType(String type) {
    // No longer using different directories based on type
    return 1; // All docket images are stored in subdirectory 1
  }

  String _imageUrl() {
    final type = widget.docket.docketType;
    final dir = _dirForType(type);
    final file = widget.docket.imageName;
    return 'http://124.43.181.243:8000/api/fetch-testdocket-image/$dir/$file';
  }

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
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh functionality
              setState(() {});
            },
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
      body: Stack(
        children: [
          Column(
            children: [
              // Status bar at top
              Container(
                width: double.infinity,
                color: _getStatusColor(),
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 16,
                ),
                child: Text(
                  'Status: $_statusLabel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
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
              ),
            ],
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
    // Format date for display
    final formatter = DateFormat('MMM dd, yyyy • hh:mm a');
    final uploaded = widget.docket.uploadedTime.isEmpty
        ? 'Not available'
        : formatter.format(DateTime.parse(widget.docket.uploadedTime));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image header
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.05),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image with tap to expand functionality
                  GestureDetector(
                    onTap: () => _showFullScreenImage(context),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          _imageUrl(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  size: 64,
                                  color: _getStatusColor().withOpacity(0.3),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Image not available',
                                  style: TextStyle(
                                    color: _getStatusColor().withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: _getStatusColor(),
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                        // Zoom indicator overlay
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.zoom_out_map,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status overlay on top right
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getStatusColor(),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStatusIcon(), color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon based on status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Docket info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.docket.docketType,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.tag,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ID: ${widget.docket.id}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Uploaded: $uploaded',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSection() {
    // Display docket type without editing capability
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Docket Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.description, color: Colors.grey.shade600, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_docketType, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF003366)),
              const SizedBox(width: 8),
              const Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () {
                  setState(() {}); // Refresh the UI
                },
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Column(
            children: [
              // Card header
              Container(
                width: double.infinity,
                color: Colors.blue.withOpacity(0.1),
                padding: const EdgeInsets.all(12),
                child: const Row(
                  children: [
                    Icon(Icons.badge, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Docket Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              // Card content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: Icons.home_work,
                      label: 'Depot',
                      value: widget.docket.depot,
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.photo,
                      label: 'Image',
                      value: widget.docket.imageName,
                    ),
                    if (widget.docket.docketSerial != null)
                      const SizedBox(height: 16),
                    if (widget.docket.docketSerial != null)
                      _InfoRow(
                        icon: Icons.tag,
                        label: 'Serial',
                        value: widget.docket.docketSerial ?? 'N/A',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.timeline, color: Color(0xFF003366)),
              const SizedBox(width: 8),
              const Text(
                'Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Column(
            children: [
              // Card header
              Container(
                width: double.infinity,
                color: Colors.green.withOpacity(0.1),
                padding: const EdgeInsets.all(12),
                child: const Row(
                  children: [
                    Icon(Icons.history, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Activity History',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              // Timeline items
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimelineItem(
                      icon: Icons.upload,
                      title: 'Uploaded',
                      date: widget.docket.uploadedTime,
                      subtitle: widget.docket.uploadedBy ?? 'Unknown user',
                      isFirst: true,
                      isLast:
                          widget.docket.assignTime == null &&
                          widget.docket.completedTime == null,
                    ),

                    if (widget.docket.assignTime != null)
                      _buildTimelineItem(
                        icon: Icons.assignment_ind,
                        title: 'Assigned',
                        date: widget.docket.assignTime ?? '',
                        subtitle: 'To: ${widget.docket.assignedTo ?? 'N/A'}',
                        isFirst: false,
                        isLast: widget.docket.completedTime == null,
                      ),

                    if (widget.docket.completedTime != null)
                      _buildTimelineItem(
                        icon: Icons.check_circle,
                        title: 'Completed',
                        date: widget.docket.completedTime ?? '',
                        subtitle: 'By: ${widget.docket.assignedTo ?? 'N/A'}',
                        isFirst: false,
                        isLast: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Location Information
        const SizedBox(height: 24),
        if (widget.docket.locationDetails != null ||
            transformerNumber.isNotEmpty ||
            poleNumber.isNotEmpty ||
            meterShiftDetails.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF003366)),
                    const SizedBox(width: 8),
                    const Text(
                      'Location Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003366),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: Column(
                  children: [
                    // Card header
                    Container(
                      width: double.infinity,
                      color: Colors.orange.withOpacity(0.1),
                      padding: const EdgeInsets.all(12),
                      child: const Row(
                        children: [
                          Icon(Icons.pin_drop, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Location Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Location content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.docket.locationDetails != null)
                            _InfoRow(
                              icon: Icons.location_on_outlined,
                              label: 'Full Location',
                              value: widget.docket.locationDetails ?? 'N/A',
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
                    ),
                  ],
                ),
              ),
            ],
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

  /// Show full screen image viewer with zoom capabilities
  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Image View'),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Save image',
                onPressed: () {
                  // Future enhancement: Add image download capability
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Download not implemented yet'),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                _imageUrl(),
                fit: BoxFit.contain,
                loadingBuilder: (_, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.broken_image, color: Colors.white54, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_status) {
      case 0:
        return Icons.hourglass_empty; // Unassigned
      case 1:
        return Icons.person_outline; // Assigned
      case 2:
        return Icons.check_circle_outline; // Completed
      case 3:
        return Icons.loop; // Reassigned
      case 4:
        return Icons.error_outline; // Issue
      default:
        return Icons.help_outline;
    }
  }

  Widget? _buildFAB() {
    return FloatingActionButton.extended(
      backgroundColor: const Color(0xFF003366),
      foregroundColor: Colors.white,
      onPressed: _showActionMenu,
      icon: const Icon(Icons.edit),
      label: const Text('Update'),
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
                leading: const Icon(Icons.category),
                title: const Text('Update Docket Type'),
                onTap: () {
                  Navigator.pop(context);
                  _showDocketTypeUpdateDialog();
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

  void _showDocketTypeUpdateDialog() {
    // Use local variable to track selected type in the dialog
    String selectedType = _docketType;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Docket Type'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select a new docket type:'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  items: _allDocketTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
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
                _updateDocketType(selectedType);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateLocationDetails(String newDetails) async {
    setState(() => _updating = true);

    try {
      // Use DocketUpdateApi instead of _docketService
      final success = await DocketUpdateApi.updateLocationDetails(
        id: widget.docket.id,
        locationDetails: newDetails,
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

  Future<void> _updateDocketType(String newType) async {
    setState(() => _updating = true);

    try {
      final success = await DocketUpdateApi.updateDocketType(
        id: widget.docket.id,
        newType: newType,
      );

      if (success) {
        // Update local state to reflect the change
        setState(() => _docketType = newType);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Docket type updated successfully')),
          );
          // The API doesn't return the updated docket, so navigate back
          // and let the parent page refresh the data
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update docket type')),
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

Widget _buildTimelineItem({
  required IconData icon,
  required String title,
  required String date,
  required String subtitle,
  required bool isFirst,
  required bool isLast,
}) {
  // Format date if possible
  String formattedDate = date;
  if (date.isNotEmpty) {
    try {
      final dateTime = DateTime.parse(date);
      final formatter = DateFormat('MMM dd, yyyy • hh:mm a');
      formattedDate = formatter.format(dateTime);
    } catch (e) {
      // Keep the original if parsing fails
    }
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Timeline line and dot
      SizedBox(
        width: 24,
        child: Column(
          children: [
            if (!isFirst)
              Container(width: 2, height: 16, color: Colors.grey[300]),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isLast ? Colors.green : Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: Colors.grey[300]),
          ],
        ),
      ),
      const SizedBox(width: 16),
      // Content
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              formattedDate,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 14)),
            if (!isLast) const SizedBox(height: 16),
          ],
        ),
      ),
    ],
  );
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
    String displayValue = value;

    // Format date if the value looks like a date
    if (value.contains('T') && value.contains('Z')) {
      try {
        final date = DateTime.parse(value);
        final formatter = DateFormat('MMM dd, yyyy • hh:mm a');
        displayValue = formatter.format(date);
      } catch (e) {
        // If parsing fails, use the original value
        displayValue = value;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(displayValue, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
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
