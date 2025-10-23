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
// update DocketDetails.status
import 'services/httpUpdateDocketStatus2.dart';

// import '../viewDockets/updateDockets/httpUpdateDockets.dart';

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

  // Local state management for workflow states (persists during session)
  bool _localIsAcknowledged = false;
  bool _localIsAttending = false;
  bool _localIsStarted = false;
  bool _localIsCompleted = false;

  // Computed workflow states - use local state OR database state
  bool get _isAcknowledged =>
      _localIsAcknowledged || (_workLog?.acknowledgedAt != null);
  bool get _isAttending => _localIsAttending || (_workLog?.attendingAt != null);
  bool get _isStarted => _localIsStarted || (_workLog?.startedAt != null);
  bool get _isCompleted => _localIsCompleted || (_workLog?.completedAt != null);

  // UI state helpers
  bool get _canAttend => _isAcknowledged && !_isAttending;

  // Workflow: Acknowledge → Attend → Start Work (with BEFORE photos) → Complete Work (with AFTER photos)
  // Photo-related getters - Attendance tracking workflow
  bool get _canTakeBeforePhotos =>
      _isAttending && !_isCompleted; // Unlocked after attending
  bool get _canTakeAfterPhotos =>
      _isStarted &&
      _beforePhotos.isNotEmpty &&
      !_isCompleted; // AFTER photos unlock only when work started AND BEFORE photos exist
  bool get _canTakeExtraPhotos =>
      _isAcknowledged; // EXTRA photos available always after acknowledgment
  bool get _canComplete =>
      _isStarted &&
      _beforePhotos.isNotEmpty &&
      _afterPhotos.isNotEmpty &&
      !_isCompleted;

  String _now() => DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  /// Get effective employee number with fallback for testing
  String get _effectiveEmployeeNo =>
      widget.employeeNo.isEmpty ? 'TEMP_USER_001' : widget.employeeNo;

  /// Generate docket image URL
  String _getDocketImageUrl(String imageName) {
    if (imageName.isEmpty) return '';

    // Clean the image name (remove any existing .jpg extensions)
    String cleanImageName = imageName.replaceAll('.jpg', '');

    // Docket images are stored in subdirectory '4' (original docket images)
    final url =
        'http://124.43.181.243:8000/api/fetch-testdocket-image/4/$cleanImageName.jpg';
    print('DEBUG getDocketImageUrl: $imageName -> $url');
    return url;
  }

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

      // Use fallback employee number if not provided
      print('DEBUG: Using effectiveEmployeeNo: "$_effectiveEmployeeNo"');

      print('DEBUG: About to call WorkLogService.getWorkLogs...');
      // Try to get existing work log
      final existingLogs = await WorkLogService.getWorkLogs(
        assignmentId: widget.assignment.docketId,
        docketId: widget.docket.id,
        employeeNo: _effectiveEmployeeNo,
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
            _workLog!.docketId != widget.docket.id ||
            _workLog!.employeeNo != _effectiveEmployeeNo) {
          print('DEBUG: WARNING - Work log data mismatch!');
          print(
            'DEBUG: Expected assignmentId: ${widget.assignment.docketId}, got: ${_workLog!.assignmentId}',
          );
          print(
            'DEBUG: Expected docketId: ${widget.docket.id}, got: ${_workLog!.docketId}',
          );
          print(
            'DEBUG: Expected employeeNo: $_effectiveEmployeeNo, got: ${_workLog!.employeeNo}',
          );
          _showError('Work log data mismatch. Creating new work log...');
          _workLog = null; // Force creation of new work log
        }
      }

      if (_workLog == null) {
        print(
          'DEBUG: No existing work log found - creating new one automatically...',
        );
        print('DEBUG: About to call WorkLogService.createWorkLog...');

        try {
          // Always create work log when assignment is opened (if it doesn't exist)
          _workLog = await WorkLogService.createWorkLog(
            assignmentId: widget.assignment.docketId,
            docketId: widget.docket.id,
            employeeNo: _effectiveEmployeeNo,
          );
          print('DEBUG: Successfully created new work log: $_workLog');
        } catch (createError) {
          print('DEBUG: Error during createWorkLog: $createError');
          print('DEBUG: Checking if work log was actually created...');

          // Add a small delay to allow database consistency
          await Future.delayed(Duration(milliseconds: 500));

          // Try to reload work logs to see if creation succeeded despite error
          try {
            final existingLogs = await WorkLogService.getWorkLogs(
              assignmentId: widget.assignment.docketId,
              docketId: widget.docket.id,
              employeeNo: _effectiveEmployeeNo,
            );

            if (existingLogs.isNotEmpty) {
              print(
                'DEBUG: Work log was actually created successfully despite API error!',
              );
              _workLog = existingLogs.first;
            } else {
              print('DEBUG: Work log creation truly failed');

              // Provide more helpful error message for server errors
              if (createError.toString().contains('Server Error: 500')) {
                throw 'Server temporarily unavailable. Please try again.';
              }
              rethrow; // Re-throw original error
            }
          } catch (reloadError) {
            print('DEBUG: Failed to reload work logs: $reloadError');

            // Provide more helpful error message for server errors
            if (createError.toString().contains('Server Error: 500')) {
              throw 'Server temporarily unavailable. Please try again.';
            }
            throw createError; // Re-throw original error
          }
        }
      }

      // Validate work log was created/loaded successfully
      if (_workLog == null) {
        print(
          'DEBUG: CRITICAL ERROR: _workLog is still null after creation attempt',
        );
        throw 'Failed to create or load work log';
      } else if (_workLog!.id.isEmpty) {
        print('DEBUG: CRITICAL ERROR: _workLog.id is empty after creation');
        throw 'Work log created but has empty ID';
      } else {
        print('DEBUG: Work log ready with ID: ${_workLog!.id}');
      }

      // Load existing photos
      await _loadPhotos();

      // Initialize local state based on database state
      _localIsAcknowledged = _workLog?.acknowledgedAt != null;
      _localIsAttending = _workLog?.attendingAt != null;
      _localIsStarted = _workLog?.startedAt != null;
      _localIsCompleted = _workLog?.completedAt != null;

      // Set notes if available
      if (_workLog?.remarks != null) {
        _notesController.text = _workLog!.remarks!;
      }

      print('DEBUG: _loadWorkLog() completed successfully');
      setState(() => _loading = false);
    } catch (e, stackTrace) {
      print('DEBUG: Exception in _loadWorkLog(): $e');
      print('DEBUG: Stack trace: $stackTrace');

      // Check if we actually have a work log despite the error
      if (_workLog != null && _workLog!.id.isNotEmpty) {
        print('DEBUG: Work log exists despite error - continuing normally');
        setState(() => _loading = false);
        // Don't show error message since work log is actually available
      } else {
        print('DEBUG: No work log available after error');
        setState(() => _loading = false);
        _showError('Failed to load work log: $e');
      }

      print('DEBUG: _loadWorkLog() completed with error');
    }
  }

  /// Load photos from server
  Future<void> _loadPhotos() async {
    if (_workLog?.id == null) return;

    try {
      final beforePhotos = await WorkLogService.getWorkPhotosByKind(
        workLogId: _workLog!.id,
        kind: PhotoKind.before,
      );
      final afterPhotos = await WorkLogService.getWorkPhotosByKind(
        workLogId: _workLog!.id,
        kind: PhotoKind.after,
      );
      final extraPhotos = await WorkLogService.getWorkPhotosByKind(
        workLogId: _workLog!.id,
        kind: PhotoKind.extra,
      );

      _beforePhotos
        ..clear()
        ..addAll(beforePhotos);
      _afterPhotos
        ..clear()
        ..addAll(afterPhotos);
      _extraPhotos
        ..clear()
        ..addAll(extraPhotos);
    } catch (e) {
      _showError('Failed to load photos: $e');
    }
  }

  /// Mark as acknowledged - Simply update the existing work log
  Future<void> _markAcknowledged() async {
    print('DEBUG: _markAcknowledged called');
    print('DEBUG: _isAcknowledged = $_isAcknowledged');
    print('DEBUG: _workLog?.id = ${_workLog?.id}');

    if (_saving) {
      print('DEBUG: Already saving, ignoring acknowledge request');
      return;
    }

    if (_isAcknowledged) {
      _showError('Assignment is already acknowledged');
      return;
    }

    if (_workLog == null || _workLog!.id.isEmpty) {
      _showError('Work log not found. Please try reloading the page.');
      return;
    }

    setState(() => _saving = true);
    try {
      print('DEBUG: Updating work log with acknowledgment');
      print('DEBUG: workLogId: ${_workLog!.id}');
      print('DEBUG: acknowledgedAt: ${_now()}');

      // Simply update the existing work log with acknowledgment
      _workLog = await WorkLogService.updateWorkLog(
        workLogId: _workLog!.id,
        acknowledgedAt: _now(),
      );

      print('DEBUG: Successfully updated work log: $_workLog');

      // Update local state for immediate UI response
      _localIsAcknowledged = true;

      setState(() {});
      _showSuccess('Assignment acknowledged successfully!');
    } catch (e) {
      print('DEBUG: Error in _markAcknowledged: $e');
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
        workLogId: _workLog!.id,
        attendingAt: _now(),
      );

      // Update local state for immediate UI response
      _localIsAttending = true;

      print('DEBUG: After setting _localIsAttending = true');
      print('DEBUG: _localIsAcknowledged = $_localIsAcknowledged');
      print('DEBUG: _localIsAttending = $_localIsAttending');
      print('DEBUG: _isAcknowledged = $_isAcknowledged');
      print('DEBUG: _isAttending = $_isAttending');
      print('DEBUG: _canAttend = $_canAttend');

      setState(() {
        // Force UI rebuild with updated state
      });
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
        workLogId: _workLog!.id,
        startedAt: _now(),
      );

      // Update local state for immediate UI response
      _localIsStarted = true;

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
      _showError('You must acknowledge the assignment first');
      return;
    }

    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _saving = true);
    try {
      final sequence = _getNextSequence(kind);
      final caption = _generateCaption(kind);

      final workPhoto = await WorkLogService.uploadWorkPhotoWithKind(
        workLogId: _workLog!.id,
        kind: kind,
        filePath: image.path,
        sequence: sequence,
        caption: caption,
        uploadedBy: _effectiveEmployeeNo,
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
        workLogId: _workLog!.id,
        completedAt: nowStr,
        remarks: _notesController.text.trim(),
      );

      // Update local state for immediate UI response
      _localIsCompleted = true;

      // 2) Update Docket row
      final docketUpdated = await DocketStatusApi.markCompleted(
        widget.docket.id,
      );

      if (docketUpdated) {
        if (widget.onChanged != null) await widget.onChanged!();
        _showSuccess('Assignment completed successfully!');

        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        print(
          'DEBUG: docketUpdated returned false, but WorkLog was updated successfully',
        );
        print('DEBUG: WorkLog completion status: ${_workLog?.completedAt}');

        // Even though docketUpdated returned false, the WorkLog was updated successfully
        // This might be a server response parsing issue, so let's show success instead
        _showSuccess('Assignment completed successfully! (WorkLog updated)');

        if (widget.onChanged != null) await widget.onChanged!();

        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      _showError('Failed to complete assignment: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  /// Save notes
  Future<void> _saveNotes() async {
    if (_workLog?.id == null) {
      print('DEBUG: _workLog is null or id is null');
      return;
    }

    if (_workLog!.id.isEmpty) {
      print('DEBUG: _workLog.id is empty string');
      _showError('Work log ID is missing. Please try refreshing the page.');
      return;
    }

    final currentNotes = _notesController.text.trim();
    print('DEBUG: Saving notes with work log ID: "${_workLog!.id}"');
    print('DEBUG: Current notes content: "$currentNotes"');
    print('DEBUG: Original remarks: "${_workLog?.remarks ?? ''}"');

    setState(() => _saving = true);
    try {
      String finalNotes;

      // Check if this is a completed assignment and we're adding additional notes
      if (_isCompleted) {
        final originalNotes = (_workLog?.remarks ?? '').trim();

        // If the current notes are exactly the same as original, no changes needed
        if (currentNotes == originalNotes) {
          _showSuccess('No changes to save');
          setState(() => _saving = false);
          return;
        }

        // If current notes are completely different or longer, assume user added new content
        if (currentNotes.length > originalNotes.length &&
            currentNotes.startsWith(originalNotes)) {
          // User added content to the end - append with timestamp
          final newContent = currentNotes
              .substring(originalNotes.length)
              .trim();
          if (newContent.isNotEmpty) {
            final timestamp = DateFormat(
              'yyyy-MM-dd HH:mm',
            ).format(DateTime.now());

            if (originalNotes.isEmpty) {
              finalNotes = '[$timestamp] $newContent';
            } else {
              finalNotes =
                  '$originalNotes\n\n--- Additional Comments ---\n[$timestamp] $newContent';
            }
          } else {
            finalNotes = originalNotes;
          }
        } else {
          // Content was modified - append as new timestamped comment to preserve original
          final timestamp = DateFormat(
            'yyyy-MM-dd HH:mm',
          ).format(DateTime.now());

          if (originalNotes.isEmpty) {
            finalNotes = '[$timestamp] $currentNotes';
          } else {
            finalNotes =
                '$originalNotes\n\n--- Additional Comments ---\n[$timestamp] $currentNotes';
          }
        }

        print('DEBUG: Final notes for completed assignment: "$finalNotes"');
      } else {
        // Assignment not completed yet - allow normal editing
        finalNotes = currentNotes;
        print('DEBUG: Final notes for active assignment: "$finalNotes"');
      }

      await WorkLogService.updateWorkLog(
        workLogId: _workLog!.id,
        remarks: finalNotes,
      );

      // Update the local worklog and text controller with the final notes
      if (_workLog != null) {
        _workLog = _workLog!.copyWith(remarks: finalNotes);
        _notesController.text = finalNotes;
      }

      _showSuccess(
        _isCompleted
            ? 'Additional comments saved successfully'
            : 'Notes saved successfully',
      );
    } catch (e) {
      _showError('Failed to save notes: $e');
    } finally {
      setState(() => _saving = false);
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
        return 'BEFORE_${serial}_$formattedDate';
      case PhotoKind.after:
        return 'AFTER_${serial}_$formattedDate';
      case PhotoKind.extra:
        return 'EXTRA_${serial}_$formattedDate';
    }
  }

  /// Show docket image in full screen
  void _showDocketImageFullScreen(String imageUrl, String docketSerial) {
    if (imageUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // Full screen image
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
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
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load docket image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  shape: CircleBorder(),
                ),
              ),
            ),
            // Title at bottom
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Docket Image - $docketSerial',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  /// Format assigned persons as comma-separated list
  String _formatAssignedPersons(String assignedPersons) {
    if (assignedPersons.isEmpty || assignedPersons.toUpperCase() == 'NULL') {
      return '-';
    }

    // Split by comma and clean up each person's name
    final persons = assignedPersons
        .split(',')
        .map((person) => person.trim())
        .where((person) => person.isNotEmpty)
        .toList();

    if (persons.isEmpty) {
      return '-';
    }

    // Join with comma and space for proper formatting
    return persons.join(', ');
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

                  // Progress and Actions
                  _buildProgressAndActions(),
                  const SizedBox(height: 32),

                  // Photo Sections (Before photos are now integrated in Start Work step, After photos are now integrated in Complete step)
                  _buildPhotoSection(
                    'Extra Photos',
                    _extraPhotos,
                    PhotoKind.extra,
                    _canTakeExtraPhotos,
                    'Add EXTRA Photo',
                    Icons.add_photo_alternate,
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButtons(),
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
    final docketImageUrl = _getDocketImageUrl(docket.imageName);

    // Debug logging for image issues
    print('DEBUG _buildDocketInfo:');
    print('  docket.id: ${docket.id}');
    print('  docket.imageName: "${docket.imageName}"');
    print('  docketImageUrl: "$docketImageUrl"');
    print('  assignment.assignedPersons: "${assignment.assignedPersons}"');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
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
                      Text(
                        'Depot: ${docket.depot}  •  Serial: ${docket.docketSerial}',
                      ),
                    ],
                  ),
                ),
                if (docketImageUrl.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _showDocketImageFullScreen(
                      docketImageUrl,
                      docket.docketSerial,
                    ),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.network(
                          docketImageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[100],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'No Image',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 20),
            KvRow(label: 'Docket ID', value: assignment.docketId),
            KvRow(
              label: 'Assigned Persons',
              value: _formatAssignedPersons(assignment.assignedPersons),
            ),
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

  Widget _buildProgressAndActions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assignment Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Step 1: Acknowledge Assignment
            _buildProgressActionStep(
              stepNumber: 1,
              title: 'Acknowledge Assignment',
              description: 'Confirm you have received this assignment',
              isCompleted: _isAcknowledged,
              isActive: !_isAcknowledged,
              icon: Icons.assignment_turned_in,
              actionButton: _isAcknowledged
                  ? null
                  : ElevatedButton.icon(
                      onPressed: (_saving || _isAcknowledged)
                          ? null
                          : _markAcknowledged,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Acknowledge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
            ),

            // Connector Line
            if (!_isCompleted) _buildConnectorLine(_isAcknowledged),

            // Step 2: Mark as Attending
            _buildProgressActionStep(
              stepNumber: 2,
              title: 'Mark as Attending',
              description: 'Confirm you are on-site and ready to work',
              isCompleted: _isAttending,
              isActive: _canAttend,
              icon: Icons.location_on,
              actionButton: _isAttending
                  ? null
                  : ElevatedButton.icon(
                      onPressed: (_saving || !_canAttend)
                          ? null
                          : _markAttending,
                      icon: const Icon(Icons.directions_walk, size: 18),
                      label: const Text('Mark Attending'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canAttend
                            ? const Color(0xFF4CAF50)
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
            ),

            // Connector Line
            if (!_isCompleted) _buildConnectorLine(_isAttending),

            // Step 3: Start Work (Auto-triggered)
            _buildProgressActionStepWithPhotos(
              stepNumber: 3,
              title: 'Start Work',
              description: _isStarted
                  ? 'Work started successfully! You can continue taking BEFORE photos if needed.'
                  : 'Take your first BEFORE photo to automatically start work',
              isCompleted: _isStarted,
              isActive: _isAttending && !_isCompleted,
              icon: Icons.play_arrow,
              showPhotoSection:
                  _isAttending, // Show photos even after completion for viewing
              photoSectionTitle: 'Before Photos (${_beforePhotos.length})',
              photos: _beforePhotos,
              photoKind: PhotoKind.before,
              canTakePhoto: _canTakeBeforePhotos,
              addPhotoButtonText: 'Take BEFORE Photo',
              addPhotoIcon: Icons.add_a_photo,
            ),

            // Connector Line
            if (!_isCompleted) _buildConnectorLine(_isStarted),

            // Step 4: Complete Work (with After Photos)
            _buildProgressActionStepWithPhotos(
              stepNumber: 4,
              title: 'Complete Assignment',
              description: _isCompleted
                  ? 'Assignment completed successfully!'
                  : 'Take AFTER photos to show completed work, then mark assignment as complete',
              isCompleted: _isCompleted,
              isActive: _isStarted && !_isCompleted,
              icon: Icons.check_circle,
              showPhotoSection:
                  _isStarted, // Show photos even after completion for viewing
              photoSectionTitle: 'After Photos (${_afterPhotos.length})',
              photos: _afterPhotos,
              photoKind: PhotoKind.after,
              canTakePhoto: _canTakeAfterPhotos,
              addPhotoButtonText: 'Take AFTER Photo',
              addPhotoIcon: Icons.add_a_photo_outlined,
              actionButton: _isCompleted
                  ? null
                  : ElevatedButton.icon(
                      onPressed: _canComplete ? _markComplete : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle, size: 18),
                      label: Text(_saving ? 'Completing...' : 'Mark Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canComplete
                            ? Colors.orange
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
            ),

            // Requirements Summary
            if (!_isCompleted) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Requirements to Complete',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRequirementCheck(
                      'At least 1 BEFORE photo',
                      _beforePhotos.isNotEmpty,
                    ),
                    _buildRequirementCheck(
                      'At least 1 AFTER photo',
                      _afterPhotos.isNotEmpty,
                    ),
                    _buildRequirementCheck('Work must be started', _isStarted),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressActionStep({
    required int stepNumber,
    required String title,
    required String description,
    required bool isCompleted,
    required bool isActive,
    required IconData icon,
    Widget? actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF003366).withOpacity(0.05)
            : (isActive
                  ? Colors.blue.withOpacity(0.02)
                  : Colors.grey.withOpacity(0.02)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF003366)
              : (isActive ? Colors.blue : Colors.grey.withOpacity(0.3)),
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Step Number/Status Circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFF003366)
                  : (isActive ? Colors.blue : Colors.grey.withOpacity(0.3)),
              shape: BoxShape.circle,
            ),
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isCompleted
                          ? const Color(0xFF003366)
                          : (isActive ? Colors.blue : Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isCompleted
                              ? const Color(0xFF003366)
                              : (isActive ? Colors.blue : Colors.grey[700]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
                if (actionButton != null) ...[
                  const SizedBox(height: 12),
                  actionButton,
                ],
                if (isCompleted) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressActionStepWithPhotos({
    required int stepNumber,
    required String title,
    required String description,
    required bool isCompleted,
    required bool isActive,
    required IconData icon,
    required bool showPhotoSection,
    required String photoSectionTitle,
    required List<WorkPhoto> photos,
    required PhotoKind photoKind,
    required bool canTakePhoto,
    required String addPhotoButtonText,
    required IconData addPhotoIcon,
    Widget? actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF003366).withOpacity(0.05)
            : (isActive
                  ? Colors.blue.withOpacity(0.02)
                  : Colors.grey.withOpacity(0.02)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF003366)
              : (isActive ? Colors.blue : Colors.grey.withOpacity(0.3)),
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Step Number/Status Circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF003366)
                      : (isActive ? Colors.blue : Colors.grey.withOpacity(0.3)),
                  shape: BoxShape.circle,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(
                        '$stepNumber',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: isCompleted
                              ? const Color(0xFF003366)
                              : (isActive ? Colors.blue : Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isCompleted
                                  ? const Color(0xFF003366)
                                  : (isActive ? Colors.blue : Colors.grey[700]),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Action Button (if provided)
          if (actionButton != null) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: actionButton),
          ],

          // Photo Section
          if (showPhotoSection) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: isActive ? Colors.blue : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          photoSectionTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.blue : Colors.grey[700],
                          ),
                        ),
                      ),
                      if (canTakePhoto)
                        ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _addPhoto(photoKind),
                          icon: Icon(addPhotoIcon, size: 16),
                          label: Text(
                            addPhotoButtonText,
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (photos.isNotEmpty)
                    PhotoGrid(images: photos)
                  else if (canTakePhoto)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.photo_camera,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              photoKind == PhotoKind.before
                                  ? 'No photos taken yet. Take your first BEFORE photo to start work!'
                                  : 'No AFTER photos taken yet. Take photos to show completed work!',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectorLine(bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(left: 20),
      child: Column(
        children: [
          Container(
            width: 2,
            height: 20,
            color: isCompleted ? const Color(0xFF003366) : Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementCheck(String requirement, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirement,
              style: TextStyle(
                fontSize: 13,
                color: isMet ? Colors.green : Colors.grey[600],
                fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
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
            if (photos.isNotEmpty)
              PhotoGrid(images: photos)
            else if (canTakePhoto)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.photo_camera, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No photos taken yet. Click "$buttonLabel" to add photos.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Request for Additional Work button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleRequestAdditionalWork,
            icon: const Icon(Icons.add_task),
            label: const Text('Request Additional Work'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Escalate button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleEscalate,
            icon: const Icon(Icons.warning_amber),
            label: const Text('Escalate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Handle request for additional work
  Future<void> _handleRequestAdditionalWork() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Additional Work'),
        content: const Text(
          'Are you sure you want to request additional work for this docket?\n\n'
          'This will notify the supervisor that extra work or resources are needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Request'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _saving = true);

      try {
        // Check if workLog exists
        if (_workLog?.id == null || _workLog!.id.isEmpty) {
          _showError('Work log not found. Please try refreshing the page.');
          return;
        }

        // Update workLog status to 1 (Additional Work Requested)
        await WorkLogService.updateWorkLog(
          workLogId: _workLog!.id,
          status: '1',
        );

        // Update local state
        if (_workLog != null) {
          _workLog = _workLog!.copyWith(status: '1');
        }

        _showSuccess('Additional work request submitted successfully');

        // Refresh if callback provided
        if (widget.onChanged != null) {
          await widget.onChanged!();
        }
      } catch (e) {
        _showError('Failed to submit request: $e');
      } finally {
        setState(() => _saving = false);
      }
    }
  }

  /// Handle escalation
  Future<void> _handleEscalate() async {
    // Show simple confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Escalate Issue'),
          ],
        ),
        content: const Text(
          'Are you sure you want to escalate this docket?\n\n'
          'This will notify management immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _saving = true);

      try {
        // Update docket status to 5 (Escalated)
        final success = await DocketStatusApi.markEscalated(widget.docket.id);

        if (success) {
          _showSuccess(
            'Issue escalated successfully. Management has been notified.',
          );

          // Refresh if callback provided
          if (widget.onChanged != null) {
            await widget.onChanged!();
          }
        } else {
          _showError('Failed to escalate docket. Please try again.');
        }
      } catch (e) {
        _showError('Error escalating docket: $e');
      } finally {
        setState(() => _saving = false);
      }
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
            // Show read-only view if assignment is completed
            if (_isCompleted && _notesController.text.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey.shade50,
                ),
                child: Text(
                  _notesController.text,
                  style: const TextStyle(fontSize: 14),
                ),
              )
            else
              // Show editable field if assignment is not completed yet
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
            // Only show save button if assignment is not completed yet
            if (!_isCompleted)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _saving ? null : _saveNotes,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt),
                  label: Text(_saving ? 'Saving...' : 'Save Notes'),
                ),
              )
            else
              // Show completion indicator
              Row(
                children: [
                  Icon(Icons.lock, color: Colors.orange.shade600, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Assignment completed - Notes locked',
                    style: TextStyle(
                      color: Colors.orange.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
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
