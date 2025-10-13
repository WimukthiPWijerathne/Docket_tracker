// lib/pages/viewDockets/docket_details_page.dart
import 'package:flutter/material.dart';
import 'package:leco_docket_tracker/pages/viewDockets/updateDockets/httpUpdateDockets.dart';
import 'package:provider/provider.dart';

import '../../models/dockets.dart';
import '../loginScreen/fetchUserAccess.dart';

class DocketDetailsPage extends StatefulWidget {
  final Docket docket;

  const DocketDetailsPage({super.key, required this.docket});

  @override
  State<DocketDetailsPage> createState() => _DocketDetailsPageState();
}

class _DocketDetailsPageState extends State<DocketDetailsPage> {
  late String _docketType; // local, so we can update UI after a successful change
  bool _updating = false;

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

  /// ---- Status helpers (AssignedTime is a STRING from DB) ----
  int get _status {
    final raw = widget.docket.AssignedTime; // <-- string from DB
    final s = raw?.toString().trim() ?? '0';
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

  IconData get _statusIcon {
    switch (_status) {
      case 0:
        return Icons.pending_outlined;
      case 1:
        return Icons.assignment_turned_in_outlined;
      case 2:
        return Icons.check_circle_outline;
      case 3:
        return Icons.restart_alt;
      case 4:
        return Icons.report_problem_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Color get _statusColorBg {
    switch (_status) {
      case 0:
        return Colors.blueGrey.shade100;
      case 1:
        return Colors.blue.shade100;
      case 2:
        return Colors.green.shade100;
      case 3:
        return Colors.orange.shade100;
      case 4:
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color get _statusColorFg {
    switch (_status) {
      case 0:
        return Colors.blueGrey.shade900;
      case 1:
        return Colors.blue.shade900;
      case 2:
        return Colors.green.shade900;
      case 3:
        return Colors.orange.shade900;
      case 4:
        return Colors.red.shade900;
      default:
        return Colors.grey.shade800;
    }
  }

  bool get _canChangeTypeByStatus => _status == 0; // only Unassigned can change

  @override
  void initState() {
    super.initState();
    _docketType = widget.docket.docketType;
  }

  String _typeFolder(String t) {
    final s = t.toLowerCase().trim();
    if (s == 'service line maintenance' || s == 'service line maintainance') return '1';
    if (s == 'meter testing') return '2';
    if (s == 'estimate') return '3';
    return '4'; // default
  }

  String _ensureJpg(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg')) return name;
    if (lower.endsWith('.jpeg')) return name.substring(0, name.length - 5) + '.jpg';
    // if your server truly only serves .jpg, force it; otherwise keep as-is for png/webp:
    return name.endsWith('.png') || name.endsWith('.webp') ? name : '$name.jpg';
  }

  String get _imageUrl {
    final dir = _typeFolder(widget.docket.docketType);
    final file = Uri.encodeComponent(_ensureJpg(widget.docket.imageName));
    return 'http://124.43.181.243:8000/api/fetch-testdocket-image/$dir/$file';
  }

  Future<void> _changeDocketType(BuildContext context) async {
    // Hard lock: type change is only allowed while Unassigned.
    if (!_canChangeTypeByStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Type change is locked for status "${_statusLabel}".'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final ua = context.read<UserAccess>();
    final hasEditAccess = (ua.accessLevel ?? 99) < 5;
    if (!hasEditAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to change type')),
      );
      return;
    }

    String temp = _docketType;

    final newType = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Change Docket Type',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: temp,
                    items: _allDocketTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => temp = v ?? temp,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Docket Type',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, temp),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (newType == null || newType == _docketType) return;

    setState(() => _updating = true);

    final updatedBy = ua.username ?? ua.employeeNumber ?? ua.uuid ?? 'Unknown';
    final ok = await DocketUpdateApi.updateDocketType(
      id: widget.docket.id,
      newType: newType,
      uploadedBy: updatedBy,
    );

    if (!mounted) return;
    setState(() => _updating = false);

    if (ok) {
      setState(() => _docketType = newType);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Docket type updated'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ua = context.watch<UserAccess>();
    final hasEditAccess = (ua.accessLevel ?? 99) < 5;
    final canEditType = hasEditAccess && _canChangeTypeByStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Docket Details'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          // Status chip in the AppBar for quick glance
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColorBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(_statusIcon, size: 16, color: _statusColorFg),
                  const SizedBox(width: 6),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColorFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_updating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Image.network(
                          _imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Center(child: Text('Image not available')),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Head card (Type, Depot, Serial, Status)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Docket Type line (locked if not Unassigned)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(Icons.widgets, color: Color(0xFF003366)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _docketType,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF003366),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: _canChangeTypeByStatus
                                      ? 'Change type'
                                      : 'Type change locked for "${_statusLabel}"',
                                  onPressed: canEditType ? () => _changeDocketType(context) : null,
                                  icon: const Icon(Icons.edit),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ChipInfo(icon: Icons.factory, label: 'Depot', value: widget.docket.depot),
                                _ChipInfo(icon: Icons.tag, label: 'Serial', value: widget.docket.docketSerial),
                                _ChipInfo(icon: _statusIcon, label: 'Status', value: _statusLabel,
                                    bg: _statusColorBg, fg: _statusColorFg),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Details list
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          _InfoTile(
                            icon: Icons.person_outline,
                            label: 'Uploaded By',
                            value: widget.docket.uploadedBy,
                          ),
                          _InfoTile(
                            icon: Icons.schedule,
                            label: 'Uploaded Time',
                            value: widget.docket.uploadedTime,
                          ),
                          _InfoTile(
                            icon: Icons.assignment_ind_outlined,
                            label: 'Assigned To',
                            value: widget.docket.assignedTo,
                          ),
                          _InfoTile(
                            icon: Icons.access_time,
                            label: 'Assigned Time',
                            value: widget.docket.AssignedTime,
                          ),
                          _InfoTile(
                            icon: Icons.check_circle_outline,
                            label: 'Completed Time',
                            value: widget.docket.completedTime,
                          ),
                          _InfoTile(
                            icon: Icons.location_on_outlined,
                            label: 'Location Details',
                            value: widget.docket.locationDetails,
                            hideIfEmpty: true,
                          ),
                          if (widget.docket.transformerNumber.isNotEmpty ||
                              widget.docket.poleNumber.isNotEmpty ||
                              widget.docket.meterShiftDetails.isNotEmpty)
                            const Divider(height: 1),
                          if (widget.docket.transformerNumber.isNotEmpty)
                            _InfoTile(
                              icon: Icons.transform,
                              label: 'Transformer',
                              value: widget.docket.transformerNumber,
                            ),
                          if (widget.docket.poleNumber.isNotEmpty)
                            _InfoTile(
                              icon: Icons.electric_bolt_outlined,
                              label: 'Pole',
                              value: widget.docket.poleNumber,
                            ),
                          if (widget.docket.meterShiftDetails.isNotEmpty)
                            _InfoTile(
                              icon: Icons.swap_horiz,
                              label: 'Meter Shift',
                              value: widget.docket.meterShiftDetails,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Small pill chip used in header section
class _ChipInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? bg;
  final Color? fg;

  const _ChipInfo({
    required this.icon,
    required this.label,
    required this.value,
    this.bg,
    this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final show = (value).toString().trim().isNotEmpty;
    if (!show) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg ?? const Color(0xFF003366)),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: fg ?? const Color(0xFF003366),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon + label + value list row (nicer than plain text rows)
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool hideIfEmpty;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.hideIfEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.isEmpty ? '—' : value;
    if (hideIfEmpty && value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: false,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFFEAF0F7),
        child: Icon(icon, size: 18, color: const Color(0xFF003366)),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(v),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}


//v2
// // lib/pages/viewDockets/docket_details_page.dart
// import 'package:flutter/material.dart';
// import 'package:leco_docket_tracker/pages/viewDockets/updateDockets/httpUpdateDocketassignment.dart';
// import 'package:provider/provider.dart';
//
// import '../../models/dockets.dart';
// import '../loginScreen/fetchUserAccess.dart';
//
//
// class DocketDetailsPage extends StatefulWidget {
//   final Docket docket;
//
//   const DocketDetailsPage({super.key, required this.docket});
//
//   @override
//   State<DocketDetailsPage> createState() => _DocketDetailsPageState();
// }
//
// class _DocketDetailsPageState extends State<DocketDetailsPage> {
//   late String _docketType; // local, so we can update UI after a successful change
//   bool _updating = false;
//
//   // Keep it consistent with your app
//   static const List<String> _allDocketTypes = [
//     'Service Line Maintenance',
//     'Meter Testing',
//     'Estimate',
//     'Per Visit',
//     'Pole Disconnection',
//     'Material Remove',
//     'Meter Replacement Only',
//     'Visit with Contractor',
//     'Pole Top Maintenance',
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _docketType = widget.docket.docketType;
//   }
//
//
//   String _typeFolder(String t) {
//     final s = t.toLowerCase().trim();
//     if (s == 'service line maintenance' || s == 'service line maintainance') return '1';
//     if (s == 'meter testing') return '2';
//     if (s == 'estimate') return '3';
//     return '4'; // default
//   }
//
//   String _ensureJpg(String name) {
//     final lower = name.toLowerCase();
//     if (lower.endsWith('.jpg')) return name;
//     if (lower.endsWith('.jpeg')) return name.substring(0, name.length - 5) + '.jpg';
//     // if your server truly only serves .jpg, force it; otherwise keep as-is for png/webp:
//     return name.endsWith('.png') || name.endsWith('.webp') ? name : '$name.jpg';
//   }
//
//   String get _imageUrl {
//     final dir = _typeFolder(widget.docket.docketType);
//     final file = Uri.encodeComponent(_ensureJpg(widget.docket.imageName));
//     return 'http://124.43.181.243:8000/api/fetch-testdocket-image/$dir/$file';
//   }
//
//
//   Future<void> _changeDocketType(BuildContext context) async {
//     final ua = context.read<UserAccess>();
//     final canEdit = (ua.accessLevel ?? 99) < 5;
//     if (!canEdit) return;
//
//     String temp = _docketType;
//
//     final newType = await showModalBottomSheet<String>(
//       context: context,
//       isScrollControlled: true,
//       builder: (ctx) {
//         return Padding(
//           padding:
//           EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
//           child: SafeArea(
//             top: false,
//             child: Container(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Text(
//                     'Change Docket Type',
//                     style:
//                     TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//                   ),
//                   const SizedBox(height: 12),
//                   DropdownButtonFormField<String>(
//                     value: temp,
//                     items: _allDocketTypes
//                         .map((t) =>
//                         DropdownMenuItem(value: t, child: Text(t)))
//                         .toList(),
//                     onChanged: (v) => temp = v ?? temp,
//                     decoration: const InputDecoration(
//                       border: OutlineInputBorder(),
//                       labelText: 'Docket Type',
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: OutlinedButton(
//                           onPressed: () => Navigator.pop(ctx),
//                           child: const Text('Cancel'),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: ElevatedButton(
//                           onPressed: () => Navigator.pop(ctx, temp),
//                           child: const Text('Save'),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//
//     if (newType == null || newType == _docketType) return;
//
//     setState(() => _updating = true);
//
//     final updatedBy = ua.username ?? ua.employeeNumber ?? ua.uuid ?? 'Unknown';
//     final ok = await DocketUpdateApi.updateDocketType(
//       id: widget.docket.id,
//       newType: newType,
//       updatedBy: updatedBy,
//     );
//
//     if (!mounted) return;
//     setState(() => _updating = false);
//
//     if (ok) {
//       setState(() => _docketType = newType);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Docket type updated'),
//           backgroundColor: Colors.green,
//         ),
//       );
//       // Optionally notify the previous list to refresh:
//       // Navigator.pop(context, true);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Update failed'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final ua = context.watch<UserAccess>();
//     final canEditType = (ua.accessLevel ?? 99) < 5;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Docket Details'),
//         actions: [
//           if (_updating)
//             const Padding(
//               padding: EdgeInsets.only(right: 16),
//               child: Center(
//                 child: SizedBox(
//                   width: 18,
//                   height: 18,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
//               ),
//             )
//         ],
//       ),
//       body: SafeArea(
//         child: LayoutBuilder(builder: (context, c) {
//           return SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: ConstrainedBox(
//               constraints: BoxConstraints(minHeight: c.maxHeight - 32),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Image
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(12),
//                     child: AspectRatio(
//                       aspectRatio: 3 / 4,
//                       child: Image.network(
//                         _imageUrl,
//                         fit: BoxFit.cover,
//                         errorBuilder: (_, __, ___) => Container(
//                           color: Colors.grey[200],
//                           child: const Center(
//                               child: Text('Image not available')),
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//
//                   // Info card
//                   Card(
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12)),
//                     elevation: 2,
//                     child: Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         children: [
//                           _RowData('Depot', widget.docket.depot),
//                           const SizedBox(height: 8),
//
//                           // Docket type row (editable for access < 5)
//                           Row(
//                             crossAxisAlignment: CrossAxisAlignment.center,
//                             children: [
//                               const SizedBox(
//                                   width: 140,
//                                   child: Text('Docket Type',
//                                       style: TextStyle(
//                                           fontWeight: FontWeight.w600))),
//                               Expanded(
//                                 child: Text(
//                                   _docketType,
//                                   style: const TextStyle(fontSize: 16),
//                                 ),
//                               ),
//                               if (canEditType)
//                                 IconButton(
//                                   tooltip: 'Change type',
//                                   onPressed:
//                                   _updating ? null : () => _changeDocketType(context),
//                                   icon: const Icon(Icons.edit),
//                                 ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//
//                           _RowData('Uploaded By', widget.docket.uploadedBy),
//                           const SizedBox(height: 8),
//                           _RowData('Uploaded Time', widget.docket.uploadedTime),
//                           const SizedBox(height: 8),
//                           _RowData('Assigned To', widget.docket.assignedTo),
//                           const SizedBox(height: 8),
//                           _RowData('Assigned Time', widget.docket.AssignedTime),
//                           const SizedBox(height: 8),
//                           _RowData('Completed Time', widget.docket.completedTime),
//                           const SizedBox(height: 8),
//                           _RowData('Docket Serial', widget.docket.docketSerial),
//                           const SizedBox(height: 8),
//
//                           // Parsed location details (if you added them to model)
//                           if (widget.docket.transformerNumber.isNotEmpty ||
//                               widget.docket.poleNumber.isNotEmpty ||
//                               widget.docket.meterShiftDetails.isNotEmpty) ...[
//                             const Divider(height: 24),
//                             _RowData('Transformer', widget.docket.transformerNumber),
//                             const SizedBox(height: 8),
//                             _RowData('Pole', widget.docket.poleNumber),
//                             const SizedBox(height: 8),
//                             _RowData('Meter Shift', widget.docket.meterShiftDetails),
//                           ],
//
//                           // Raw location string
//                           if (widget.docket.locationDetails.isNotEmpty) ...[
//                             const Divider(height: 24),
//                             _RowData('Location Details', widget.docket.locationDetails),
//                           ],
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }),
//       ),
//     );
//   }
// }
//
// class _RowData extends StatelessWidget {
//   final String label;
//   final String value;
//
//   const _RowData(this.label, this.value);
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: 140,
//           child: Text(label,
//               style:
//               const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
//         ),
//         Expanded(
//           child: Text(
//             value.isEmpty ? '—' : value,
//             style: const TextStyle(fontSize: 16),
//           ),
//         ),
//       ],
//     );
//   }
// }


//v1
// import 'package:flutter/material.dart';
// import '../../models/dockets.dart';
//
// class DocketDetailPage extends StatelessWidget {
//   final Docket docket;
//
//   const DocketDetailPage({super.key, required this.docket});
//
//   int _dirForType(String type) {
//     switch (type.toLowerCase()) {
//       case 'service line maintenance':
//         return 1;
//       case 'meter testing':
//         return 2;
//       case 'estimate':
//         return 3;
//       default:
//         return 4;
//     }
//   }
//
//   String _imageUrl() {
//     final dir = _dirForType(docket.docketType ?? '');
//     final file = docket.imageName ?? '';
//     return 'http://124.43.181.243:8000/api/fetch-testdocket-image/$dir/$file';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final rows = <_RowData>[
//       _RowData('Depot', docket.depot),
//       _RowData('Docket Type', docket.docketType),
//       _RowData('Image Name', docket.imageName),
//       _RowData('Uploaded By', docket.uploadedBy),
//       _RowData('Uploaded Time', docket.uploadedTime),
//       _RowData('Assigned To', docket.assignedTo),
//       // _RowData('Location Details', docket.locationDetails),
//       _RowData('Docket Serial', docket.docketSerial),
//       // inside your rows list:
//       _RowData('Transformer', docket.transformerNumber),
//       _RowData('Pole', docket.poleNumber),
//       _RowData('Meter Shift', docket.meterShiftDetails),
//       _RowData('Location Details (raw)', docket.locationDetails),
//
//       _RowData('ID', docket.id?.toString()),
//     ];
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Docket Details'),
//         backgroundColor: const Color(0xFF003366),
//         foregroundColor: Colors.white,
//       ),
//       body: SafeArea(
//         child: ListView(
//           padding: const EdgeInsets.all(16),
//           children: [
//             ClipRRect(
//               borderRadius: BorderRadius.circular(12),
//               child: AspectRatio(
//                 aspectRatio: 3 / 4,
//                 child: Image.network(
//                   _imageUrl(),
//                   fit: BoxFit.cover,
//                   errorBuilder: (_, __, ___) => Container(
//                     color: const Color(0xFFF1F3F6),
//                     alignment: Alignment.center,
//                     child: const Icon(Icons.broken_image, size: 48),
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//             Card(
//               elevation: 2,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   children: rows
//                       .where((r) => (r.value ?? '').isNotEmpty)
//                       .map((r) => _DetailRow(label: r.label, value: r.value!))
//                       .toList(),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _RowData {
//   final String label;
//   final String? value;
//   _RowData(this.label, this.value);
// }
//
// class _DetailRow extends StatelessWidget {
//   final String label;
//   final String value;
//   const _DetailRow({required this.label, required this.value});
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 130,
//             child: Text(label,
//                 style: const TextStyle(
//                     fontWeight: FontWeight.w600, color: Color(0xFF003366))),
//           ),
//           const SizedBox(width: 12),
//           Expanded(child: Text(value)),
//         ],
//       ),
//     );
//   }
// }
