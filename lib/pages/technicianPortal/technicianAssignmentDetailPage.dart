import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:leco_docket_tracker/pages/technicianPortal/widgets/kvRow.dart';
import 'package:leco_docket_tracker/pages/technicianPortal/widgets/photoGrid.dart';
import 'package:leco_docket_tracker/pages/technicianPortal/services/workLogService.dart';

import '../../models/ImageModel.dart';
import '../../models/dockets.dart';
import '../../models/docketAssignment.dart' as models;

import '../viewDockets/updateDockets/httpUpdateDockets.dart';

class AssignmentDetailPage extends StatefulWidget {
  final Docket docket;
  final models.DocketAssignment assignment;
  final String employeeNo; // from caller
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

  String? _workLogId; // (string for simplicity)
  bool _loading = true;
  bool _saving = false;

  // Milestone flags (simple UI state)
  bool _seen = true, _ack = false, _att = false, _started = false, _completed = false;
  // _saving is already declared above in the state variables

  // Notes
  String _techNotes = '';

  // Photos
  final List<ImageModel> _before = [];
  final List<ImageModel> _after = [];
  final List<ImageModel> _extra = [];

  String _now() => DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _seen = true; // Mark as seen when page is opened
    _hydrate();
  }

  Future<void> _hydrate() async {
    setState(() => _loading = true);
    try {
      // First, try to get existing work log
      final workLogs = await WorkLogService.getWorkLogs(
        assignmentId: widget.assignment.docketId,
        docketID: '${widget.docket.id}',
        employeeNo: widget.employeeNo,
      );

      // Check if there's an existing acknowledged work log
      final hasAcknowledged = workLogs.any((log) => 
        log.acknowledgedAt != null && log.acknowledgedAt!.isNotEmpty);

      // Ensure work log exists and get id
      _workLogId = await WorkLogService.ensureWorkLogId(
        assignmentID: widget.assignment.docketId,
        docketID: '${widget.docket.id}',
        employeeNo: widget.employeeNo,
        onStartedIfNew: _now(),
      );

      // Pull existing photos (so reopening after crash shows server state)
      final before = await WorkLogService.listPhotos(
        workLogId: _workLogId!,
        kind: PhotoKind.before,
      );
      final after = await WorkLogService.listPhotos(
        workLogId: _workLogId!,
        kind: PhotoKind.after,
      );
      final extra = await WorkLogService.listPhotos(
        workLogId: _workLogId!,
        kind: PhotoKind.extra,
      );

      setState(() {
        _before
          ..clear()
          ..addAll(before);
        _after
          ..clear()
          ..addAll(after);
        _extra
          ..clear()
          ..addAll(extra);

        // Set flags based on database state
        _ack = hasAcknowledged;
        _started = _before.isNotEmpty;
        _completed = _after.isNotEmpty;
      });

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    }
  }

  // ---------- Milestones ----------
  Future<void> _markAck() async {
    if (_ack || _saving) return;
    setState(() {
      _saving = true;
      _ack = true; // Immediately update UI to show acknowledgment in progress
    });
    
    try {
      final now = _now();
      
      // First update the work log in the database
      await WorkLogService.acknowledgeWorkLog(
        assignmentID: widget.assignment.docketId,
        docketID: widget.docket.id.toString(),
        employeeNo: widget.employeeNo,
        acknowledgedAt: now,
      );
      
      // Update the milestone for backward compatibility
      await WorkLogService.setMilestone(
        assignmentID: widget.assignment.docketId,
        employeeNo: widget.employeeNo,
        field: MilestoneField.acknowledgedAt,
        value: now,
      );
      
      if (mounted) {
        // Update the button state to show it's acknowledged
        setState(() {
          _ack = true;
          _saving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment acknowledged'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Revert the UI state on error
      if (mounted) {
        setState(() {
          _ack = false;
          _saving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to acknowledge: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Revert the UI state on error
      if (mounted) {
        setState(() => _ack = false);
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _markAttending() async {
    if (_att) return;
    setState(() => _att = true);
    await WorkLogService.setMilestone(
      assignmentID: widget.assignment.docketId,
      employeeNo: widget.employeeNo,
      field: MilestoneField.attendingAt,
      value: _now(),
    );
    // TODO: Implement markAttending method or replace with working alternative
    // await AssignmentService.markAttending(
    //   assignmentID: widget.assignment.docketId,
    //   by: widget.employeeNo,
    // );
  }

  // ---------- Photos ----------
  Future<void> _addPhoto(PhotoKind kind) async {
    if (kind != PhotoKind.extra && !_att) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mark Attending first.')));
      return;
    }
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x == null || _workLogId == null) return;

    setState(() => _saving = true);
    try {
      final seq = _seqFor(kind);
      final im = await WorkLogService.uploadPhoto(
        workLogId: _workLogId!,
        kind: kind,
        filePath: x.path,
        sequence: seq,
        caption: _captionFor(kind),
        uploadedBy: widget.employeeNo,
      );

      switch (kind) {
        case PhotoKind.before:
          _before.add(im);
          _started = true;
          await WorkLogService.setMilestone(
            assignmentID: widget.assignment.docketId,
            employeeNo: widget.employeeNo,
            field: MilestoneField.startedAt,
            value: _now(),
          );
          // TODO: Implement markStarted method or replace with working alternative
          // await AssignmentService.markStarted(
          //   assignmentID: widget.assignment.docketId,
          //   by: widget.employeeNo,
          // );
          break;
        case PhotoKind.after:
          _after.add(im);
          _completed = true;
          break;
        case PhotoKind.extra:
          _extra.add(im);
          break;
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Upload failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _seqFor(PhotoKind k) {
    switch (k) {
      case PhotoKind.before:
        return _before.length + 1;
      case PhotoKind.after:
        return _after.length + 1;
      case PhotoKind.extra:
        return _extra.length + 1;
    }
  }

  String _captionFor(PhotoKind k) {
    final serial = widget.docket.docketSerial;
    switch (k) {
      case PhotoKind.before:
        return 'BEFORE $serial @ ${_now()}';
      case PhotoKind.after:
        return 'AFTER $serial @ ${_now()}';
      case PhotoKind.extra:
        return 'EXTRA $serial @ ${_now()}';
    }
  }

  // ---------- Complete ----------
  Future<void> _markComplete() async {
    if (_before.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one BEFORE photo.')),
      );
      return;
    }
    if (_after.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one AFTER photo.')),
      );
      return;
    }

    setState(() => _saving = true);
    final nowStr = _now();
    try {
      // 1) Mark WorkLog (status/completedAt)
      await WorkLogService.complete(
        assignmentID: widget.assignment.docketId,
        employeeNo: widget.employeeNo,
        completedAt: nowStr,
      );

      // 2) Update Docket row
      final ok1 = await DocketUpdateApi.updateFields(
        id: widget.docket.id,
        fields: {'AssignedTime': '2', 'completedTime': nowStr},
      );

      // 3) Update Assignment row - TODO: Implement markCompleted method
      // final ok2 = await AssignmentService.markCompleted(
      //   assignmentID: widget.assignment.docketId,
      //   completedTime: nowStr,
      //   updatedBy: widget.employeeNo,
      //   // reassignedNew: '2', // enable if you mirror status here
      // );
      final ok2 = true; // Placeholder until method is implemented

      if (ok1 && ok2) {
        if (widget.onChanged != null) await widget.onChanged!();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Completed and updated')),
          );
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Update failed'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- UI ----------
  String _fmt(String s) => (s.isEmpty || s.toUpperCase() == 'NULL') ? '-' : s;

  @override
  Widget build(BuildContext context) {
    final d = widget.docket;
    final a = widget.assignment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.docketType,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Depot: ${d.depot}    Serial: ${d.docketSerial}'),
                  // KvRow(label: 'Location', value: d.locationDetails ?? '-'), // locationDetails not available on Docket model
                  const Divider(height: 24),

                  KvRow(label: 'Docket ID', value: a.docketId),
                  KvRow(label: 'Assigned Persons', value: a.assignedPersons),
                  KvRow(label: 'Assigned Time', value: _fmt(a.assignedTime)),
                  KvRow(label: 'Reassigned', value: a.reassigned.toString()),
                  KvRow(label: 'Uploaded By', value: a.uploadedBy),
                  KvRow(label: 'Uploaded Time', value: _fmt(a.uploadedTime)),
                  // KvRow(label: 'Completed Time', value: _fmt(a.completedTime)), // completedTime not available on DocketAssignment model
                  const Divider(height: 24),

                  const Text(
                    'My Progress',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('Seen', _seen),
                      _chip('Acknowledged', _ack),
                      _chip('Attending', _att),
                      _chip('Started', _started),
                      _chip('Completed', _completed),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // BEFORE
                  SectionHeader(
                    title: 'Before photos',
                    action: TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _addPhoto(PhotoKind.before),
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Add BEFORE'),
                    ),
                  ),
                  PhotoGrid(images: _before),

                  const SizedBox(height: 16),

                  // EXTRA
                  SectionHeader(
                    title: 'Extra photos',
                    action: TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _addPhoto(PhotoKind.extra),
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add EXTRA'),
                    ),
                  ),
                  PhotoGrid(images: _extra),

                  const SizedBox(height: 16),

                  // AFTER
                  SectionHeader(
                    title: 'After photos',
                    action: TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _addPhoto(PhotoKind.after),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Add AFTER'),
                    ),
                  ),
                  PhotoGrid(images: _after),

                  const SizedBox(height: 16),

                  // Actions
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _ack || _saving ? null : _markAck,
                        icon: _ack 
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.done_all),
                        label: _saving 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_ack ? 'Acknowledged' : 'Acknowledge'),
                        style: ButtonStyle(
                          backgroundColor: _ack
                              ? MaterialStateProperty.all(Colors.green.withOpacity(0.1))
                              : null,
                          foregroundColor: _ack
                              ? MaterialStateProperty.all(Colors.green)
                              : null,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _att ? null : _markAttending,
                        icon: const Icon(Icons.directions_walk),
                        label: const Text('Attending'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _addPhoto(PhotoKind.before),
                        icon: const Icon(Icons.play_circle),
                        label: const Text('Start work (add BEFORE)'),
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            (!_saving &&
                                _before.isNotEmpty &&
                                _after.isNotEmpty)
                            ? _markComplete
                            : null,
                        icon: const Icon(Icons.check_circle),
                        label: Text(_saving ? 'Saving…' : 'Mark complete'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Technician Notes',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    minLines: 2,
                    maxLines: 5,
                    onChanged: (v) => _techNotes = v,
                    decoration: const InputDecoration(
                      hintText: 'Add any notes about this job...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await WorkLogService.saveRemarks(
                          assignmentID: widget.assignment.docketId,
                          employeeNo: widget.employeeNo,
                          remarks: _techNotes,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notes saved')),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save notes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _chip(String text, bool on) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: on
          ? const Color(0xFF003366).withOpacity(0.1)
          : Colors.black12.withOpacity(0.06),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: on ? const Color(0xFF003366) : Colors.black26),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: on ? const Color(0xFF003366) : Colors.black54,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

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

//v1
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
//
// import '../../models/ImageModel.dart';
// import '../../models/dockets.dart';
// import '../../models/docketAssignment.dart';
// import '../../service/assignment_service.dart';
// import '../viewDockets/updateDockets/httpUpdateDockets.dart';
//
// /// Replace the implementation of these two functions with your real services.
// /// 1) Upload one image and return its ImageModel.
// /// 2) List all images for a docket (used to reload after crash / reopen).
// abstract class ImageRepository {
//   static Future<ImageModel> uploadForDocket({
//     required String docketId,
//     required String filePath,
//     required String title,
//     String? description,
//   }) async {
//     // TODO: call your existing uploader here and return ImageModel
//     // Example:
//     // return await MyUploader.upload(docketId: docketId, filePath: filePath, title: title, description: description);
//
//     // Temporary placeholder so this file compiles if you paste it:
//     return ImageModel(
//       id: DateTime.now().millisecondsSinceEpoch.toString(),
//       title: title,
//       imageUrl: filePath, // replace with uploaded URL
//       description: description,
//       createdAt: DateTime.now(),
//     );
//   }
//
//   static Future<List<ImageModel>> listForDocket(String docketId) async {
//     // TODO: replace with your API that fetches all images for a docket
//     // Example: return await MyUploader.list(docketId);
//     return <ImageModel>[];
//   }
// }
//
// class AssignmentDetailPage extends StatefulWidget {
//   final Docket docket;
//   final DocketAssignment assignment;
//   final String employeeNo; // pass from caller (avoid Provider in initState)
//   final Future<void> Function()? onChanged;
//
//   const AssignmentDetailPage({
//     super.key,
//     required this.docket,
//     required this.assignment,
//     required this.employeeNo,
//     this.onChanged,
//   });
//
//   @override
//   State<AssignmentDetailPage> createState() => _AssignmentDetailPageState();
// }
//
// class _AssignmentDetailPageState extends State<AssignmentDetailPage> {
//   final _picker = ImagePicker();
//
//   // Server state we keep in memory for quick UI updates
//   ImageModel? _beforePhoto;
//   ImageModel? _afterPhoto;
//   final List<ImageModel> _extraPhotos = [];
//   String _techNotes = '';
//
//   bool _saving = false;
//   bool _acknowledged = false;
//   bool _attending = false;
//   bool _started = false;
//   bool _completed = false;
//
//   String get _docketId => '${widget.docket.id}';
//   String _nowStr() => DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
//
//   @override
//   void initState() {
//     super.initState();
//     _hydrateFromServer();
//   }
//
//   /// Pull existing images + infer milestones if possible.
//   Future<void> _hydrateFromServer() async {
//     try {
//       final imgs = await ImageRepository.listForDocket(_docketId);
//
//       // If you tag your uploads by title, we can classify them:
//       // e.g. title starts with "BEFORE:", "AFTER:", "EXTRA:"
//       for (final im in imgs) {
//         final t = im.title.toUpperCase();
//         if (t.startsWith('BEFORE')) {
//           _beforePhoto ??= im;
//           _started = true;
//         } else if (t.startsWith('AFTER')) {
//           _afterPhoto ??= im;
//           _completed = true;
//         } else if (t.startsWith('EXTRA') || t.startsWith('ADDITIONAL')) {
//           _extraPhotos.add(im);
//         }
//       }
//
//       // If your server already stores per-milestone times in DocketAssignment,
//       // you can read widget.assignment.* fields here to set _acknowledged/_attending/_started/_completed.
//
//       setState(() {});
//     } catch (_) {
//       // ignore; show whatever we have
//     }
//   }
//
//   // ---------- Actions (upload first, then stamp server times) ----------
//   Future<void> _ack() async {
//     if (_acknowledged) return;
//     setState(() => _acknowledged = true);
//     await AssignmentService.markAcknowledged(
//       assignmentID: widget.assignment.assignmentId,
//       by: widget.employeeNo,
//     );
//   }
//
//   Future<void> _attend() async {
//     if (_attending) return;
//     setState(() => _attending = true);
//     await AssignmentService.markAttending(
//       assignmentID: widget.assignment.assignmentId,
//       by: widget.employeeNo,
//     );
//   }
//
//   Future<void> _startWork() async {
//     // Capture BEFORE, upload immediately.
//     final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
//     if (x == null) return;
//
//     setState(() => _saving = true);
//     try {
//       final im = await ImageRepository.uploadForDocket(
//         docketId: _docketId,
//         filePath: x.path,
//         title: 'BEFORE: ${widget.docket.docketSerial}',
//         description: 'Before work photo by ${widget.employeeNo} at ${_nowStr()}',
//       );
//       setState(() {
//         _beforePhoto = im;
//         _started = true;
//       });
//       await AssignmentService.markStarted(
//         assignmentID: widget.assignment.assignmentId,
//         by: widget.employeeNo,
//       );
//     } finally {
//       if (mounted) setState(() => _saving = false);
//     }
//   }
//
//   Future<void> _addExtra() async {
//     if (!_attending) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Mark Attending before adding extras.')),
//       );
//       return;
//     }
//     final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
//     if (x == null) return;
//
//     setState(() => _saving = true);
//     try {
//       final im = await ImageRepository.uploadForDocket(
//         docketId: _docketId,
//         filePath: x.path,
//         title: 'EXTRA: ${widget.docket.docketSerial}',
//         description: 'Additional work photo by ${widget.employeeNo} at ${_nowStr()}',
//       );
//       setState(() => _extraPhotos.add(im));
//       // If you want to send extraComment/notes at this step, you can call AssignmentService.updateFields(...)
//     } finally {
//       if (mounted) setState(() => _saving = false);
//     }
//   }
//
//   Future<void> _complete() async {
//     if (!_started) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please take the BEFORE photo (Start Work) first.')),
//       );
//       return;
//     }
//
//     final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
//     if (x == null) return;
//
//     setState(() => _saving = true);
//     final nowStr = _nowStr();
//     try {
//       // Upload AFTER first (crash-safe)
//       final im = await ImageRepository.uploadForDocket(
//         docketId: _docketId,
//         filePath: x.path,
//         title: 'AFTER: ${widget.docket.docketSerial}',
//         description: 'After work photo by ${widget.employeeNo} at $nowStr',
//       );
//       setState(() {
//         _afterPhoto = im;
//         _completed = true;
//       });
//
//       // Update Docket (status + completedTime)
//       final ok1 = await DocketUpdateApi.updateFields(id: widget.docket.id, fields: {
//         'AssignedTime': '2',
//         'completedTime': nowStr,
//       });
//
//       // Update DocketAssignment.completedTime (optionally reassigned="2")
//       final ok2 = await AssignmentService.markCompleted(
//         assignmentID: widget.assignment.assignmentId,
//         completedTime: nowStr,
//         updatedBy: widget.employeeNo,
//         // reassignedNew: '2', // uncomment if your table uses this to mark done
//       );
//
//       if (ok1 && ok2) {
//         if (widget.onChanged != null) await widget.onChanged!();
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completed and updated')));
//           Navigator.pop(context);
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(backgroundColor: Colors.red, content: Text('Update failed')),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _saving = false);
//     }
//   }
//
//   // ---------- UI ----------
//   String _fmt(String s) => (s.isEmpty || s.toUpperCase() == 'NULL') ? '-' : s;
//
//   @override
//   Widget build(BuildContext context) {
//     final d = widget.docket;
//     final a = widget.assignment;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Assignment'),
//         backgroundColor: const Color(0xFF003366),
//         foregroundColor: Colors.white,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text(d.docketType, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF003366))),
//           const SizedBox(height: 6),
//           Text('Depot: ${d.depot}    Serial: ${d.docketSerial}'),
//           _kv('Location', d.locationDetails ?? '-'),
//           const Divider(height: 24),
//
//           _kv('Assignment ID', a.assignmentId),
//           _kv('Assigned Persons', a.assignedPersons),
//           _kv('Assigned Time', _fmt(a.assignedTime)),
//           _kv('Reassigned', a.reassigned),
//           _kv('Uploaded By', a.uploadedBy),
//           _kv('Uploaded Time', _fmt(a.uploadedTime)),
//           _kv('Completed Time', _fmt(a.completedTime)),
//           const Divider(height: 24),
//
//           const Text('My Progress', style: TextStyle(fontWeight: FontWeight.w700)),
//           const SizedBox(height: 8),
//           Wrap(
//             spacing: 8,
//             runSpacing: 8,
//             children: [
//               _chip('Acknowledged', _acknowledged),
//               _chip('Attending', _attending),
//               _chip('Started', _started),
//               _chip('Completed', _completed),
//             ],
//           ),
//           const SizedBox(height: 12),
//
//           if (_beforePhoto != null) _photoTile('Before photo', _beforePhoto!),
//           if (_afterPhoto  != null) _photoTile('After photo',  _afterPhoto!),
//           if (_extraPhotos.isNotEmpty) ...[
//             const SizedBox(height: 8),
//             const Text('Extra photos', style: TextStyle(fontWeight: FontWeight.w600)),
//             const SizedBox(height: 6),
//             Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: _extraPhotos.map(_thumb).toList(),
//             ),
//           ],
//
//           const SizedBox(height: 16),
//
//           Wrap(spacing: 8, runSpacing: 8, children: [
//             ElevatedButton.icon(
//                 onPressed: _acknowledged ? null : _ack,
//                 icon: const Icon(Icons.done_all),
//                 label: const Text('Acknowledge')),
//             ElevatedButton.icon(
//                 onPressed: _attending ? null : _attend,
//                 icon: const Icon(Icons.directions_walk),
//                 label: const Text('Attending')),
//             ElevatedButton.icon(
//                 onPressed: _started || _saving ? null : _startWork,
//                 icon: const Icon(Icons.play_circle),
//                 label: const Text('Start work (before)')),
//             OutlinedButton.icon(
//                 onPressed: _attending && !_saving ? _addExtra : null,
//                 icon: const Icon(Icons.add_a_photo),
//                 label: const Text('Add extra')),
//             ElevatedButton.icon(
//                 onPressed: _started && _afterPhoto == null && !_saving ? _complete : null,
//                 icon: const Icon(Icons.check_circle),
//                 label: Text(_saving ? 'Saving…' : 'Complete (after)')),
//           ]),
//
//           const SizedBox(height: 24),
//
//           const Text('Technician Notes', style: TextStyle(fontWeight: FontWeight.w700)),
//           const SizedBox(height: 8),
//           TextField(
//             minLines: 2,
//             maxLines: 5,
//             onChanged: (v) => _techNotes = v,
//             decoration: const InputDecoration(
//               hintText: 'Add any notes about this job...',
//               border: OutlineInputBorder(),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Align(
//             alignment: Alignment.centerRight,
//             child: TextButton.icon(
//               onPressed: () async {
//                 // Optional: send notes to server (choose a suitable column)
//                 // await AssignmentService.updateFields(
//                 //   assignmentID: widget.assignment.assignmentId,
//                 //   fields: {'techNotes': _techNotes},
//                 // );
//                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes saved')));
//               },
//               icon: const Icon(Icons.save_alt),
//               label: const Text('Save notes'),
//             ),
//           ),
//         ]),
//       ),
//     );
//   }
//
//   // ---- small UI helpers
//   Widget _kv(String k, String v) => Padding(
//     padding: const EdgeInsets.symmetric(vertical: 4),
//     child: Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(width: 140, child: Text('$k:', style: const TextStyle(color: Colors.black54))),
//         Expanded(child: Text(v.isEmpty ? '-' : v)),
//       ],
//     ),
//   );
//
//   Widget _chip(String text, bool on) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//     decoration: BoxDecoration(
//       color: on ? const Color(0xFF003366).withOpacity(0.1) : Colors.black12.withOpacity(0.06),
//       borderRadius: BorderRadius.circular(999),
//       border: Border.all(color: on ? const Color(0xFF003366) : Colors.black26),
//     ),
//     child: Text(text, style: TextStyle(color: on ? const Color(0xFF003366) : Colors.black54, fontWeight: FontWeight.w600)),
//   );
//
//   Widget _photoTile(String title, ImageModel im) {
//     final img = _buildImage(im.imageUrl);
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
//         const SizedBox(height: 6),
//         ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
//         const SizedBox(height: 8),
//       ],
//     );
//   }
//
//   Widget _thumb(ImageModel im) {
//     final img = _buildImage(im.imageUrl, height: 120.0);
//     return ClipRRect(borderRadius: BorderRadius.circular(8), child: img);
//   }
//
//   Widget _buildImage(String uri, {double height = 200}) {
//     if (uri.startsWith('http://') || uri.startsWith('https://')) {
//       return Image.network(uri, height: height, fit: BoxFit.cover);
//     }
//     // For true file paths on mobile, switch to:
//     // return Image.file(File(uri), height: height, fit: BoxFit.cover);
//     return Image.asset(uri, height: height, fit: BoxFit.cover);
//   }
// }
