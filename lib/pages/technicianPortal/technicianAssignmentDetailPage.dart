import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:leco_docket_tracker/pages/technicianPortal/widgets/kvRow.dart';
import 'package:leco_docket_tracker/pages/technicianPortal/widgets/photoGrid.dart';
import 'package:leco_docket_tracker/pages/technicianPortal/services/workLogService.dart';

import '../../models/WorkPhoto.dart';
import '../../models/dockets.dart';
import '../../models/docketAssignment.dart' as models;
import '../../models/WorkLog.dart';

import '../viewDockets/updateDockets/httpUpdateDockets.dart';

class AssignmentDetailPage extends StatefulWidget {
  final Docket docket;
  final models.DocketAssignment assignment;
  final String employeeNo;
  final Future<void> Function()? onChanged;

  const AssignmentDetailPage({
    super.key,
    required this.docket,
    required this.assignment,
    required this.employeeNo,
    this.onChanged,
  });

  @override
  State<AssignmentDetailPage> createState() => _AssignmentDetailPageState();
}

class _AssignmentDetailPageState extends State<AssignmentDetailPage> {
  final _picker = ImagePicker();
  final _notesController = TextEditingController();

  // Core state
  WorkLog? _workLog;
  bool _loading = true;
  bool _saving = false;

  // Photos
  final List<WorkPhoto> _beforePhotos = [];
  final List<WorkPhoto> _afterPhotos = [];
  final List<WorkPhoto> _extraPhotos = [];

  // Computed workflow states based on database
  bool get _isAcknowledged => _workLog?.acknowledgedAt != null;
  bool get _isAttending => _workLog?.attendingAt != null;
  bool get _isStarted => _workLog?.startedAt != null;
  bool get _isCompleted => _workLog?.completedAt != null;

  // UI state helpers
  bool get _canAttend => _isAcknowledged && !_isAttending;
  bool get _canStartWork => _isAttending && !_isStarted;

  // Test: Acknowledge → Attend → BEFORE photos → Auto start → AFTER photos → Complete
  // Photo-related getters - Attendance tracking workflow
  bool get _canTakeBeforePhotos =>
      _isAttending && !_isCompleted; // Unlocked after attending
  bool get _canTakeAfterPhotos =>
      _isStarted &&
      _beforePhotos.isNotEmpty &&
      !_isCompleted; // AFTER photos unlock only when work started AND BEFORE photos exist
  bool get _canTakeExtraPhotos =>
      _isAttending &&
      !_isCompleted; // EXTRA photos available throughout process after attending
  bool get _canComplete =>
      _isStarted &&
      _beforePhotos.isNotEmpty &&
      _afterPhotos.isNotEmpty &&
      !_isCompleted;

  String _now() => DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    print('DEBUG: initState() called');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      // Only load once
      print(
        'DEBUG: didChangeDependencies() called - About to call _loadWorkLog()',
      );
      _loadWorkLog().catchError((error) {
        print(
          'DEBUG: Error in _loadWorkLog from didChangeDependencies: $error',
        );
        if (mounted) {
          setState(() => _loading = false);
          _showError('Failed to initialize: $error');
        }
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Load existing work log or create new one
  Future<void> _loadWorkLog() async {
    print('DEBUG: _loadWorkLog() START');
    setState(() => _loading = true);
    try {
      print('DEBUG: Loading work log...');
      print('DEBUG: assignmentId: ${widget.assignment.docketId}');
      print('DEBUG: docketId: ${widget.docket.id}');
      print('DEBUG: employeeNo: "${widget.employeeNo}"');

      // CRITICAL: Check if employee number is provided
      if (widget.employeeNo.isEmpty) {
        print('DEBUG: Employee number is empty, showing error');
        setState(() => _loading = false);

        // Schedule the error message to be shown after the build completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showError('Employee number is missing. Please log in again.');
          }
        });
        return;
      }

      print('DEBUG: About to call WorkLogService.getWorkLogs...');
      // Try to get existing work log
      final existingLogs = await WorkLogService.getWorkLogs(
        assignmentId: widget.assignment.docketId,
        docketId: '${widget.docket.id}',
        employeeNo: widget.employeeNo,
      );

      print('DEBUG: Found ${existingLogs.length} existing work logs');

      // Log all found work logs for debugging
      for (int i = 0; i < existingLogs.length; i++) {
        print('DEBUG: Work log $i: ${existingLogs[i]}');
      }

      if (existingLogs.isNotEmpty) {
        // Use existing work log
        _workLog = existingLogs.first;
        print('DEBUG: Using existing work log: $_workLog');

        // CRITICAL: Validate that the work log matches current assignment
        if (_workLog!.assignmentId != widget.assignment.docketId ||
            _workLog!.docketId != '${widget.docket.id}' ||
            _workLog!.employeeNo != widget.employeeNo) {
          print('DEBUG: WARNING - Work log data mismatch!');
          print(
            'DEBUG: Expected assignmentId: ${widget.assignment.docketId}, got: ${_workLog!.assignmentId}',
          );
          print(
            'DEBUG: Expected docketId: ${widget.docket.id}, got: ${_workLog!.docketId}',
          );
          print(
            'DEBUG: Expected employeeNo: ${widget.employeeNo}, got: ${_workLog!.employeeNo}',
          );
          _showError('Work log data mismatch. Creating new work log...');
          _workLog = null; // Force creation of new work log
        }
      }

      if (_workLog == null) {
        print('DEBUG: Creating new work log...');
        print('DEBUG: About to call WorkLogService.createWorkLog...');
        try {
          // Create new work log
          _workLog = await WorkLogService.createWorkLog(
            assignmentId: widget.assignment.docketId,
            docketId: '${widget.docket.id}',
            employeeNo: widget.employeeNo,
          );
          print('DEBUG: Created new work log: $_workLog');
        } catch (createError) {
          print('DEBUG: Failed to create work log: $createError');
          // Don't throw error here - let user try to acknowledge manually
          print('DEBUG: Will allow manual acknowledgment attempt');
        }
      }

      // Validate work log was created/loaded successfully
      if (_workLog == null) {
        print('DEBUG: _workLog is null - user can try manual acknowledgment');
        // Don't show error or return early - let the user try to acknowledge
      } else if (_workLog!.id.isEmpty) {
        print(
          'DEBUG: _workLog.id is empty - user can try manual acknowledgment',
        );
        // Don't show error or return early - let the user try to acknowledge
      } else {
        print('DEBUG: Work log loaded successfully with ID: ${_workLog!.id}');
      }

      // Load existing photos
      await _loadPhotos();

      // Set notes if available
      if (_workLog?.remarks != null) {
        _notesController.text = _workLog!.remarks!;
      }

      print('DEBUG: _loadWorkLog() completed successfully');
      setState(() => _loading = false);
    } catch (e, stackTrace) {
      print('DEBUG: Exception in _loadWorkLog(): $e');
      print('DEBUG: Stack trace: $stackTrace');
      setState(() => _loading = false);
      _showError('Failed to load work log: $e');
      print('DEBUG: _loadWorkLog() completed with error');
    }
  }

  /// Load photos from server
  Future<void> _loadPhotos() async {
    if (_workLog?.id == null) {
      print('DEBUG: Cannot load photos - workLog.id is null');
      return;
    }

    try {
      print('DEBUG: Loading photos for workLogId: ${_workLog!.id}');

      final beforePhotos = await WorkLogService.getWorkPhotosByKind(
        workLogId: _workLog!.id!,
        kind: PhotoKind.before,
      );
      final afterPhotos = await WorkLogService.getWorkPhotosByKind(
        workLogId: _workLog!.id!,
        kind: PhotoKind.after,
      );
      final extraPhotos = await WorkLogService.getWorkPhotosByKind(
        workLogId: _workLog!.id!,
        kind: PhotoKind.extra,
      );

      print('DEBUG: Loaded ${beforePhotos.length} before photos');
      print('DEBUG: Loaded ${afterPhotos.length} after photos');
      print('DEBUG: Loaded ${extraPhotos.length} extra photos');

      // Debug: Print details of loaded photos
      for (var photo in beforePhotos) {
        print(
          'DEBUG: BEFORE photo - ID: ${photo.id}, ImageName: ${photo.imageName}, Kind: ${photo.kind}',
        );
      }
      for (var photo in afterPhotos) {
        print(
          'DEBUG: AFTER photo - ID: ${photo.id}, ImageName: ${photo.imageName}, Kind: ${photo.kind}',
        );
      }
      for (var photo in extraPhotos) {
        print(
          'DEBUG: EXTRA photo - ID: ${photo.id}, ImageName: ${photo.imageName}, Kind: ${photo.kind}',
        );
      }

      _beforePhotos
        ..clear()
        ..addAll(beforePhotos);
      _afterPhotos
        ..clear()
        ..addAll(afterPhotos);
      _extraPhotos
        ..clear()
        ..addAll(extraPhotos);

      print('DEBUG: Photo loading completed successfully');
    } catch (e) {
      print('DEBUG: Error loading photos: $e');
      _showError('Failed to load photos: $e');
    }
  }

  /// Mark as acknowledged
  Future<void> _markAcknowledged() async {
    print('DEBUG: _markAcknowledged called');
    print('DEBUG: _isAcknowledged = $_isAcknowledged');
    print('DEBUG: _workLog?.id = ${_workLog?.id}');
    print('DEBUG: _workLog = $_workLog');
    print('DEBUG: _saving = $_saving');

    if (_saving) {
      print('DEBUG: Already saving, ignoring acknowledge request');
      return;
    }

    if (_isAcknowledged) {
      _showError('Assignment is already acknowledged');
      return;
    }

    // Additional validation
    if (widget.employeeNo.isEmpty) {
      _showError('Employee number is missing. Please log in again.');
      return;
    }

    setState(() => _saving = true);
    try {
      // If work log doesn't exist or has empty ID, create a new one with acknowledgment
      if (_workLog == null || _workLog!.id.isEmpty) {
        print('DEBUG: Creating new work log with acknowledgment');
        print('DEBUG: acknowledgedAt: ${_now()}');
        print('DEBUG: Current employee: ${widget.employeeNo}');

        _workLog = await WorkLogService.createWorkLog(
          assignmentId: widget.assignment.docketId,
          docketId: '${widget.docket.id}',
          employeeNo: widget.employeeNo,
          acknowledgedAt: _now(), // Set acknowledgment time during creation
        );

        print('DEBUG: Created new work log with acknowledgment: $_workLog');
      } else {
        // Update existing work log with acknowledgment
        print(
          'DEBUG: Updating existing work log with workLogId: ${_workLog!.id}',
        );
        print('DEBUG: acknowledgedAt: ${_now()}');
        print('DEBUG: Current employee: ${widget.employeeNo}');

        _workLog = await WorkLogService.updateWorkLog(
          workLogId: _workLog!.id,
          acknowledgedAt: _now(),
        );

        print('DEBUG: Updated existing work log: $_workLog');
      }

      print('DEBUG: Final workLog: $_workLog');
      print('DEBUG: New acknowledgedAt: ${_workLog?.acknowledgedAt}');
      print(
        'DEBUG: _isAcknowledged after update: ${_workLog?.acknowledgedAt != null}',
      );

      setState(() {});
      _showSuccess('Assignment acknowledged successfully!');
    } catch (e) {
      print('DEBUG: Error in _markAcknowledged: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      _showError('Failed to acknowledge: $e');
    } finally {
      setState(() => _saving = false);
      print('DEBUG: _markAcknowledged completed, _saving = $_saving');
    }
  }

  /// Mark as attending
  Future<void> _markAttending() async {
    if (_isAttending || _workLog?.id == null) return;

    setState(() => _saving = true);
    try {
      _workLog = await WorkLogService.updateWorkLog(
        workLogId: _workLog!.id!,
        attendingAt: _now(),
      );
      setState(() {});
      _showSuccess('Marked as attending - You can now take photos!');
    } catch (e) {
      _showError('Failed to mark attending: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  /// Start work (automatically called when first BEFORE photo is taken)
  Future<void> _markStarted() async {
    if (_isStarted || _workLog?.id == null) return;

    try {
      _workLog = await WorkLogService.updateWorkLog(
        workLogId: _workLog!.id!,
        startedAt: _now(),
      );
      setState(() {});
    } catch (e) {
      _showError('Failed to mark as started: $e');
    }
  }

  /// Add photo
  Future<void> _addPhoto(PhotoKind kind) async {
    if (_workLog?.id == null) return;

    // Check permissions
    if (kind == PhotoKind.before && !_canTakeBeforePhotos) {
      _showError('You must mark as attending first');
      return;
    }
    if (kind == PhotoKind.after && !_canTakeAfterPhotos) {
      _showError('You must start work (take BEFORE photos) first');
      return;
    }
    if (kind == PhotoKind.extra && !_canTakeExtraPhotos) {
      _showError('You must mark as attending first');
      return;
    }

    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice:
          CameraDevice.rear, // Use rear camera for work photos
    );
    if (image == null) return;

    setState(() => _saving = true);
    try {
      final sequence = _getNextSequence(kind);
      final caption = _generateCaption(kind);

      final workPhoto = await WorkLogService.uploadWorkPhotoWithKind(
        workLogId: _workLog!.id!,
        kind: kind,
        filePath: image.path,
        sequence: sequence,
        caption: caption,
        uploadedBy: widget.employeeNo,
      );

      // Print uploaded photo details to console
      print('=== PHOTO UPLOADED & SAVED TO DATABASE ===');
      print('Photo ID (Database): ${workPhoto.id}');
      print('Image Name: ${workPhoto.imageName}');
      final subdirectory = kind == PhotoKind.before
          ? 1
          : (kind == PhotoKind.after ? 2 : 3);
      final cleanName = workPhoto.imageName.endsWith('.jpg')
          ? workPhoto.imageName.substring(0, workPhoto.imageName.length - 4)
          : workPhoto.imageName;
      print(
        'Full Photo URL: http://124.43.136.185:8000/api/fetch-testdocket-image/$subdirectory/$cleanName.jpg',
      );
      print('Photo Kind: ${kind.toString()}');
      print('Caption: $caption');
      print('Sequence: $sequence');
      print('Work Log ID: ${workPhoto.workLogId}');
      print('Uploaded By: ${workPhoto.uploadedBy}');
      print('Uploaded At: ${workPhoto.uploadedAt}');
      print('Status: ✅ File uploaded to storage & metadata saved to database');
      print('=============================================');

      // Add to appropriate list
      bool autoStarted = false;
      switch (kind) {
        case PhotoKind.before:
          _beforePhotos.add(workPhoto);
          // Auto start work when first BEFORE photo uploaded successfully
          if (!_isStarted) {
            await _markStarted();
            autoStarted = true;
          }
          break;
        case PhotoKind.after:
          _afterPhotos.add(workPhoto);
          break;
        case PhotoKind.extra:
          _extraPhotos.add(workPhoto);
          break;
      }

      setState(() {});
      // Different success messages for auto work start vs normal upload
      if (kind == PhotoKind.before && autoStarted) {
        _showSuccess('BEFORE photo uploaded - Work started automatically!');
      } else {
        _showSuccess('Photo uploaded successfully');
      }
    } catch (e) {
      _showError('Failed to upload photo: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  /// Mark as complete
  Future<void> _markComplete() async {
    if (!_canComplete || _workLog?.id == null) return;

    setState(() => _saving = true);
    try {
      final nowStr = _now();

      // 1) Mark WorkLog as completed
      _workLog = await WorkLogService.updateWorkLog(
        workLogId: _workLog!.id!,
        completedAt: nowStr,
        remarks: _notesController.text.trim(),
      );

      // 2) Update Docket row
      final docketUpdated = await DocketUpdateApi.updateFields(
        id: widget.docket.id,
        fields: {
          'AssignedTime': '2', // Mark as completed
          'completedTime': nowStr,
        },
      );

      if (docketUpdated) {
        if (widget.onChanged != null) await widget.onChanged!();
        _showSuccess('Assignment completed successfully!');

        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        _showError('Failed to update docket status');
      }
    } catch (e) {
      _showError('Failed to complete assignment: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  /// Save notes
  Future<void> _saveNotes() async {
    if (_workLog?.id == null) return;

    try {
      await WorkLogService.updateWorkLog(
        workLogId: _workLog!.id!,
        remarks: _notesController.text.trim(),
      );
      _showSuccess('Notes saved');
    } catch (e) {
      _showError('Failed to save notes: $e');
    }
  }

  /// Helper methods for photos
  int _getNextSequence(PhotoKind kind) {
    switch (kind) {
      case PhotoKind.before:
        return _beforePhotos.length + 1;
      case PhotoKind.after:
        return _afterPhotos.length + 1;
      case PhotoKind.extra:
        return _extraPhotos.length + 1;
    }
  }

  String _generateCaption(PhotoKind kind) {
    final serial = widget.docket.docketSerial;
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    switch (kind) {
      case PhotoKind.before:
        return 'BEFORE_${serial}_${formattedDate}';
      case PhotoKind.after:
        return 'AFTER_${serial}_${formattedDate}';
      case PhotoKind.extra:
        return 'EXTRA_${serial}_${formattedDate}';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatNullableString(String? value) {
    return (value == null || value.isEmpty || value.toUpperCase() == 'NULL')
        ? '-'
        : value;
  }

  @override
  Widget build(BuildContext context) {
    final docket = widget.docket;
    final assignment = widget.assignment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Details'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Docket Info
                  _buildDocketInfo(docket, assignment),
                  const Divider(height: 32),

                  // Progress Status
                  _buildProgressStatus(),
                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButtons(),
                  const SizedBox(height: 32),

                  // Photo Sections
                  _buildPhotoSection(
                    'Before Photos',
                    _beforePhotos,
                    PhotoKind.before,
                    _canTakeBeforePhotos,
                    'Add BEFORE Photo',
                    Icons.add_a_photo,
                  ),
                  const SizedBox(height: 24),

                  _buildPhotoSection(
                    'Extra Photos',
                    _extraPhotos,
                    PhotoKind.extra,
                    _canTakeExtraPhotos,
                    'Add EXTRA Photo',
                    Icons.add_photo_alternate,
                  ),
                  const SizedBox(height: 24),

                  _buildPhotoSection(
                    'After Photos',
                    _afterPhotos,
                    PhotoKind.after,
                    _canTakeAfterPhotos,
                    'Add AFTER Photo',
                    Icons.add_a_photo_outlined,
                  ),
                  const SizedBox(height: 32),

                  // Notes Section
                  _buildNotesSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildDocketInfo(Docket docket, models.DocketAssignment assignment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              docket.docketType,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 8),
            Text('Depot: ${docket.depot}  •  Serial: ${docket.docketSerial}'),
            const Divider(height: 20),
            KvRow(label: 'Docket ID', value: assignment.docketId),
            KvRow(label: 'Assigned Persons', value: assignment.assignedPersons),
            KvRow(
              label: 'Assigned Time',
              value: _formatNullableString(assignment.assignedTime),
            ),
            KvRow(label: 'Uploaded By', value: assignment.uploadedBy),
            KvRow(
              label: 'Uploaded Time',
              value: _formatNullableString(assignment.uploadedTime),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                _buildProgressStep(
                  'Acknowledge Assignment',
                  _isAcknowledged,
                  Icons.assignment_turned_in,
                ),
                _buildProgressStep(
                  'Mark as Attending',
                  _isAttending,
                  Icons.location_on,
                ),
                _buildProgressStep('Start Work', _isStarted, Icons.play_arrow),
                _buildProgressStep(
                  'Complete Work',
                  _isCompleted,
                  Icons.done_all,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: (_saving || _isAcknowledged)
                      ? null
                      : _markAcknowledged,
                  icon: const Icon(Icons.done_all),
                  label: Text(
                    _isAcknowledged ? 'Acknowledged ✓' : 'Acknowledge',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAcknowledged ? Colors.green : null,
                    foregroundColor: _isAcknowledged ? Colors.white : null,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: (_saving || !_canAttend) ? null : _markAttending,
                  icon: const Icon(Icons.directions_walk),
                  label: Text(_isAttending ? 'Attending ✓' : 'Mark Attending'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAttending ? Colors.green : null,
                    foregroundColor: _isAttending ? Colors.white : null,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _canComplete ? _markComplete : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(_saving ? 'Completing...' : 'Mark Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCompleted
                        ? Colors.green
                        : (_canComplete ? Colors.orange : null),
                    foregroundColor: (_isCompleted || _canComplete)
                        ? Colors.white
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Photo Section UI
  Widget _buildPhotoSection(
    String title,
    List<WorkPhoto> photos,
    PhotoKind kind,
    bool canTakePhoto,
    String buttonLabel,
    IconData buttonIcon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$title (${photos.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: (_saving || !canTakePhoto)
                      ? null
                      : () => _addPhoto(kind),
                  icon: Icon(buttonIcon),
                  label: Text(buttonLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!canTakePhoto)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getPhotoLockMessage(kind),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              )
            else
              PhotoGrid(images: photos),
          ],
        ),
      ),
    );
  }

  String _getPhotoLockMessage(PhotoKind kind) {
    switch (kind) {
      case PhotoKind.before:
        return 'Mark as attending to unlock BEFORE photos';
      case PhotoKind.after:
        return 'Take BEFORE photos and start work to unlock AFTER photos';
      case PhotoKind.extra:
        return 'Mark as attending to unlock EXTRA photos';
    }
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Technician Notes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Add any notes about this assignment...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saveNotes,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save Notes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Replace status chips with step-by-step progress indicators
  Widget _buildProgressStep(String title, bool isCompleted, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF003366).withOpacity(0.1)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompleted ? const Color(0xFF003366) : Colors.grey[300]!,
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF003366) : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: isCompleted ? Colors.white : Colors.grey[600],
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isCompleted ? const Color(0xFF003366) : Colors.grey[700],
                fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String text, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF003366).withOpacity(0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? const Color(0xFF003366) : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            const Icon(Icons.check_circle, size: 16, color: Color(0xFF003366)),
          if (isActive) const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: isActive ? const Color(0xFF003366) : Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widget for section headers
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
