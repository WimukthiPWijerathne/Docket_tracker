

//v4
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
//
// import '../../models/dockets.dart';
// import '../../service/dockey_service.dart';
// import '../loginScreen/fetchUserAccess.dart';
// import '../viewDockets/updateDockets/httpUpdateDockets.dart';
//
// /// Technician Portal
// /// - Assigned: dockets with AssignedTime == '1' (pending)
// /// - Completed: dockets with AssignedTime == '2'
// class TechnicianPortalPage extends StatefulWidget {
//   const TechnicianPortalPage({super.key});
//
//   @override
//   State<TechnicianPortalPage> createState() => _TechnicianPortalPageState();
// }
//
// class _TechnicianPortalPageState extends State<TechnicianPortalPage> {
//   final _svc = DocketService();
//   bool _loading = true;
//   String? _error;
//   List<Docket> _all = [];
//
//   /// Docket IDs currently assigned (reassigned=0) to the logged-in employee.
//   /// Store as String for safe comparison regardless of underlying id type.
//   final Set<String> _myAssignedIds = {};
//
//   /// Completed tab month filter: 'All' or 'yyyy-MM'
//   String _completedMonth = _monthKey(DateTime.now());
//
//   static const int _criticalDays = 2;
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }
//
//   // ---------- Load ----------
//   Future<void> _load() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//
//     // Who is logged in?
//     final ua = Provider.of<UserAccess>(context, listen: false);
//     final me = (ua.employeeNumber ?? '').trim();
//     debugPrint('[TechPortal] logged-in: empNo="$me", '
//         'name="${ua.username}", depot="${ua.depot}", level=${ua.accessLevel}');
//
//     try {
//       // 1) Load all dockets (for card data)
//       final data = await _svc.fetchDockets();
//
//       // 2) Load assignments for *me* (reassigned=0 -> status=0 in your service)
//       final mine = await _svc.fetchAssignedDocketsForEmployee(me, status: 0);
//
//       setState(() {
//         _all = data;
//         _myAssignedIds
//           ..clear()
//           ..addAll(mine.map((d) => '${d.id}'));
//         _loading = false;
//       });
//
//       debugPrint('[TechPortal] myAssignedIds sample: '
//           '${_myAssignedIds.take(10).toList()} (total ${_myAssignedIds.length})');
//     } catch (e) {
//       setState(() {
//         _error = 'Failed to load dockets: $e';
//         _loading = false;
//         _all = [];
//         _myAssignedIds.clear();
//       });
//     }
//   }
//
//   // ---------- Helpers / Filters ----------
//   static DateTime _parseTs(String? ts) {
//     if (ts == null || ts.trim().isEmpty) {
//       return DateTime.fromMillisecondsSinceEpoch(0);
//     }
//     final s = ts.trim();
//     try {
//       return DateTime.parse(s.replaceAll('/', '-'));
//     } catch (_) {
//       try {
//         return DateFormat('yyyy-MM-dd HH:mm:ss').parse(s);
//       } catch (_) {
//         try {
//           return DateFormat('yyyy-MM-dd').parse(s);
//         } catch (_) {
//           return DateTime.fromMillisecondsSinceEpoch(0);
//         }
//       }
//     }
//   }
//
//   static String _monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
//
//   static String _prettyDate(DateTime d) =>
//       d.millisecondsSinceEpoch == 0
//           ? '-'
//           : DateFormat('yyyy-MM-dd HH:mm').format(d);
//
//   /// Now we decide "assigned to me" by checking membership in _myAssignedIds.
//   bool _assignedToMe(Docket d) => _myAssignedIds.contains('${d.id}');
//
//   List<Docket> _myAssignedPending() {
//     return _all.where((d) {
//       final status = (d.AssignedTime ?? '0').trim();
//       return status == '1' && _assignedToMe(d);
//     }).toList()
//       ..sort((a, b) {
//         final at = _parseTs(a.uploadedTime);
//         final bt = _parseTs(b.uploadedTime);
//         return at.compareTo(bt);
//       });
//   }
//
//   List<Docket> _myCompletedForMonth(String monthKey) {
//     final src = _all.where((d) {
//       final status = (d.AssignedTime ?? '0').trim();
//       if (status != '2') return false;
//       return _assignedToMe(d);
//     });
//     if (monthKey == 'All') {
//       return src.toList()
//         ..sort((a, b) =>
//             _parseTs(b.completedTime).compareTo(_parseTs(a.completedTime)));
//     }
//     return src
//         .where((d) => _monthKey(_parseTs(d.completedTime)) == monthKey)
//         .toList()
//       ..sort((a, b) =>
//           _parseTs(b.completedTime).compareTo(_parseTs(a.completedTime)));
//   }
//
//   ({int total, int completed, int pending}) _summaryForMonth(String monthKey) {
//     final mine = _all.where((d) => _assignedToMe(d));
//     final monthSet = monthKey == 'All'
//         ? mine
//         : mine.where(
//           (d) => _monthKey(_parseTs(d.uploadedTime)) == monthKey,
//     );
//
//     int total = 0, completed = 0, pending = 0;
//     for (final d in monthSet) {
//       total++;
//       final s = (d.AssignedTime ?? '0').trim();
//       if (s == '2') {
//         completed++;
//       } else if (s == '1') {
//         pending++;
//       }
//     }
//     return (total: total, completed: completed, pending: pending);
//   }
//
//   List<String> _availableMonths() {
//     final set = <String>{};
//     for (final d in _all) {
//       if (_assignedToMe(d)) {
//         final k1 = _monthKey(_parseTs(d.completedTime));
//         if (k1 != _monthKey(DateTime.fromMillisecondsSinceEpoch(0))) {
//           set.add(k1);
//         }
//         final k2 = _monthKey(_parseTs(d.uploadedTime));
//         if (k2 != _monthKey(DateTime.fromMillisecondsSinceEpoch(0))) {
//           set.add(k2);
//         }
//       }
//     }
//     final list = set.toList()..sort();
//     // Ensure current month exists for UX
//     final nowKey = _monthKey(DateTime.now());
//     if (!list.contains(nowKey)) list.add(nowKey);
//     list.sort();
//     return ['All', ...{...list}];
//   }
//
//   // ---------- Actions ----------
//   Future<bool> _markComplete(Docket d) async {
//     final ok = await DocketUpdateApi.updateFields(id: d.id, fields: {
//       'AssignedTime': '2',
//       'completedTime': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
//     });
//     return ok;
//   }
//
//   Future<bool> _escalate(Docket d, {required String reason}) async {
//     final ok = await DocketUpdateApi.updateFields(id: d.id, fields: {
//       'AssignedTime': '4',
//       'locationDetails': ((d.locationDetails ?? '').trim().isEmpty)
//           ? '[Escalated] $reason'
//           : '${d.locationDetails}\n[Escalated] $reason',
//     });
//     return ok;
//   }
//
//   // ---------- UI ----------
//   @override
//   Widget build(BuildContext context) {
//     final myEmpNo =
//         Provider.of<UserAccess>(context, listen: false).employeeNumber ?? '';
//
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Technician'),
//           backgroundColor: const Color(0xFF003366),
//           foregroundColor: Colors.white,
//           actions: [
//             IconButton(
//               tooltip: 'Refresh',
//               onPressed: _load,
//               icon: const Icon(Icons.refresh),
//             ),
//           ],
//           bottom: const TabBar(
//             indicatorColor: Colors.white,
//             indicatorWeight: 3,
//             labelColor: Colors.white,
//             unselectedLabelColor: Colors.white70,
//             tabs: [
//               Tab(text: 'Assigned'),
//               Tab(text: 'Completed'),
//             ],
//           ),
//         ),
//         body: SafeArea(
//           child: _loading
//               ? const Center(child: CircularProgressIndicator())
//               : _error != null
//               ? _ErrorView(message: _error!, onRetry: _load)
//               : myEmpNo.trim().isEmpty
//               ? const _ErrorView(
//             message:
//             'Your employee number is missing. Please sign in again or contact admin.',
//           )
//               : TabBarView(
//             children: [
//               _AssignedTab(
//                 assigned: _myAssignedPending(),
//                 monthKey: _monthKey(DateTime.now()),
//                 summary:
//                 _summaryForMonth(_monthKey(DateTime.now())),
//                 onOpenWork: _openWorkSheet,
//               ),
//               _CompletedTab(
//                 all: _all,
//                 months: _availableMonths(),
//                 selectedMonth: _completedMonth,
//                 onMonthChanged: (m) =>
//                     setState(() => _completedMonth = m),
//                 itemsForMonth:
//                 _myCompletedForMonth(_completedMonth),
//                 summary: _summaryForMonth(_completedMonth),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Bottom sheet: photos + actions
//   Future<void> _openWorkSheet(Docket d) async {
//     final picker = ImagePicker();
//     XFile? before;
//     XFile? after;
//     final List<XFile> extra = [];
//     String extraComment = '';
//     bool saving = false;
//
//     // ignore: use_build_context_synchronously
//     await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       useSafeArea: true,
//       builder: (ctx) {
//         return StatefulBuilder(
//           builder: (ctx, setSheet) {
//             final canEscalate =
//             (before != null || after != null || extra.isNotEmpty);
//             final canComplete = (before != null && after != null);
//             return Padding(
//               padding: EdgeInsets.only(
//                 left: 16,
//                 right: 16,
//                 bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
//                 top: 16,
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Row(
//                     children: [
//                       const Icon(Icons.home_repair_service,
//                           color: Color(0xFF003366)),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           d.docketType,
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w700,
//                             fontSize: 16,
//                             color: Color(0xFF003366),
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                       IconButton(
//                         onPressed: () => Navigator.pop(ctx),
//                         icon: const Icon(Icons.close),
//                       )
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   const Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text('Please capture work photos',
//                         style: TextStyle(color: Colors.black54)),
//                   ),
//                   const SizedBox(height: 12),
//
//                   _PhotoRow(
//                     label: 'Before work',
//                     file: before,
//                     onTake: () async {
//                       before = await picker.pickImage(
//                         source: ImageSource.camera,
//                         imageQuality: 80,
//                       );
//                       setSheet(() {});
//                     },
//                     requiredMark: true,
//                   ),
//                   const SizedBox(height: 10),
//                   _PhotoRow(
//                     label: 'After work',
//                     file: after,
//                     onTake: () async {
//                       after = await picker.pickImage(
//                         source: ImageSource.camera,
//                         imageQuality: 80,
//                       );
//                       setSheet(() {});
//                     },
//                     requiredMark: true,
//                   ),
//                   const SizedBox(height: 10),
//                   _PhotoRow.multi(
//                     label: 'Additional photo(s)',
//                     files: extra,
//                     onTake: () async {
//                       final x = await picker.pickImage(
//                         source: ImageSource.camera,
//                         imageQuality: 80,
//                       );
//                       if (x != null) extra.add(x);
//                       setSheet(() {});
//                     },
//                   ),
//                   const SizedBox(height: 10),
//                   TextField(
//                     minLines: 1,
//                     maxLines: 3,
//                     onChanged: (v) => extraComment = v,
//                     decoration: const InputDecoration(
//                       labelText:
//                       'Additional comment (required if adding extras)',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//
//                   Row(
//                     children: [
//                       Expanded(
//                         child: OutlinedButton.icon(
//                           onPressed: !canEscalate || saving
//                               ? null
//                               : () async {
//                             if (extra.isNotEmpty &&
//                                 extraComment.trim().isEmpty) {
//                               ScaffoldMessenger.of(ctx).showSnackBar(
//                                 const SnackBar(
//                                   content: Text(
//                                       'Please add a comment for additional photo(s).'),
//                                 ),
//                               );
//                               return;
//                             }
//                             setSheet(() => saving = true);
//                             // TODO: upload photos via SFTP
//                             final ok = await _escalate(d,
//                                 reason: extraComment.trim());
//                             setSheet(() => saving = false);
//                             if (!mounted) return;
//                             if (ok) {
//                               Navigator.pop(ctx);
//                               await _load();
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 const SnackBar(
//                                   content: Text('Escalated'),
//                                   backgroundColor: Colors.orange,
//                                 ),
//                               );
//                             } else {
//                               ScaffoldMessenger.of(ctx).showSnackBar(
//                                 const SnackBar(
//                                   content: Text('Escalation failed'),
//                                   backgroundColor: Colors.red,
//                                 ),
//                               );
//                             }
//                           },
//                           icon: const Icon(Icons.flag),
//                           label: const Text('Escalate'),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           onPressed: !canComplete || saving
//                               ? null
//                               : () async {
//                             setSheet(() => saving = true);
//                             // TODO: upload photos via SFTP
//                             final ok = await _markComplete(d);
//                             setSheet(() => saving = false);
//                             if (!mounted) return;
//                             if (ok) {
//                               Navigator.pop(ctx);
//                               await _load();
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 const SnackBar(
//                                   content: Text('Marked complete'),
//                                   backgroundColor: Colors.green,
//                                 ),
//                               );
//                             } else {
//                               ScaffoldMessenger.of(ctx).showSnackBar(
//                                 const SnackBar(
//                                   content: Text('Update failed'),
//                                   backgroundColor: Colors.red,
//                                 ),
//                               );
//                             }
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF003366),
//                             foregroundColor: Colors.white,
//                           ),
//                           icon: const Icon(Icons.check_circle),
//                           label: const Text('Mark complete'),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
// }
//
// // ---------- Assigned Tab ----------
// class _AssignedTab extends StatelessWidget {
//   final List<Docket> assigned;
//   final String monthKey;
//   final ({int total, int completed, int pending}) summary;
//   final void Function(Docket d) onOpenWork;
//
//   const _AssignedTab({
//     required this.assigned,
//     required this.monthKey,
//     required this.summary,
//     required this.onOpenWork,
//   });
//
//   static DateTime _parseTs(String? s) =>
//       _TechnicianPortalPageState._parseTs(s);
//
//   @override
//   Widget build(BuildContext context) {
//     final chips = _SummaryChips(
//       total: summary.total,
//       completed: summary.completed,
//       pending: summary.pending,
//     );
//
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
//           child: chips,
//         ),
//         Expanded(
//           child: assigned.isEmpty
//               ? const _EmptyView(
//             icon: Icons.inbox,
//             title: 'No assigned jobs',
//             subtitle: 'You have no pending work right now.',
//           )
//               : ListView.separated(
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//             itemBuilder: (_, i) {
//               final d = assigned[i];
//               final up = _parseTs(d.uploadedTime);
//               final days = DateTime.now().difference(up).inDays;
//               final critical =
//                   days >= _TechnicianPortalPageState._criticalDays;
//               return _AssignedCard(
//                 docket: d,
//                 uploadedAt: up,
//                 pendingDays: days,
//                 critical: critical,
//                 onTap: () => onOpenWork(d),
//               );
//             },
//             separatorBuilder: (_, __) => const SizedBox(height: 10),
//             itemCount: assigned.length,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// class _AssignedCard extends StatelessWidget {
//   final Docket docket;
//   final DateTime uploadedAt;
//   final int pendingDays;
//   final bool critical;
//   final VoidCallback onTap;
//
//   const _AssignedCard({
//     required this.docket,
//     required this.uploadedAt,
//     required this.pendingDays,
//     required this.critical,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final dueText = pendingDays <= 0
//         ? 'Due today'
//         : 'Pending $pendingDays day${pendingDays == 1 ? '' : 's'}';
//     final badgeColor = critical ? Colors.red : const Color(0xFF003366);
//
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(14),
//         child: Padding(
//           padding: const EdgeInsets.all(14),
//           child: Row(
//             children: [
//               const CircleAvatar(
//                 radius: 22,
//                 backgroundColor: Color(0xFFE8EEF6),
//                 child: Icon(Icons.assignment, color: Color(0xFF003366)),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       docket.docketType,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                           fontWeight: FontWeight.w700,
//                           fontSize: 16,
//                           color: Color(0xFF003366)),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       'Depot: ${docket.depot} • Serial: ${docket.docketSerial}',
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(color: Colors.black87),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       'Uploaded: ${_TechnicianPortalPageState._prettyDate(uploadedAt)}',
//                       style: const TextStyle(
//                           color: Colors.black54, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Container(
//                 padding:
//                 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: badgeColor.withOpacity(0.1),
//                   border: Border.all(color: badgeColor.withOpacity(0.3)),
//                   borderRadius: BorderRadius.circular(999),
//                 ),
//                 child: Text(
//                   dueText,
//                   style: TextStyle(
//                     color: badgeColor,
//                     fontWeight: FontWeight.w700,
//                     fontSize: 12,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ---------- Completed Tab ----------
// class _CompletedTab extends StatelessWidget {
//   final List<Docket> all;
//   final List<String> months; // 'All', 'yyyy-MM'
//   final String selectedMonth;
//   final ValueChanged<String> onMonthChanged;
//   final List<Docket> itemsForMonth;
//   final ({int total, int completed, int pending}) summary;
//
//   const _CompletedTab({
//     required this.all,
//     required this.months,
//     required this.selectedMonth,
//     required this.onMonthChanged,
//     required this.itemsForMonth,
//     required this.summary,
//   });
//
//   static DateTime _parseTs(String? s) =>
//       _TechnicianPortalPageState._parseTs(s);
//
//   @override
//   Widget build(BuildContext context) {
//     final chips = _SummaryChips(
//       total: summary.total,
//       completed: summary.completed,
//       pending: summary.pending,
//     );
//
//     // guard the dropdown against a value not present in items
//     final safeValue =
//     months.contains(selectedMonth) ? selectedMonth : months.first;
//
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
//           child: Row(
//             children: [
//               Expanded(child: chips),
//               const SizedBox(width: 12),
//               SizedBox(
//                 width: 170,
//                 child: DropdownButtonFormField<String>(
//                   value: safeValue,
//                   items: months
//                       .map(
//                         (m) => DropdownMenuItem(
//                       value: m,
//                       child: Text(
//                         m == 'All'
//                             ? 'All months'
//                             : DateFormat('MMM yyyy').format(
//                             DateFormat('yyyy-MM').parse(m)),
//                       ),
//                     ),
//                   )
//                       .toList(),
//                   onChanged: (String? v) {
//                     if (v != null) onMonthChanged(v);
//                   },
//                   decoration: const InputDecoration(
//                     labelText: 'Month',
//                     border: OutlineInputBorder(),
//                     contentPadding:
//                     EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Expanded(
//           child: itemsForMonth.isEmpty
//               ? const _EmptyView(
//             icon: Icons.inbox,
//             title: 'No completed jobs',
//             subtitle: 'Nothing completed for the selected month.',
//           )
//               : ListView.separated(
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//             itemCount: itemsForMonth.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 10),
//             itemBuilder: (_, i) {
//               final d = itemsForMonth[i];
//               final cAt = _parseTs(d.completedTime);
//               return Card(
//                 elevation: 1.5,
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12)),
//                 child: ListTile(
//                   leading: const CircleAvatar(
//                     backgroundColor: Color(0xFFE8EEF6),
//                     child: Icon(Icons.check, color: Color(0xFF003366)),
//                   ),
//                   title: Text(
//                     d.docketType,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                         fontWeight: FontWeight.w700,
//                         color: Color(0xFF003366)),
//                   ),
//                   subtitle: Text(
//                     'Depot: ${d.depot} • Serial: ${d.docketSerial}\n'
//                         'Completed: ${_TechnicianPortalPageState._prettyDate(cAt)}',
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ---------- Shared UI ----------
// class _SummaryChips extends StatelessWidget {
//   final int total, completed, pending;
//   const _SummaryChips(
//       {required this.total, required this.completed, required this.pending});
//
//   @override
//   Widget build(BuildContext context) {
//     Widget chip(String title, int count, Color color) => Container(
//       margin: const EdgeInsets.only(right: 8, bottom: 8),
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.08),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.18)),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(title,
//               style: TextStyle(
//                   color: color, fontWeight: FontWeight.w600, fontSize: 13)),
//           const SizedBox(width: 8),
//           Container(
//             padding:
//             const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
//             decoration: BoxDecoration(
//               color: color,
//               borderRadius: BorderRadius.circular(999),
//             ),
//             child: Text(
//               '$count',
//               style: const TextStyle(
//                   color: Colors.white, fontWeight: FontWeight.bold),
//             ),
//           ),
//         ],
//       ),
//     );
//
//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: Row(
//         children: [
//           chip('Total', total, Colors.blueGrey),
//           chip('Completed', completed, Colors.green.shade700),
//           chip('Pending', pending, const Color(0xFF003366)),
//         ],
//       ),
//     );
//   }
// }
//
// class _PhotoRow extends StatelessWidget {
//   final String label;
//   final XFile? file;
//   final List<XFile>? files;
//   final VoidCallback onTake;
//   final bool requiredMark;
//
//   const _PhotoRow({
//     required this.label,
//     required this.file,
//     required this.onTake,
//     this.requiredMark = false,
//   }) : files = null;
//
//   const _PhotoRow.multi({
//     required this.label,
//     required this.files,
//     required this.onTake,
//   })  : file = null,
//         requiredMark = false;
//
//   @override
//   Widget build(BuildContext context) {
//     final bool multi = files != null;
//     final count = multi ? files!.length : (file == null ? 0 : 1);
//
//     return Row(
//       children: [
//         Expanded(
//           child: Text.rich(
//             TextSpan(
//               text: label,
//               style: const TextStyle(fontWeight: FontWeight.w600),
//               children: [
//                 if (requiredMark)
//                   const TextSpan(
//                     text: ' *',
//                     style: TextStyle(color: Colors.red),
//                   ),
//                 TextSpan(
//                   text:
//                   '  •  ${count == 0 ? "No photo" : "$count photo${count > 1 ? 's' : ''}"}',
//                   style: const TextStyle(
//                       color: Colors.black54, fontWeight: FontWeight.w400),
//                 )
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(width: 8),
//         OutlinedButton.icon(
//           onPressed: onTake,
//           icon: const Icon(Icons.photo_camera),
//           label: const Text('Take'),
//         ),
//       ],
//     );
//   }
// }
//
// class _EmptyView extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String? subtitle;
//   const _EmptyView({required this.icon, required this.title, this.subtitle});
//
//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       physics: const AlwaysScrollableScrollPhysics(),
//       children: [
//         SizedBox(height: MediaQuery.of(context).size.height * 0.2),
//         Icon(icon, size: 64, color: Colors.black26),
//         const SizedBox(height: 12),
//         Text(title,
//             textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
//         if (subtitle != null) ...[
//           const SizedBox(height: 6),
//           Text(subtitle!,
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: Colors.black54)),
//         ],
//       ],
//     );
//   }
// }
//
// class _ErrorView extends StatelessWidget {
//   final String message;
//   final Future<void> Function()? onRetry;
//   const _ErrorView({required this.message, this.onRetry});
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
//             const SizedBox(height: 12),
//             Text(message, textAlign: TextAlign.center),
//             if (onRetry != null) ...[
//               const SizedBox(height: 12),
//               ElevatedButton(
//                 onPressed: onRetry,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF003366),
//                   foregroundColor: Colors.white,
//                 ),
//                 child: const Text('Retry'),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }


//v3
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
//
// import '../../models/dockets.dart';
// import '../../service/dockey_service.dart';
// import '../loginScreen/fetchUserAccess.dart';
// import '../viewDockets/updateDockets/httpUpdateDockets.dart';
//
// /// Technician Portal
// /// - Assigned: dockets with AssignedTime == '1' (pending)
// /// - Completed: dockets with AssignedTime == '2'
// /// Filtering to *this* tech is done via a simple helper that checks a
// /// comma-separated `assignedTo` string if your model provides it.
// /// (If `assignedTo` is empty in your feed, this will still work but
// /// will not filter per-user; you can wire it to DocketAssignment later.)
// class TechnicianPortalPage extends StatefulWidget {
//   const TechnicianPortalPage({super.key});
//
//   @override
//   State<TechnicianPortalPage> createState() => _TechnicianPortalPageState();
// }
//
// class _TechnicianPortalPageState extends State<TechnicianPortalPage> {
//   final _svc = DocketService();
//   bool _loading = true;
//   String? _error;
//   List<Docket> _all = [];
//
//   /// Completed tab month filter: 'All' or 'yyyy-MM'
//   String _completedMonth = _monthKey(DateTime.now());
//
//   static const int _criticalDays = 2;
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }
//
//   // ---------- Load ----------
//   Future<void> _load() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//
//     // DEBUG: who is logged in?
//     final ua = Provider.of<UserAccess>(context, listen: false);
//     final me = (ua.employeeNumber ?? '').trim();
//     debugPrint('[TechPortal] logged-in: empNo="$me", '
//         'name="${ua.username}", depot="${ua.depot}", level=${ua.accessLevel}');
//
//     try {
//       final data = await _svc.fetchDockets();
//       setState(() {
//         _all = data;
//         _loading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _error = 'Failed to load dockets: $e';
//         _loading = false;
//         _all = [];
//       });
//     }
//   }
//
//   // ---------- Helpers / Filters ----------
//   String get _myEmpNo =>
//       (Provider.of<UserAccess>(context, listen: false).employeeNumber ?? '')
//           .trim();
//
//   static DateTime _parseTs(String? ts) {
//     if (ts == null || ts.trim().isEmpty) {
//       return DateTime.fromMillisecondsSinceEpoch(0);
//     }
//     final s = ts.trim();
//     try {
//       return DateTime.parse(s.replaceAll('/', '-'));
//     } catch (_) {
//       try {
//         return DateFormat('yyyy-MM-dd HH:mm:ss').parse(s);
//       } catch (_) {
//         try {
//           return DateFormat('yyyy-MM-dd').parse(s);
//         } catch (_) {
//           return DateTime.fromMillisecondsSinceEpoch(0);
//         }
//       }
//     }
//   }
//
//   static String _monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
//
//   static String _prettyDate(DateTime d) =>
//       d.millisecondsSinceEpoch == 0
//           ? '-'
//           : DateFormat('yyyy-MM-dd HH:mm').format(d);
//
//   /// Very simple per-user check. If your `Docket` model has a field like
//   /// `assignedTo` (e.g., "1238,1240"), this will work. If it's always empty,
//   /// this function returns true only if `assignedTo` contains the employee no.
//   bool _assignedToMe(Docket d) {
//     final me = _myEmpNo;
//     if (me.isEmpty) return false;
//     final s = (d.assignedTo ?? '').trim();
//     if (s.isEmpty) return false;
//     return s.split(',').map((e) => e.trim()).contains(me);
//   }
//
//   List<Docket> _myAssignedPending() {
//     return _all.where((d) {
//       final status = (d.AssignedTime ?? '0').trim();
//       // Show pending (1). If you want strictly "for me", add && _assignedToMe(d)
//       return status == '1' && _assignedToMe(d);
//     }).toList()
//       ..sort((a, b) {
//         final at = _parseTs(a.uploadedTime);
//         final bt = _parseTs(b.uploadedTime);
//         return at.compareTo(bt);
//       });
//   }
//
//   List<Docket> _myCompletedForMonth(String monthKey) {
//     final src = _all.where((d) {
//       final status = (d.AssignedTime ?? '0').trim();
//       if (status != '2') return false;
//       return _assignedToMe(d);
//     });
//     if (monthKey == 'All') {
//       return src.toList()
//         ..sort((a, b) =>
//             _parseTs(b.completedTime).compareTo(_parseTs(a.completedTime)));
//     }
//     return src
//         .where((d) => _monthKey(_parseTs(d.completedTime)) == monthKey)
//         .toList()
//       ..sort((a, b) =>
//           _parseTs(b.completedTime).compareTo(_parseTs(a.completedTime)));
//   }
//
//   ({int total, int completed, int pending}) _summaryForMonth(String monthKey) {
//     final mine = _all.where((d) => _assignedToMe(d));
//     final monthSet = monthKey == 'All'
//         ? mine
//         : mine.where(
//           (d) => _monthKey(_parseTs(d.uploadedTime)) == monthKey,
//     );
//
//     int total = 0, completed = 0, pending = 0;
//     for (final d in monthSet) {
//       total++;
//       final s = (d.AssignedTime ?? '0').trim();
//       if (s == '2') {
//         completed++;
//       } else if (s == '1') {
//         pending++;
//       }
//     }
//     return (total: total, completed: completed, pending: pending);
//   }
//
//   List<String> _availableMonths() {
//     final set = <String>{};
//     for (final d in _all) {
//       if (_assignedToMe(d)) {
//         final k1 = _monthKey(_parseTs(d.completedTime));
//         if (k1 != _monthKey(DateTime.fromMillisecondsSinceEpoch(0))) {
//           set.add(k1);
//         }
//         final k2 = _monthKey(_parseTs(d.uploadedTime));
//         if (k2 != _monthKey(DateTime.fromMillisecondsSinceEpoch(0))) {
//           set.add(k2);
//         }
//       }
//     }
//     final list = set.toList()..sort();
//     // Ensure current month exists for UX
//     final nowKey = _monthKey(DateTime.now());
//     if (!list.contains(nowKey)) list.add(nowKey);
//     list.sort();
//     // Put 'All' first and make unique
//     return ['All', ...{...list}];
//   }
//
//   // ---------- Actions ----------
//   Future<bool> _markComplete(Docket d) async {
//     final ok = await DocketUpdateApi.updateFields(id: d.id, fields: {
//       'AssignedTime': '2',
//       'completedTime': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
//     });
//     return ok;
//   }
//
//   Future<bool> _escalate(Docket d, {required String reason}) async {
//     final ok = await DocketUpdateApi.updateFields(id: d.id, fields: {
//       'AssignedTime': '4',
//       'locationDetails': ((d.locationDetails ?? '').trim().isEmpty)
//           ? '[Escalated] $reason'
//           : '${d.locationDetails}\n[Escalated] $reason',
//     });
//     return ok;
//   }
//
//   // ---------- UI ----------
//   @override
//   Widget build(BuildContext context) {
//     final myEmpNo = Provider.of<UserAccess>(context, listen:false).employeeNumber!;
//     final pending =  _svc.fetchAssignedDocketsForEmployee(myEmpNo, status: 0); // reassigned=0
//
//
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Technician'),
//           backgroundColor: const Color(0xFF003366),
//           foregroundColor: Colors.white,
//           actions: [
//             IconButton(
//               tooltip: 'Refresh',
//               onPressed: _load,
//               icon: const Icon(Icons.refresh),
//             ),
//           ],
//           bottom: const TabBar(
//             indicatorColor: Colors.white,
//             indicatorWeight: 3,
//             labelColor: Colors.white,
//             unselectedLabelColor: Colors.white70,
//             tabs: [
//               Tab(text: 'Assigned'),
//               Tab(text: 'Completed'),
//             ],
//           ),
//         ),
//         body: SafeArea(
//           child: _loading
//               ? const Center(child: CircularProgressIndicator())
//               : _error != null
//               ? _ErrorView(message: _error!, onRetry: _load)
//               : myEmpNo.isEmpty
//               ? const _ErrorView(
//             message:
//             'Your employee number is missing. Please sign in again or contact admin.',
//           )
//               : TabBarView(
//             children: [
//               _AssignedTab(
//                 assigned: _myAssignedPending(),
//                 monthKey: _monthKey(DateTime.now()),
//                 summary:
//                 _summaryForMonth(_monthKey(DateTime.now())),
//                 onOpenWork: _openWorkSheet,
//               ),
//               _CompletedTab(
//                 all: _all,
//                 months: _availableMonths(),
//                 selectedMonth: _completedMonth,
//                 onMonthChanged: (m) =>
//                     setState(() => _completedMonth = m),
//                 itemsForMonth:
//                 _myCompletedForMonth(_completedMonth),
//                 summary: _summaryForMonth(_completedMonth),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Bottom sheet: photos + actions
//   Future<void> _openWorkSheet(Docket d) async {
//     final picker = ImagePicker();
//     XFile? before;
//     XFile? after;
//     final List<XFile> extra = [];
//     String extraComment = '';
//     bool saving = false;
//
//     // ignore: use_build_context_synchronously
//     await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       useSafeArea: true,
//       builder: (ctx) {
//         return StatefulBuilder(
//           builder: (ctx, setSheet) {
//             final canEscalate =
//             (before != null || after != null || extra.isNotEmpty);
//             final canComplete = (before != null && after != null);
//             return Padding(
//               padding: EdgeInsets.only(
//                 left: 16,
//                 right: 16,
//                 bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
//                 top: 16,
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Row(
//                     children: [
//                       const Icon(Icons.home_repair_service,
//                           color: Color(0xFF003366)),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           d.docketType,
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w700,
//                             fontSize: 16,
//                             color: Color(0xFF003366),
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                       IconButton(
//                         onPressed: () => Navigator.pop(ctx),
//                         icon: const Icon(Icons.close),
//                       )
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   const Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text('Please capture work photos',
//                         style: TextStyle(color: Colors.black54)),
//                   ),
//                   const SizedBox(height: 12),
//
//                   _PhotoRow(
//                     label: 'Before work',
//                     file: before,
//                     onTake: () async {
//                       before = await picker.pickImage(
//                         source: ImageSource.camera,
//                         imageQuality: 80,
//                       );
//                       setSheet(() {});
//                     },
//                     requiredMark: true,
//                   ),
//                   const SizedBox(height: 10),
//                   _PhotoRow(
//                     label: 'After work',
//                     file: after,
//                     onTake: () async {
//                       after = await picker.pickImage(
//                         source: ImageSource.camera,
//                         imageQuality: 80,
//                       );
//                       setSheet(() {});
//                     },
//                     requiredMark: true,
//                   ),
//                   const SizedBox(height: 10),
//                   _PhotoRow.multi(
//                     label: 'Additional photo(s)',
//                     files: extra,
//                     onTake: () async {
//                       final x = await picker.pickImage(
//                         source: ImageSource.camera,
//                         imageQuality: 80,
//                       );
//                       if (x != null) extra.add(x);
//                       setSheet(() {});
//                     },
//                   ),
//                   const SizedBox(height: 10),
//                   TextField(
//                     minLines: 1,
//                     maxLines: 3,
//                     onChanged: (v) => extraComment = v,
//                     decoration: const InputDecoration(
//                       labelText:
//                       'Additional comment (required if adding extras)',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//
//                   Row(
//                     children: [
//                       Expanded(
//                         child: OutlinedButton.icon(
//                           onPressed: !canEscalate || saving
//                               ? null
//                               : () async {
//                             if (extra.isNotEmpty &&
//                                 extraComment.trim().isEmpty) {
//                               ScaffoldMessenger.of(ctx).showSnackBar(
//                                 const SnackBar(
//                                   content: Text(
//                                       'Please add a comment for additional photo(s).'),
//                                 ),
//                               );
//                               return;
//                             }
//                             setSheet(() => saving = true);
//                             // TODO: upload photos via SFTP
//                             final ok = await _escalate(d,
//                                 reason: extraComment.trim());
//                             setSheet(() => saving = false);
//                             if (!mounted) return;
//                             if (ok) {
//                               Navigator.pop(ctx);
//                               await _load();
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 const SnackBar(
//                                   content: Text('Escalated'),
//                                   backgroundColor: Colors.orange,
//                                 ),
//                               );
//                             } else {
//                               ScaffoldMessenger.of(ctx).showSnackBar(
//                                 const SnackBar(
//                                   content: Text('Escalation failed'),
//                                   backgroundColor: Colors.red,
//                                 ),
//                               );
//                             }
//                           },
//                           icon: const Icon(Icons.flag),
//                           label: const Text('Escalate'),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           onPressed: !canComplete || saving
//                               ? null
//                               : () async {
//                             setSheet(() => saving = true);
//                             // TODO: upload photos via SFTP
//                             final ok = await _markComplete(d);
//                             setSheet(() => saving = false);
//                             if (!mounted) return;
//                             if (ok) {
//                               Navigator.pop(ctx);
//                               await _load();
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 const SnackBar(
//                                   content: Text('Marked complete'),
//                                   backgroundColor: Colors.green,
//                                 ),
//                               );
//                             } else {
//                               ScaffoldMessenger.of(ctx).showSnackBar(
//                                 const SnackBar(
//                                   content: Text('Update failed'),
//                                   backgroundColor: Colors.red,
//                                 ),
//                               );
//                             }
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF003366),
//                             foregroundColor: Colors.white,
//                           ),
//                           icon: const Icon(Icons.check_circle),
//                           label: const Text('Mark complete'),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
// }
//
// // ---------- Assigned Tab ----------
// class _AssignedTab extends StatelessWidget {
//   final List<Docket> assigned;
//   final String monthKey;
//   final ({int total, int completed, int pending}) summary;
//   final void Function(Docket d) onOpenWork;
//
//   const _AssignedTab({
//     required this.assigned,
//     required this.monthKey,
//     required this.summary,
//     required this.onOpenWork,
//   });
//
//   static DateTime _parseTs(String? s) =>
//       _TechnicianPortalPageState._parseTs(s);
//
//   @override
//   Widget build(BuildContext context) {
//     final chips = _SummaryChips(
//       total: summary.total,
//       completed: summary.completed,
//       pending: summary.pending,
//     );
//
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
//           child: chips,
//         ),
//         Expanded(
//           child: assigned.isEmpty
//               ? const _EmptyView(
//             icon: Icons.inbox,
//             title: 'No assigned jobs',
//             subtitle: 'You have no pending work right now.',
//           )
//               : ListView.separated(
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//             itemBuilder: (_, i) {
//               final d = assigned[i];
//               final up = _parseTs(d.uploadedTime);
//               final days = DateTime.now().difference(up).inDays;
//               final critical =
//                   days >= _TechnicianPortalPageState._criticalDays;
//               return _AssignedCard(
//                 docket: d,
//                 uploadedAt: up,
//                 pendingDays: days,
//                 critical: critical,
//                 onTap: () => onOpenWork(d),
//               );
//             },
//             separatorBuilder: (_, __) => const SizedBox(height: 10),
//             itemCount: assigned.length,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// class _AssignedCard extends StatelessWidget {
//   final Docket docket;
//   final DateTime uploadedAt;
//   final int pendingDays;
//   final bool critical;
//   final VoidCallback onTap;
//
//   const _AssignedCard({
//     required this.docket,
//     required this.uploadedAt,
//     required this.pendingDays,
//     required this.critical,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final dueText = pendingDays <= 0
//         ? 'Due today'
//         : 'Pending $pendingDays day${pendingDays == 1 ? '' : 's'}';
//     final badgeColor = critical ? Colors.red : const Color(0xFF003366);
//
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(14),
//         child: Padding(
//           padding: const EdgeInsets.all(14),
//           child: Row(
//             children: [
//               const CircleAvatar(
//                 radius: 22,
//                 backgroundColor: Color(0xFFE8EEF6),
//                 child: Icon(Icons.assignment, color: Color(0xFF003366)),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       docket.docketType,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                           fontWeight: FontWeight.w700,
//                           fontSize: 16,
//                           color: Color(0xFF003366)),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       'Depot: ${docket.depot} • Serial: ${docket.docketSerial}',
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(color: Colors.black87),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       'Uploaded: ${_TechnicianPortalPageState._prettyDate(uploadedAt)}',
//                       style: const TextStyle(
//                           color: Colors.black54, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Container(
//                 padding:
//                 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: badgeColor.withOpacity(0.1),
//                   border: Border.all(color: badgeColor.withOpacity(0.3)),
//                   borderRadius: BorderRadius.circular(999),
//                 ),
//                 child: Text(
//                   dueText,
//                   style: TextStyle(
//                     color: badgeColor,
//                     fontWeight: FontWeight.w700,
//                     fontSize: 12,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ---------- Completed Tab ----------
// class _CompletedTab extends StatelessWidget {
//   final List<Docket> all;
//   final List<String> months; // 'All', 'yyyy-MM'
//   final String selectedMonth;
//   final ValueChanged<String> onMonthChanged;
//   final List<Docket> itemsForMonth;
//   final ({int total, int completed, int pending}) summary;
//
//   const _CompletedTab({
//     required this.all,
//     required this.months,
//     required this.selectedMonth,
//     required this.onMonthChanged,
//     required this.itemsForMonth,
//     required this.summary,
//   });
//
//   static DateTime _parseTs(String? s) =>
//       _TechnicianPortalPageState._parseTs(s);
//
//   @override
//   Widget build(BuildContext context) {
//     final chips = _SummaryChips(
//       total: summary.total,
//       completed: summary.completed,
//       pending: summary.pending,
//     );
//
//     // guard the dropdown against a value not present in items
//     final safeValue =
//     months.contains(selectedMonth) ? selectedMonth : months.first;
//
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
//           child: Row(
//             children: [
//               Expanded(child: chips),
//               const SizedBox(width: 12),
//               SizedBox(
//                 width: 170,
//                 child: DropdownButtonFormField<String>(
//                   value: safeValue,
//                   items: months
//                       .map(
//                         (m) => DropdownMenuItem(
//                       value: m,
//                       child: Text(
//                         m == 'All'
//                             ? 'All months'
//                             : DateFormat('MMM yyyy').format(
//                             DateFormat('yyyy-MM').parse(m)),
//                       ),
//                     ),
//                   )
//                       .toList(),
//                   onChanged: (String? v) {
//                     if (v != null) onMonthChanged(v);
//                   },
//                   decoration: const InputDecoration(
//                     labelText: 'Month',
//                     border: OutlineInputBorder(),
//                     contentPadding:
//                     EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Expanded(
//           child: itemsForMonth.isEmpty
//               ? const _EmptyView(
//             icon: Icons.inbox,
//             title: 'No completed jobs',
//             subtitle: 'Nothing completed for the selected month.',
//           )
//               : ListView.separated(
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//             itemCount: itemsForMonth.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 10),
//             itemBuilder: (_, i) {
//               final d = itemsForMonth[i];
//               final cAt = _parseTs(d.completedTime);
//               return Card(
//                 elevation: 1.5,
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12)),
//                 child: ListTile(
//                   leading: const CircleAvatar(
//                     backgroundColor: Color(0xFFE8EEF6),
//                     child: Icon(Icons.check, color: Color(0xFF003366)),
//                   ),
//                   title: Text(
//                     d.docketType,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                         fontWeight: FontWeight.w700,
//                         color: Color(0xFF003366)),
//                   ),
//                   subtitle: Text(
//                     'Depot: ${d.depot} • Serial: ${d.docketSerial}\n'
//                         'Completed: ${_TechnicianPortalPageState._prettyDate(cAt)}',
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ---------- Shared UI ----------
// class _SummaryChips extends StatelessWidget {
//   final int total, completed, pending;
//   const _SummaryChips(
//       {required this.total, required this.completed, required this.pending});
//
//   @override
//   Widget build(BuildContext context) {
//     Widget chip(String title, int count, Color color) => Container(
//       margin: const EdgeInsets.only(right: 8, bottom: 8),
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.08),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.18)),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(title,
//               style: TextStyle(
//                   color: color,
//                   fontWeight: FontWeight.w600,
//                   fontSize: 13)),
//           const SizedBox(width: 8),
//           Container(
//             padding:
//             const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
//             decoration: BoxDecoration(
//               color: color,
//               borderRadius: BorderRadius.circular(999),
//             ),
//             child: Text(
//               '$count',
//               style: const TextStyle(
//                   color: Colors.white, fontWeight: FontWeight.bold),
//             ),
//           ),
//         ],
//       ),
//     );
//
//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: Row(
//         children: [
//           chip('Total', total, Colors.blueGrey),
//           chip('Completed', completed, Colors.green.shade700),
//           chip('Pending', pending, const Color(0xFF003366)),
//         ],
//       ),
//     );
//   }
// }
//
// class _PhotoRow extends StatelessWidget {
//   final String label;
//   final XFile? file;
//   final List<XFile>? files;
//   final VoidCallback onTake;
//   final bool requiredMark;
//
//   const _PhotoRow({
//     required this.label,
//     required this.file,
//     required this.onTake,
//     this.requiredMark = false,
//   }) : files = null;
//
//   const _PhotoRow.multi({
//     required this.label,
//     required this.files,
//     required this.onTake,
//   })  : file = null,
//         requiredMark = false;
//
//   @override
//   Widget build(BuildContext context) {
//     final bool multi = files != null;
//     final count = multi ? files!.length : (file == null ? 0 : 1);
//
//     return Row(
//       children: [
//         Expanded(
//           child: Text.rich(
//             TextSpan(
//               text: label,
//               style: const TextStyle(fontWeight: FontWeight.w600),
//               children: [
//                 if (requiredMark)
//                   const TextSpan(
//                     text: ' *',
//                     style: TextStyle(color: Colors.red),
//                   ),
//                 TextSpan(
//                   text:
//                   '  •  ${count == 0 ? "No photo" : "$count photo${count > 1 ? 's' : ''}"}',
//                   style: const TextStyle(
//                       color: Colors.black54, fontWeight: FontWeight.w400),
//                 )
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(width: 8),
//         OutlinedButton.icon(
//           onPressed: onTake,
//           icon: const Icon(Icons.photo_camera),
//           label: const Text('Take'),
//         ),
//       ],
//     );
//   }
// }
//
// class _EmptyView extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String? subtitle;
//   const _EmptyView({required this.icon, required this.title, this.subtitle});
//
//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       physics: const AlwaysScrollableScrollPhysics(),
//       children: [
//         SizedBox(height: MediaQuery.of(context).size.height * 0.2),
//         Icon(icon, size: 64, color: Colors.black26),
//         const SizedBox(height: 12),
//         Text(title,
//             textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
//         if (subtitle != null) ...[
//           const SizedBox(height: 6),
//           Text(subtitle!,
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: Colors.black54)),
//         ],
//       ],
//     );
//   }
// }
//
// class _ErrorView extends StatelessWidget {
//   final String message;
//   final Future<void> Function()? onRetry;
//   const _ErrorView({required this.message, this.onRetry});
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
//             const SizedBox(height: 12),
//             Text(message, textAlign: TextAlign.center),
//             if (onRetry != null) ...[
//               const SizedBox(height: 12),
//               ElevatedButton(
//                 onPressed: onRetry,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF003366),
//                   foregroundColor: Colors.white,
//                 ),
//                 child: const Text('Retry'),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }



//v2
// // … your same imports …
// import 'dart:convert';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
//
//
// import 'package:intl/intl.dart';
// import '../../models/dockets.dart';
//
// import '../../service/dockey_service.dart';
// import '../assignDockets/uploadcontent/httpUpdateDocketassignment.dart';
// import '../loginScreen/fetchUserAccess.dart';
//
// // -----------------------------------------------------------------------------
// // Technician Portal (Assignments driven only)
// // -----------------------------------------------------------------------------
//
// class TechnicianPortalPage extends StatefulWidget {
//   const TechnicianPortalPage({super.key});
//   @override
//   State<TechnicianPortalPage> createState() => _TechnicianPortalPageState();
// }
//
// class _TechnicianPortalPageState extends State<TechnicianPortalPage> {
//   // Adjust if your filenames differ
//   static const String _GET_ASSIGNMENTS =
//       'https://powerprox.sltidc.lk/GETDocketAssignments.php';
//   static const String _UPDATE_ASSIGNMENT =
//       'https://powerprox.sltidc.lk/UPDATEDocketAssignment.php';
//
//   final _svc = DocketService();
//
//   bool _loading = true;
//   String? _error;
//
//   // rows that belong to the signed-in tech
//   List<_Assignment> _mine = [];
//   // we still fetch dockets to show labels (type, depot, serial)
//   List<Docket> _allDockets = [];
//   Map<String, Docket> _docketById = {};
//
//   String _completedMonth = _monthKey(DateTime.now());
//
//   static const int _criticalDays = 2;
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }
//
//   String get _myEmpNo => (context.read<UserAccess>().employeeNumber ?? '').trim();
//
//   Future<void> _load() async {
//     final me = _myEmpNo;
//     if (me.isEmpty) {
//       setState(() {
//         _loading = false;
//         _error = 'Your employee number is missing. Please sign in again or contact admin.';
//       });
//       return;
//     }
//
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//
//     try {
//       // 1) fetch assignments (server may filter by employeeNo; we also filter client-side)
//       final asg = await _fetchAssignments(employeeNo: me);
//       // 2) fetch dockets for labels
//       final docks = await _svc.fetchDockets();
//
//       final map = {for (final d in docks) d.id: d};
//
//       // make sure month filter value is always valid
//       final months = _availableMonthsFrom(asg);
//       if (!months.contains(_completedMonth)) {
//         _completedMonth = months.first; // usually 'All'
//       }
//
//       setState(() {
//         _mine = asg;
//         _allDockets = docks;
//         _docketById = map;
//         _loading = false;
//       });
//
//       // Debug
//       // ignore: avoid_print
//       print('[TechPortal] me=$me • assignments=${_mine.length} '
//           '(active=${_mine.where((e) => e.reassigned==0).length}, '
//           'completed=${_mine.where((e) => e.reassigned==2).length}, '
//           'reassigned=${_mine.where((e) => e.reassigned==1).length})');
//
//     } catch (e) {
//       setState(() {
//         _error = 'Failed to load: $e';
//         _loading = false;
//         _mine = [];
//         _allDockets = [];
//         _docketById = {};
//       });
//     }
//   }
//
//   // ---------------- assignments I/O ----------------
//
//   Future<List<_Assignment>> _fetchAssignments({required String employeeNo}) async {
//     try {
//       final uri = Uri.parse('$_GET_ASSIGNMENTS?employeeNo=$employeeNo');
//       final r = await http.get(uri).timeout(const Duration(seconds: 25));
//
//       // Debug payload (short)
//       // ignore: avoid_print
//       print('[TechPortal] GETDocketAssignments status=${r.statusCode}');
//       if (r.statusCode != 200) return [];
//
//       final body = r.body;
//       // ignore: avoid_print
//       print('[TechPortal] body(len=${body.length}) ${body.substring(0, body.length.clamp(0, 220))}…');
//
//       final decoded = jsonDecode(body);
//       if (decoded is! List) return [];
//
//       final all = decoded.map<_Assignment>((e) => _Assignment.fromJson(e)).toList();
//
//       // defensive client-side filter (in case the server returns all rows)
//       bool containsMe(_Assignment a) {
//         final me = employeeNo.toLowerCase();
//         return a.assignedPersons
//             .split(',')
//             .map((s) => s.trim().toLowerCase())
//             .any((s) => s == me);
//       }
//
//       return all.where(containsMe).toList();
//     } catch (e) {
//       // ignore: avoid_print
//       print('[TechPortal] fetchAssignments error: $e');
//       return [];
//     }
//   }
//
//   Future<bool> _updateAssignment({
//     required String assignmentID,
//     required int reassigned, // 1=escalated, 2=completed
//     String? completedTime,
//     String? updatedBy,
//   }) async {
//     try {
//       final payload = {
//         'assignmentID': assignmentID,
//         'reassigned': reassigned.toString(),
//         if (completedTime != null) 'completedTime': completedTime,
//         if (updatedBy != null && updatedBy.isNotEmpty) 'uploadedBy': updatedBy,
//       };
//       final r = await http
//           .post(
//         Uri.parse(_UPDATE_ASSIGNMENT),
//         headers: const {'Content-Type': 'application/json'},
//         body: jsonEncode(payload),
//       )
//           .timeout(const Duration(seconds: 25));
//       if (r.statusCode != 200) return false;
//       try {
//         final m = jsonDecode(r.body);
//         final status = (m['status'] ?? '').toString().toLowerCase();
//         return status == 'success' || status == 'warning';
//       } catch (_) {
//         final low = r.body.toLowerCase();
//         if (low.contains('fatal error')) return false;
//         return true;
//       }
//     } catch (_) {
//       return false;
//     }
//   }
//
//   // ---------------- helpers ----------------
//
//   static DateTime _parseTs(String? ts) {
//     if (ts == null || ts.trim().isEmpty) {
//       return DateTime.fromMillisecondsSinceEpoch(0);
//     }
//     final s = ts.trim().replaceAll('/', '-');
//     for (final f in ['yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm', 'yyyy-MM-dd']) {
//       try { return DateFormat(f).parse(s); } catch (_) {}
//     }
//     try { return DateTime.parse(s); } catch (_) {
//       return DateTime.fromMillisecondsSinceEpoch(0);
//     }
//   }
//
//   static String _monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
//   static String _pretty(DateTime d) =>
//       d.millisecondsSinceEpoch == 0 ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(d);
//
//   List<_Assignment> get _active =>
//       _mine.where((a) => a.reassigned == 0).toList()
//         ..sort((a, b) => _parseTs(a.assignedTime).compareTo(_parseTs(b.assignedTime)));
//
//   List<_Assignment> get _completed =>
//       _mine.where((a) => a.reassigned == 2).toList()
//         ..sort((a, b) => _parseTs(b.completedTime).compareTo(_parseTs(a.completedTime)));
//
//   List<_Assignment> _completedForMonth(String key) =>
//       key == 'All'
//           ? _completed
//           : _completed.where((a) => _monthKey(_parseTs(a.completedTime)) == key).toList();
//
//   List<String> _availableMonthsFrom(List<_Assignment> src) {
//     final set = <String>{
//       for (final a in src) _monthKey(_parseTs(a.assignedTime)),
//       for (final a in src.where((x) => x.reassigned == 2)) _monthKey(_parseTs(a.completedTime)),
//     }..remove(_monthKey(DateTime.fromMillisecondsSinceEpoch(0)));
//
//     final list = set.toList()..sort();
//     return ['All', ...list];
//   }
//
//   ({int total, int completed, int pending}) _summaryForMonth(String key) {
//     Iterable<_Assignment> base = _mine;
//     if (key != 'All') {
//       base = base.where((a) => _monthKey(_parseTs(a.assignedTime)) == key);
//     }
//     int total = 0, comp = 0, pend = 0;
//     for (final a in base) {
//       total++;
//       if (a.reassigned == 2) comp++;
//       if (a.reassigned == 0) pend++;
//     }
//     return (total: total, completed: comp, pending: pend);
//   }
//
//   Docket? _detailsOf(String id) => _docketById[id];
//
//   // ---------------- actions ----------------
//
//   Future<bool> _markComplete(_Assignment a) async {
//     final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
//     final ok1 = await _updateAssignment(
//       assignmentID: a.assignmentID,
//       reassigned: 2,
//       completedTime: now,
//       updatedBy: _myEmpNo,
//     );
//     // also reflect in DocketDetails so the rest of the app stays in sync
//     final ok2 = await DocketUpdateApi.updateFields(id: a.docketID, fields: {
//       'AssignedTime': '2',
//       'completedTime': now,
//     });
//     return ok1 && ok2;
//   }
//
//   Future<bool> _escalate(_Assignment a, {required String reason}) async {
//     final ok1 = await _updateAssignment(
//       assignmentID: a.assignmentID,
//       reassigned: 1,
//       updatedBy: _myEmpNo,
//     );
//     final ok2 = await DocketUpdateApi.updateFields(id: a.docketID, fields: {
//       'AssignedTime': '4',
//       'locationDetails': '[Escalated] $reason',
//     });
//     return ok1 && ok2;
//   }
//
//   // ---------------- UI ----------------
//
//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Technician'),
//           backgroundColor: const Color(0xFF003366),
//           foregroundColor: Colors.white,
//           actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
//           bottom: const TabBar(
//             indicatorColor: Colors.white,
//             indicatorWeight: 3,
//             labelColor: Colors.white,
//             unselectedLabelColor: Colors.white70,
//             tabs: [Tab(text: 'Assigned'), Tab(text: 'Completed')],
//           ),
//         ),
//         body: SafeArea(
//           child: _loading
//               ? const Center(child: CircularProgressIndicator())
//               : _error != null
//               ? _ErrorView(message: _error!, onRetry: _load)
//               : TabBarView(
//             children: [
//               _AssignedTab(
//                 items: _active,
//                 detailsOf: _detailsOf,
//                 summary: _summaryForMonth(_monthKey(DateTime.now())),
//                 onOpenWork: _openWorkSheet,
//               ),
//               _CompletedTab(
//                 items: _completedForMonth(_completedMonth),
//                 months: _availableMonthsFrom(_mine),
//                 selectedMonth: _completedMonth,
//                 onMonthChanged: (m) => setState(() => _completedMonth = m),
//                 detailsOf: _detailsOf,
//                 summary: _summaryForMonth(_completedMonth),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Future<void> _openWorkSheet(_Assignment a) async {
//     final d = _detailsOf(a.docketID);
//     final picker = ImagePicker();
//     XFile? before, after;
//     final extras = <XFile>[];
//     String comment = '';
//     bool saving = false;
//
//     await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       useSafeArea: true,
//       builder: (ctx) => StatefulBuilder(
//         builder: (ctx, setS) {
//           final canEscalate = (before != null || after != null || extras.isNotEmpty);
//           final canComplete = (before != null && after != null);
//
//           return Padding(
//             padding: EdgeInsets.only(
//               left: 16, right: 16,
//               bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, top: 16,
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Row(children: [
//                   const Icon(Icons.home_repair_service, color: Color(0xFF003366)),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       d?.docketType ?? 'Docket ${a.docketID}',
//                       maxLines: 1, overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF003366)),
//                     ),
//                   ),
//                   IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
//                 ]),
//                 const SizedBox(height: 12),
//                 _PhotoRow(
//                   label: 'Before work', file: before, requiredMark: true,
//                   onTake: () async { before = await picker.pickImage(source: ImageSource.camera, imageQuality: 80); setS(() {}); },
//                 ),
//                 const SizedBox(height: 10),
//                 _PhotoRow(
//                   label: 'After work', file: after, requiredMark: true,
//                   onTake: () async { after = await picker.pickImage(source: ImageSource.camera, imageQuality: 80); setS(() {}); },
//                 ),
//                 const SizedBox(height: 10),
//                 _PhotoRow.multi(
//                   label: 'Additional photo(s)', files: extras,
//                   onTake: () async { final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 80); if (x != null) extras.add(x); setS(() {}); },
//                 ),
//                 const SizedBox(height: 10),
//                 TextField(
//                   minLines: 1, maxLines: 3,
//                   onChanged: (v) => comment = v,
//                   decoration: const InputDecoration(labelText: 'Comment (required if adding extras)', border: OutlineInputBorder()),
//                 ),
//                 const SizedBox(height: 16),
//                 Row(children: [
//                   Expanded(
//                     child: OutlinedButton.icon(
//                       icon: const Icon(Icons.flag), label: const Text('Escalate'),
//                       onPressed: !canEscalate || saving ? null : () async {
//                         if (extras.isNotEmpty && comment.trim().isEmpty) {
//                           ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Comment required for additional photo(s)')));
//                           return;
//                         }
//                         setS(() => saving = true);
//                         // TODO: upload photos + comment
//                         final ok = await _escalate(a, reason: comment.trim());
//                         setS(() => saving = false);
//                         if (!mounted) return;
//                         if (ok) { Navigator.pop(ctx); await _load(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escalated'), backgroundColor: Colors.orange)); }
//                         else { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Update failed'), backgroundColor: Colors.red)); }
//                       },
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: ElevatedButton.icon(
//                       icon: const Icon(Icons.check_circle), label: const Text('Mark complete'),
//                       style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003366), foregroundColor: Colors.white),
//                       onPressed: !canComplete || saving ? null : () async {
//                         setS(() => saving = true);
//                         // TODO: upload photos
//                         final ok = await _markComplete(a);
//                         setS(() => saving = false);
//                         if (!mounted) return;
//                         if (ok) { Navigator.pop(ctx); await _load(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked complete'), backgroundColor: Colors.green)); }
//                         else { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Update failed'), backgroundColor: Colors.red)); }
//                       },
//                     ),
//                   ),
//                 ]),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
//
// // ---------------- Assigned tab UI ----------------
//
// class _AssignedTab extends StatelessWidget {
//   final List<_Assignment> items;                        // reassigned == 0
//   final Docket? Function(String docketId) detailsOf;
//   final ({int total, int completed, int pending}) summary;
//   final void Function(_Assignment a) onOpenWork;
//
//   const _AssignedTab({
//     required this.items,
//     required this.detailsOf,
//     required this.summary,
//     required this.onOpenWork,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     Widget chips() => _SummaryChips(total: summary.total, completed: summary.completed, pending: summary.pending);
//
//     return Column(children: [
//       Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: chips()),
//       Expanded(
//         child: items.isEmpty
//             ? const _EmptyView(icon: Icons.inbox, title: 'No assigned jobs', subtitle: 'You have no pending work right now.')
//             : ListView.separated(
//           padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//           itemCount: items.length,
//           separatorBuilder: (_, __) => const SizedBox(height: 10),
//           itemBuilder: (_, i) {
//             final a = items[i];
//             final d = detailsOf(a.docketID);
//             final at = _TechnicianPortalPageState._parseTs(a.assignedTime);
//             final days = DateTime.now().difference(at).inDays;
//             final critical = days >= _TechnicianPortalPageState._criticalDays;
//             final dueText = days <= 0 ? 'Due today' : 'Pending $days d';
//             final badge = critical ? Colors.red : const Color(0xFF003366);
//
//             return Card(
//               elevation: 2,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//               child: InkWell(
//                 onTap: () => onOpenWork(a),
//                 borderRadius: BorderRadius.circular(14),
//                 child: Padding(
//                   padding: const EdgeInsets.all(14),
//                   child: Row(children: [
//                     const CircleAvatar(radius: 22, backgroundColor: Color(0xFFE8EEF6), child: Icon(Icons.assignment, color: Color(0xFF003366))),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                         Text(d?.docketType ?? 'Docket ${a.docketID}',
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF003366))),
//                         const SizedBox(height: 2),
//                         Text('Depot: ${d?.depot ?? '-'} • Serial: ${d?.docketSerial ?? '-'}',
//                             maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)),
//                         const SizedBox(height: 2),
//                         Text('Assigned: ${_TechnicianPortalPageState._pretty(at)}',
//                             style: const TextStyle(color: Colors.black54, fontSize: 12)),
//                       ]),
//                     ),
//                     const SizedBox(width: 10),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: badge.withOpacity(0.1),
//                         border: Border.all(color: badge.withOpacity(0.3)),
//                         borderRadius: BorderRadius.circular(999),
//                       ),
//                       child: Text(dueText, style: TextStyle(color: badge, fontWeight: FontWeight.w700, fontSize: 12)),
//                     ),
//                   ]),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     ]);
//   }
// }
//
// // ---------------- Completed tab UI ----------------
//
// class _CompletedTab extends StatelessWidget {
//   final List<_Assignment> items;
//   final List<String> months; // Always non-empty; first item must be 'All'
//   final String selectedMonth;
//   final ValueChanged<String> onMonthChanged;
//   final Docket? Function(String docketId) detailsOf;
//   final ({int total, int completed, int pending}) summary;
//
//   const _CompletedTab({
//     required this.items,
//     required this.months,
//     required this.selectedMonth,
//     required this.onMonthChanged,
//     required this.detailsOf,
//     required this.summary,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final safeValue = months.contains(selectedMonth) ? selectedMonth : months.first; // ← fix
//
//     return Column(children: [
//       Padding(
//         padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
//         child: Row(children: [
//           Expanded(child: _SummaryChips(total: summary.total, completed: summary.completed, pending: summary.pending)),
//           const SizedBox(width: 12),
//           SizedBox(
//             width: 160,
//             child: DropdownButtonFormField<String>(
//               value: safeValue,
//               items: months
//                   .map((m) => DropdownMenuItem<String>(
//                 value: m,
//                 child: Text(m == 'All'
//                     ? 'All months'
//                     : DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(m))),
//               ))
//                   .toList(),
//               onChanged: (v) {
//                 if (v != null) onMonthChanged(v);
//               },
//               decoration: const InputDecoration(
//                 labelText: 'Month',
//                 border: OutlineInputBorder(),
//                 contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//               ),
//             ),
//           ),
//         ]),
//       ),
//       Expanded(
//         child: items.isEmpty
//             ? const _EmptyView(icon: Icons.inbox, title: 'No completed jobs', subtitle: 'Nothing completed for the selected month.')
//             : ListView.separated(
//           padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//           itemCount: items.length,
//           separatorBuilder: (_, __) => const SizedBox(height: 10),
//           itemBuilder: (_, i) {
//             final a = items[i];
//             final d = detailsOf(a.docketID);
//             final ct = _TechnicianPortalPageState._parseTs(a.completedTime);
//             return Card(
//               elevation: 1.5,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: ListTile(
//                 leading: const CircleAvatar(backgroundColor: Color(0xFFE8EEF6), child: Icon(Icons.check, color: Color(0xFF003366))),
//                 title: Text(d?.docketType ?? 'Docket ${a.docketID}',
//                     maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF003366))),
//                 subtitle: Text(
//                   'Depot: ${d?.depot ?? '-'} • Serial: ${d?.docketSerial ?? '-'}\n'
//                       'Completed: ${_TechnicianPortalPageState._pretty(ct)}',
//                   maxLines: 2, overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     ]);
//   }
// }
//
// // ---------------- Shared components (unchanged UI) ----------------
//
// class _SummaryChips extends StatelessWidget {
//   final int total, completed, pending;
//   const _SummaryChips({required this.total, required this.completed, required this.pending});
//   @override
//   Widget build(BuildContext context) {
//     Widget chip(String title, int count, Color color) => Container(
//       margin: const EdgeInsets.only(right: 8, bottom: 8),
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//       decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.18))),
//       child: Row(mainAxisSize: MainAxisSize.min, children: [
//         Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
//         const SizedBox(width: 8),
//         Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)), child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
//       ]),
//     );
//     return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
//       chip('Total', total, Colors.blueGrey),
//       chip('Completed', completed, Colors.green.shade700),
//       chip('Pending', pending, const Color(0xFF003366)),
//     ]));
//   }
// }
//
// class _PhotoRow extends StatelessWidget {
//   final String label;
//   final XFile? file;
//   final List<XFile>? files;
//   final VoidCallback onTake;
//   final bool requiredMark;
//
//   const _PhotoRow({required this.label, required this.file, required this.onTake, this.requiredMark = false}) : files = null;
//   const _PhotoRow.multi({required this.label, required this.files, required this.onTake})  : file = null, requiredMark = false;
//
//   @override
//   Widget build(BuildContext context) {
//     final bool multi = files != null;
//     final count = multi ? files!.length : (file == null ? 0 : 1);
//     return Row(children: [
//       Expanded(child: Text.rich(TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.w600), children: [
//         if (requiredMark) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
//         TextSpan(text: '  •  ${count == 0 ? "No photo" : "$count photo${count > 1 ? 's' : ''}"}', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w400)),
//       ]))),
//       const SizedBox(width: 8),
//       OutlinedButton.icon(onPressed: onTake, icon: const Icon(Icons.photo_camera), label: const Text('Take')),
//     ]);
//   }
// }
//
// class _EmptyView extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String? subtitle;
//   const _EmptyView({required this.icon, required this.title, this.subtitle});
//
//   @override
//   Widget build(BuildContext context) {
//     return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
//       SizedBox(height: MediaQuery.of(context).size.height * 0.2),
//       Icon(icon, size: 64, color: Colors.black26),
//       const SizedBox(height: 12),
//       Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
//       if (subtitle != null) ...[
//         const SizedBox(height: 6),
//         Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
//       ],
//     ]);
//   }
// }
//
// class _ErrorView extends StatelessWidget {
//   final String message;
//   final Future<void> Function()? onRetry;
//   const _ErrorView({required this.message, this.onRetry});
//   @override
//   Widget build(BuildContext context) {
//     return Center(child: Padding(
//       padding: const EdgeInsets.all(24),
//       child: Column(mainAxisSize: MainAxisSize.min, children: [
//         const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
//         const SizedBox(height: 12),
//         Text(message, textAlign: TextAlign.center),
//         if (onRetry != null) ...[
//           const SizedBox(height: 12),
//           ElevatedButton(
//             onPressed: onRetry,
//             style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003366), foregroundColor: Colors.white),
//             child: const Text('Retry'),
//           ),
//         ],
//       ]),
//     ));
//   }
// }
//
// // ---------------- Local model for assignments ----------------
//
// class _Assignment {
//   final String assignmentID;
//   final String docketID;
//   final String assignedPersons; // CSV of employeeNo
//   final String assignedTime;
//   final int reassigned;         // 0 active, 1 escalated, 2 completed
//   final String uploadedBy;
//   final String uploadedTime;
//   final String completedTime;
//
//   _Assignment({
//     required this.assignmentID,
//     required this.docketID,
//     required this.assignedPersons,
//     required this.assignedTime,
//     required this.reassigned,
//     required this.uploadedBy,
//     required this.uploadedTime,
//     required this.completedTime,
//   });
//
//   factory _Assignment.fromJson(Map<String, dynamic> j) {
//     String s(dynamic v) => (v ?? '').toString();
//     int i(dynamic v) => int.tryParse(s(v)) ?? 0;
//
//     // Accept both lower/upper/different aliases
//     return _Assignment(
//       assignmentID: s(j['assignmentID'] ?? j['assignmentId'] ?? j['id']),
//       docketID: s(j['docketID'] ?? j['docketId'] ?? j['docket_id']),
//       assignedPersons: s(j['assignedPersons'] ?? j['assignees'] ?? j['assigned_to'] ?? ''),
//       assignedTime: s(j['assignedTime'] ?? j['assigned_time'] ?? j['UploadedTime']),
//       reassigned: i(j['reassigned']),
//       uploadedBy: s(j['uploadedBy'] ?? j['uploaded_by']),
//       uploadedTime: s(j['uploadedTime'] ?? j['uploaded_time']),
//       completedTime: s(j['completedTime'] ?? j['completed_time']),
//     );
//   }
// }
//
//
//
//
// //v1
// // import 'dart:async';
// // import 'package:flutter/material.dart';
// // import 'package:image_picker/image_picker.dart';
// // import 'package:intl/intl.dart';
// // import 'package:provider/provider.dart';
// //
// // import '../../models/dockets.dart';
// // import '../../service/dockey_service.dart';
// // import '../loginScreen/fetchUserAccess.dart';
// // import '../viewDockets/updateDockets/httpUpdateDockets.dart';
// //
// // /// Technician Portal:
// // /// - Assigned: all dockets with AssignedTime == '1' for this technician (by employeeNo), not completed
// // /// - Completed: all dockets with AssignedTime == '2' for this technician, filterable by month
// // ///
// // /// NOTE: We rely on DocketDetails.AssignedTime as status code:
// // ///  0=Unassigned, 1=Assigned, 2=Completed, 3=Reassigned, 4=Issue
// // /// and DocketDetails.assignedTo (string) to quickly check membership by employeeNo.
// // ///
// // /// For due/critical indicators we use UploadedTime as the start time
// // /// (until you expose an "assigned timestamp" on DocketDetails or join to DocketAssignment).
// // class TechnicianPortalPage extends StatefulWidget {
// //   const TechnicianPortalPage({super.key});
// //
// //   @override
// //   State<TechnicianPortalPage> createState() => _TechnicianPortalPageState();
// // }
// //
// // class _TechnicianPortalPageState extends State<TechnicianPortalPage> {
// //   final _svc = DocketService();
// //   bool _loading = true;
// //   String? _error;
// //   List<Docket> _all = [];
// //
// //   // Completed tab month filter: 'All' or 'yyyy-MM' (e.g., '2025-09')
// //   String _completedMonth = _monthKey(DateTime.now());
// //
// //   static const int _criticalDays = 2; // tweak as needed
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _load();
// //   }
// //
// //   Future<void> _load() async {
// //     setState(() {
// //       _loading = true;
// //       _error = null;
// //     });
// //     try {
// //       final data = await _svc.fetchDockets();
// //       setState(() {
// //         _all = data;
// //         _loading = false;
// //       });
// //     } catch (e) {
// //       setState(() {
// //         _error = 'Failed to load dockets: $e';
// //         _loading = false;
// //         _all = [];
// //       });
// //     }
// //   }
// //
// //   // ---------- Filters & helpers ----------
// //
// //   String get _myEmpNo {
// //     final ua = context.read<UserAccess>();
// //     return (ua.employeeNumber ?? '').trim();
// //   }
// //
// //   static DateTime _parseTs(String? ts) {
// //     if (ts == null || ts.trim().isEmpty) {
// //       return DateTime.fromMillisecondsSinceEpoch(0);
// //     }
// //     final s = ts.trim();
// //     try {
// //       // Try ISO
// //       return DateTime.parse(s.replaceAll('/', '-'));
// //     } catch (_) {
// //       // Try common DB format 2025-09-08 21:05:34
// //       try {
// //         return DateFormat('yyyy-MM-dd HH:mm:ss').parse(s);
// //       } catch (_) {
// //         // Try date only
// //         try {
// //           return DateFormat('yyyy-MM-dd').parse(s);
// //         } catch (_) {
// //           return DateTime.fromMillisecondsSinceEpoch(0);
// //         }
// //       }
// //     }
// //   }
// //
// //   static String _monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
// //
// //   static String _prettyDate(DateTime d) =>
// //       d.millisecondsSinceEpoch == 0 ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(d);
// //
// //   bool _assignedToMe(Docket d) {
// //     final me = _myEmpNo;
// //     if (me.isEmpty) return false;
// //     final s = (d.assignedTo ?? '').toLowerCase();
// //     if (s.isEmpty) return false;
// //     // allow either direct equality or comma-separated list containing employee number
// //     return s.split(',').map((e) => e.trim()).any((e) => e == me.toLowerCase()) ||
// //         s.contains(me.toLowerCase());
// //   }
// //
// //   List<Docket> _myAssignedPending() {
// //     return _all.where((d) {
// //       final status = (d.AssignedTime ?? '0').trim();
// //       return status == '1' && _assignedToMe(d);
// //     }).toList()
// //       ..sort((a, b) {
// //         // oldest first to surface long-pending/critical
// //         final at = _parseTs(a.uploadedTime);
// //         final bt = _parseTs(b.uploadedTime);
// //         return at.compareTo(bt);
// //       });
// //   }
// //
// //   List<Docket> _myCompletedForMonth(String monthKey) {
// //     final src = _all.where((d) {
// //       final status = (d.AssignedTime ?? '0').trim();
// //       if (status != '2') return false;
// //       if (!_assignedToMe(d)) return false;
// //       return true;
// //     });
// //     if (monthKey == 'All') {
// //       return src.toList()
// //         ..sort((a, b) => _parseTs(b.completedTime).compareTo(_parseTs(a.completedTime)));
// //     }
// //     return src
// //         .where((d) => _monthKey(_parseTs(d.completedTime)) == monthKey)
// //         .toList()
// //       ..sort((a, b) => _parseTs(b.completedTime).compareTo(_parseTs(a.completedTime)));
// //   }
// //
// //   // Summary for a month (top chips)
// //   ({int total, int completed, int pending}) _summaryForMonth(String monthKey) {
// //     // For summary we consider dockets assigned to me that were uploaded in that month
// //     final mine = _all.where((d) => _assignedToMe(d));
// //     Iterable<Docket> monthSet;
// //     if (monthKey == 'All') {
// //       monthSet = mine;
// //     } else {
// //       monthSet = mine.where((d) => _monthKey(_parseTs(d.uploadedTime)) == monthKey);
// //     }
// //     int total = 0, completed = 0, pending = 0;
// //     for (final d in monthSet) {
// //       total++;
// //       final s = (d.AssignedTime ?? '0').trim();
// //       if (s == '2') {
// //         completed++;
// //       } else if (s == '1') {
// //         pending++;
// //       }
// //     }
// //     return (total: total, completed: completed, pending: pending);
// //   }
// //
// //   List<String> _availableMonths() {
// //     // Build distinct yyyy-MM keys from completedTime (fallback uploadedTime)
// //     final set = <String>{};
// //     for (final d in _all) {
// //       if (_assignedToMe(d)) {
// //         final k1 = _monthKey(_parseTs(d.completedTime));
// //         if (k1 != _monthKey(DateTime.fromMillisecondsSinceEpoch(0))) set.add(k1);
// //         final k2 = _monthKey(_parseTs(d.uploadedTime));
// //         if (k2 != _monthKey(DateTime.fromMillisecondsSinceEpoch(0))) set.add(k2);
// //       }
// //     }
// //     final list = set.toList()..sort();
// //     if (!list.contains(_monthKey(DateTime.now()))) list.add(_monthKey(DateTime.now()));
// //     list.sort();
// //     // Put 'All' at the front + ensure uniqueness
// //     return ['All', ...{...list}];
// //   }
// //
// //   // ---------- Actions: complete / escalate (DB only for now) ----------
// //
// //   Future<bool> _markComplete(Docket d) async {
// //     final ok = await DocketUpdateApi.updateFields(id: d.id, fields: {
// //       'AssignedTime': '2',
// //       'UploadedTime': d.uploadedTime, // untouched
// //       'DocketSerial': d.docketSerial, // untouched
// //       'completedTime': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
// //     });
// //     return ok;
// //   }
// //
// //   Future<bool> _escalate(Docket d, {required String reason}) async {
// //     final ok = await DocketUpdateApi.updateFields(id: d.id, fields: {
// //       'AssignedTime': '4',
// //       // you may want to append reason into a dedicated column;
// //       // storing inside locationDetails to keep visibility for now:
// //       'locationDetails': ((d.locationDetails ?? '').trim().isEmpty)
// //           ? '[Escalated] $reason'
// //           : '${d.locationDetails}\n[Escalated] $reason',
// //     });
// //     return ok;
// //   }
// //
// //   // ---------- UI: pages ----------
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final emp = _myEmpNo;
// //     return DefaultTabController(
// //       length: 2,
// //       child: Scaffold(
// //         appBar: AppBar(
// //           title: const Text('Technician'),
// //           backgroundColor: const Color(0xFF003366),
// //           foregroundColor: Colors.white,
// //           actions: [
// //             IconButton(
// //               tooltip: 'Refresh',
// //               onPressed: _load,
// //               icon: const Icon(Icons.refresh),
// //             ),
// //           ],
// //           bottom: const TabBar(
// //             indicatorColor: Colors.white,
// //             indicatorWeight: 3,
// //             labelColor: Colors.white,
// //             unselectedLabelColor: Colors.white70,
// //             tabs: [
// //               Tab(text: 'Assigned'),
// //               Tab(text: 'Completed'),
// //             ],
// //           ),
// //         ),
// //         body: SafeArea(
// //           child: _loading
// //               ? const Center(child: CircularProgressIndicator())
// //               : _error != null
// //               ? _ErrorView(message: _error!, onRetry: _load)
// //               : emp.isEmpty
// //               ? const _ErrorView(
// //             message:
// //             'Your employee number is missing. Please sign in again or contact admin.',
// //           )
// //               : TabBarView(
// //             children: [
// //               _AssignedTab(
// //                 assigned: _myAssignedPending(),
// //                 monthKey: _monthKey(DateTime.now()),
// //                 summary: _summaryForMonth(_monthKey(DateTime.now())),
// //                 onOpenWork: _openWorkSheet,
// //               ),
// //               _CompletedTab(
// //                 all: _all,
// //                 months: _availableMonths(),
// //                 selectedMonth: _completedMonth,
// //                 onMonthChanged: (m) =>
// //                     setState(() => _completedMonth = m),
// //                 itemsForMonth: _myCompletedForMonth(_completedMonth),
// //                 summary: _summaryForMonth(_completedMonth),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // Bottom sheet workflow UI (photos + comment + complete/escalate)
// //   Future<void> _openWorkSheet(Docket d) async {
// //     final picker = ImagePicker();
// //     XFile? before;
// //     XFile? after;
// //     final List<XFile> extra = [];
// //     String extraComment = '';
// //     bool saving = false;
// //
// //     Future<void> takeBefore() async {
// //       before = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
// //       setState(() {});
// //     }
// //
// //     Future<void> takeAfter() async {
// //       after = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
// //       setState(() {});
// //     }
// //
// //     Future<void> addExtra() async {
// //       final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
// //       if (x != null) extra.add(x);
// //       setState(() {});
// //     }
// //
// //     // ignore: use_build_context_synchronously
// //     await showModalBottomSheet(
// //       context: context,
// //       isScrollControlled: true,
// //       useSafeArea: true,
// //       builder: (ctx) {
// //         return StatefulBuilder(
// //           builder: (ctx, setSheet) {
// //             final canEscalate = (before != null || after != null || extra.isNotEmpty);
// //             final canComplete = (before != null && after != null);
// //             return Padding(
// //               padding: EdgeInsets.only(
// //                 left: 16,
// //                 right: 16,
// //                 bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
// //                 top: 16,
// //               ),
// //               child: Column(
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: [
// //                   // Header
// //                   Row(
// //                     children: [
// //                       const Icon(Icons.home_repair_service, color: Color(0xFF003366)),
// //                       const SizedBox(width: 8),
// //                       Expanded(
// //                         child: Text(
// //                           d.docketType,
// //                           style: const TextStyle(
// //                             fontWeight: FontWeight.w700,
// //                             fontSize: 16,
// //                             color: Color(0xFF003366),
// //                           ),
// //                           overflow: TextOverflow.ellipsis,
// //                         ),
// //                       ),
// //                       IconButton(
// //                         onPressed: () => Navigator.pop(ctx),
// //                         icon: const Icon(Icons.close),
// //                       )
// //                     ],
// //                   ),
// //                   const SizedBox(height: 8),
// //                   const Align(
// //                     alignment: Alignment.centerLeft,
// //                     child: Text('Please capture work photos',
// //                         style: TextStyle(color: Colors.black54)),
// //                   ),
// //                   const SizedBox(height: 12),
// //
// //                   // Photo rows
// //                   _PhotoRow(
// //                     label: 'Before work',
// //                     file: before,
// //                     onTake: () async {
// //                       before = await ImagePicker()
// //                           .pickImage(source: ImageSource.camera, imageQuality: 80);
// //                       setSheet(() {});
// //                     },
// //                     requiredMark: true,
// //                   ),
// //                   const SizedBox(height: 10),
// //                   _PhotoRow(
// //                     label: 'After work',
// //                     file: after,
// //                     onTake: () async {
// //                       after = await ImagePicker()
// //                           .pickImage(source: ImageSource.camera, imageQuality: 80);
// //                       setSheet(() {});
// //                     },
// //                     requiredMark: true,
// //                   ),
// //                   const SizedBox(height: 10),
// //                   _PhotoRow.multi(
// //                     label: 'Additional photo(s)',
// //                     files: extra,
// //                     onTake: () async {
// //                       final x = await ImagePicker()
// //                           .pickImage(source: ImageSource.camera, imageQuality: 80);
// //                       if (x != null) extra.add(x);
// //                       setSheet(() {});
// //                     },
// //                   ),
// //                   const SizedBox(height: 10),
// //                   TextField(
// //                     minLines: 1,
// //                     maxLines: 3,
// //                     onChanged: (v) => extraComment = v,
// //                     decoration: const InputDecoration(
// //                       labelText: 'Additional comment (required if adding extras)',
// //                       border: OutlineInputBorder(),
// //                     ),
// //                   ),
// //                   const SizedBox(height: 16),
// //
// //                   // Action buttons
// //                   Row(
// //                     children: [
// //                       Expanded(
// //                         child: OutlinedButton.icon(
// //                           onPressed: !canEscalate || saving
// //                               ? null
// //                               : () async {
// //                             if (extra.isNotEmpty && extraComment.trim().isEmpty) {
// //                               ScaffoldMessenger.of(ctx).showSnackBar(
// //                                 const SnackBar(
// //                                   content: Text(
// //                                       'Please add a comment for additional photo(s).'),
// //                                 ),
// //                               );
// //                               return;
// //                             }
// //                             setSheet(() => saving = true);
// //                             // TODO: upload photos via SFTP; include extraComment
// //                             final ok =
// //                             await _escalate(d, reason: extraComment.trim());
// //                             setSheet(() => saving = false);
// //                             if (!mounted) return;
// //                             if (ok) {
// //                               Navigator.pop(ctx);
// //                               await _load();
// //                               ScaffoldMessenger.of(context).showSnackBar(
// //                                 const SnackBar(
// //                                   content: Text('Escalated'),
// //                                   backgroundColor: Colors.orange,
// //                                 ),
// //                               );
// //                             } else {
// //                               ScaffoldMessenger.of(ctx).showSnackBar(
// //                                 const SnackBar(
// //                                   content: Text('Escalation failed'),
// //                                   backgroundColor: Colors.red,
// //                                 ),
// //                               );
// //                             }
// //                           },
// //                           icon: const Icon(Icons.flag),
// //                           label: const Text('Escalate'),
// //                         ),
// //                       ),
// //                       const SizedBox(width: 12),
// //                       Expanded(
// //                         child: ElevatedButton.icon(
// //                           onPressed: !canComplete || saving
// //                               ? null
// //                               : () async {
// //                             setSheet(() => saving = true);
// //                             // TODO: upload photos via SFTP first
// //                             final ok = await _markComplete(d);
// //                             setSheet(() => saving = false);
// //                             if (!mounted) return;
// //                             if (ok) {
// //                               Navigator.pop(ctx);
// //                               await _load();
// //                               ScaffoldMessenger.of(context).showSnackBar(
// //                                 const SnackBar(
// //                                   content: Text('Marked complete'),
// //                                   backgroundColor: Colors.green,
// //                                 ),
// //                               );
// //                             } else {
// //                               ScaffoldMessenger.of(ctx).showSnackBar(
// //                                 const SnackBar(
// //                                   content: Text('Update failed'),
// //                                   backgroundColor: Colors.red,
// //                                 ),
// //                               );
// //                             }
// //                           },
// //                           style: ElevatedButton.styleFrom(
// //                             backgroundColor: const Color(0xFF003366),
// //                             foregroundColor: Colors.white,
// //                           ),
// //                           icon: const Icon(Icons.check_circle),
// //                           label: const Text('Mark complete'),
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ],
// //               ),
// //             );
// //           },
// //         );
// //       },
// //     );
// //   }
// // }
// //
// // // ---------- Assigned Tab ----------
// //
// // class _AssignedTab extends StatelessWidget {
// //   final List<Docket> assigned;
// //   final String monthKey; // current month for summary display
// //   final ({int total, int completed, int pending}) summary;
// //   final void Function(Docket d) onOpenWork;
// //
// //   const _AssignedTab({
// //     required this.assigned,
// //     required this.monthKey,
// //     required this.summary,
// //     required this.onOpenWork,
// //   });
// //
// //   static DateTime _parseTs(String? s) => _TechnicianPortalPageState._parseTs(s);
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final chips = _SummaryChips(
// //       total: summary.total,
// //       completed: summary.completed,
// //       pending: summary.pending,
// //     );
// //
// //     return Column(
// //       children: [
// //         Padding(
// //           padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
// //           child: chips,
// //         ),
// //         Expanded(
// //           child: assigned.isEmpty
// //               ? const _EmptyView(
// //             icon: Icons.inbox,
// //             title: 'No assigned jobs',
// //             subtitle: 'You have no pending work right now.',
// //           )
// //               : RefreshIndicator(
// //             onRefresh: () async {
// //               // parent handles reload via AppBar refresh; this keeps pull-to-refresh UX
// //               // ignore: use_build_context_synchronously
// //               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
// //                 content: Text('Pull-to-refresh handled by page refresh.'),
// //                 duration: Duration(milliseconds: 800),
// //               ));
// //             },
// //             child: ListView.separated(
// //               padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
// //               itemBuilder: (_, i) {
// //                 final d = assigned[i];
// //                 final up = _parseTs(d.uploadedTime);
// //                 final days = DateTime.now().difference(up).inDays;
// //                 final critical = days >= _TechnicianPortalPageState._criticalDays;
// //                 return _AssignedCard(
// //                   docket: d,
// //                   uploadedAt: up,
// //                   pendingDays: days,
// //                   critical: critical,
// //                   onTap: () => onOpenWork(d),
// //                 );
// //               },
// //               separatorBuilder: (_, __) => const SizedBox(height: 10),
// //               itemCount: assigned.length,
// //             ),
// //           ),
// //         ),
// //       ],
// //     );
// //   }
// // }
// //
// // class _AssignedCard extends StatelessWidget {
// //   final Docket docket;
// //   final DateTime uploadedAt;
// //   final int pendingDays;
// //   final bool critical;
// //   final VoidCallback onTap;
// //
// //   const _AssignedCard({
// //     required this.docket,
// //     required this.uploadedAt,
// //     required this.pendingDays,
// //     required this.critical,
// //     required this.onTap,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final dueText =
// //     pendingDays <= 0 ? 'Due today' : 'Pending $pendingDays day${pendingDays == 1 ? '' : 's'}';
// //     final badgeColor = critical ? Colors.red : const Color(0xFF003366);
// //
// //     return Card(
// //       elevation: 2,
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
// //       child: InkWell(
// //         onTap: onTap,
// //         borderRadius: BorderRadius.circular(14),
// //         child: Padding(
// //           padding: const EdgeInsets.all(14),
// //           child: Row(
// //             children: [
// //               // Leading icon
// //               CircleAvatar(
// //                 radius: 22,
// //                 backgroundColor: const Color(0xFFE8EEF6),
// //                 child: Icon(Icons.assignment, color: const Color(0xFF003366)),
// //               ),
// //               const SizedBox(width: 12),
// //               // Text
// //               Expanded(
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     Text(
// //                       docket.docketType,
// //                       maxLines: 1,
// //                       overflow: TextOverflow.ellipsis,
// //                       style: const TextStyle(
// //                           fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF003366)),
// //                     ),
// //                     const SizedBox(height: 2),
// //                     Text(
// //                       'Depot: ${docket.depot} • Serial: ${docket.docketSerial}',
// //                       maxLines: 1,
// //                       overflow: TextOverflow.ellipsis,
// //                       style: const TextStyle(color: Colors.black87),
// //                     ),
// //                     const SizedBox(height: 2),
// //                     Text(
// //                       'Uploaded: ${_TechnicianPortalPageState._prettyDate(uploadedAt)}',
// //                       style: const TextStyle(color: Colors.black54, fontSize: 12),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //               const SizedBox(width: 10),
// //               // Right badge
// //               Container(
// //                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
// //                 decoration: BoxDecoration(
// //                   color: badgeColor.withOpacity(0.1),
// //                   border: Border.all(color: badgeColor.withOpacity(0.3)),
// //                   borderRadius: BorderRadius.circular(999),
// //                 ),
// //                 child: Text(
// //                   dueText,
// //                   style: TextStyle(
// //                     color: badgeColor,
// //                     fontWeight: FontWeight.w700,
// //                     fontSize: 12,
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // // ---------- Completed Tab ----------
// //
// // class _CompletedTab extends StatelessWidget {
// //   final List<Docket> all;
// //   final List<String> months; // 'All', 'yyyy-MM' values
// //   final String selectedMonth;
// //   final ValueChanged<String> onMonthChanged;
// //   final List<Docket> itemsForMonth;
// //   final ({int total, int completed, int pending}) summary;
// //
// //   const _CompletedTab({
// //     required this.all,
// //     required this.months,
// //     required this.selectedMonth,
// //     required this.onMonthChanged,
// //     required this.itemsForMonth,
// //     required this.summary,
// //   });
// //
// //   static DateTime _parseTs(String? s) => _TechnicianPortalPageState._parseTs(s);
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final chips = _SummaryChips(
// //       total: summary.total,
// //       completed: summary.completed,
// //       pending: summary.pending,
// //     );
// //
// //     return Column(
// //       children: [
// //         // Summary + month filter
// //         Padding(
// //           padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
// //           child: Row(
// //             children: [
// //               Expanded(child: chips),
// //               const SizedBox(width: 12),
// //               SizedBox(
// //                 width: 160,
// //                 child: DropdownButtonFormField<String>(
// //                   value: selectedMonth,
// //                   items: months
// //                       .map((m) => DropdownMenuItem(
// //                     value: m,
// //                     child: Text(m == 'All'
// //                         ? 'All months'
// //                         : DateFormat('yyyy-MM').parse(m) !=
// //                         DateTime.fromMillisecondsSinceEpoch(0)
// //                         ? DateFormat('MMM yyyy').format(
// //                         DateFormat('yyyy-MM').parse(m))
// //                         : m),
// //                   ))
// //                       .toList(),
// //                   onChanged: (String? v) {
// //                     if (v != null) onMonthChanged(v);
// //                   },
// //                   decoration: const InputDecoration(
// //                     labelText: 'Month',
// //                     border: OutlineInputBorder(),
// //                     contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //         Expanded(
// //           child: itemsForMonth.isEmpty
// //               ? const _EmptyView(
// //             icon: Icons.inbox,
// //             title: 'No completed jobs',
// //             subtitle: 'Nothing completed for the selected month.',
// //           )
// //               : ListView.separated(
// //             padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
// //             itemCount: itemsForMonth.length,
// //             separatorBuilder: (_, __) => const SizedBox(height: 10),
// //             itemBuilder: (_, i) {
// //               final d = itemsForMonth[i];
// //               final cAt = _parseTs(d.completedTime);
// //               return Card(
// //                 elevation: 1.5,
// //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //                 child: ListTile(
// //                   leading: const CircleAvatar(
// //                     backgroundColor: Color(0xFFE8EEF6),
// //                     child: Icon(Icons.check, color: Color(0xFF003366)),
// //                   ),
// //                   title: Text(
// //                     d.docketType,
// //                     maxLines: 1,
// //                     overflow: TextOverflow.ellipsis,
// //                     style: const TextStyle(
// //                         fontWeight: FontWeight.w700, color: Color(0xFF003366)),
// //                   ),
// //                   subtitle: Text(
// //                     'Depot: ${d.depot} • Serial: ${d.docketSerial}\nCompleted: ${_TechnicianPortalPageState._prettyDate(cAt)}',
// //                     maxLines: 2,
// //                     overflow: TextOverflow.ellipsis,
// //                   ),
// //                 ),
// //               );
// //             },
// //           ),
// //         ),
// //       ],
// //     );
// //   }
// // }
// //
// // // ---------- Shared UI pieces ----------
// //
// // class _SummaryChips extends StatelessWidget {
// //   final int total, completed, pending;
// //   const _SummaryChips({required this.total, required this.completed, required this.pending});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     Widget chip(String title, int count, Color color) => Container(
// //       margin: const EdgeInsets.only(right: 8, bottom: 8),
// //       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
// //       decoration: BoxDecoration(
// //         color: color.withOpacity(0.08),
// //         borderRadius: BorderRadius.circular(12),
// //         border: Border.all(color: color.withOpacity(0.18)),
// //       ),
// //       child: Row(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           Text(title,
// //               style: TextStyle(
// //                   color: color, fontWeight: FontWeight.w600, fontSize: 13)),
// //           const SizedBox(width: 8),
// //           Container(
// //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
// //             decoration: BoxDecoration(
// //               color: color,
// //               borderRadius: BorderRadius.circular(999),
// //             ),
// //             child: Text(
// //               '$count',
// //               style:
// //               const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //
// //     return SingleChildScrollView(
// //       scrollDirection: Axis.horizontal,
// //       child: Row(
// //         children: [
// //           chip('Total', total, Colors.blueGrey),
// //           chip('Completed', completed, Colors.green.shade700),
// //           chip('Pending', pending, const Color(0xFF003366)),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // class _PhotoRow extends StatelessWidget {
// //   final String label;
// //   final XFile? file;
// //   final List<XFile>? files;
// //   final VoidCallback onTake;
// //   final bool requiredMark;
// //
// //   const _PhotoRow({
// //     required this.label,
// //     required this.file,
// //     required this.onTake,
// //     this.requiredMark = false,
// //   }) : files = null;
// //
// //   const _PhotoRow.multi({
// //     required this.label,
// //     required this.files,
// //     required this.onTake,
// //   })  : file = null,
// //         requiredMark = false;
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final bool multi = files != null;
// //     final count = multi ? files!.length : (file == null ? 0 : 1);
// //
// //     return Row(
// //       children: [
// //         Expanded(
// //           child: Text.rich(
// //             TextSpan(
// //               text: label,
// //               style: const TextStyle(fontWeight: FontWeight.w600),
// //               children: [
// //                 if (requiredMark)
// //                   const TextSpan(
// //                     text: ' *',
// //                     style: TextStyle(color: Colors.red),
// //                   ),
// //                 TextSpan(
// //                   text: '  •  ${count == 0 ? "No photo" : "$count photo${count > 1 ? 's' : ''}"}',
// //                   style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w400),
// //                 )
// //               ],
// //             ),
// //           ),
// //         ),
// //         const SizedBox(width: 8),
// //         OutlinedButton.icon(
// //           onPressed: onTake,
// //           icon: const Icon(Icons.photo_camera),
// //           label: const Text('Take'),
// //         ),
// //       ],
// //     );
// //   }
// // }
// //
// // class _EmptyView extends StatelessWidget {
// //   final IconData icon;
// //   final String title;
// //   final String? subtitle;
// //   const _EmptyView({required this.icon, required this.title, this.subtitle});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return ListView(
// //       physics: const AlwaysScrollableScrollPhysics(),
// //       children: [
// //         SizedBox(height: MediaQuery.of(context).size.height * 0.2),
// //         Icon(icon, size: 64, color: Colors.black26),
// //         const SizedBox(height: 12),
// //         Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
// //         if (subtitle != null) ...[
// //           const SizedBox(height: 6),
// //           Text(subtitle!,
// //               textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
// //         ],
// //       ],
// //     );
// //   }
// // }
// //
// // class _ErrorView extends StatelessWidget {
// //   final String message;
// //   final Future<void> Function()? onRetry;
// //   const _ErrorView({required this.message, this.onRetry});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Center(
// //       child: Padding(
// //         padding: const EdgeInsets.all(24),
// //         child: Column(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
// //             const SizedBox(height: 12),
// //             Text(message, textAlign: TextAlign.center),
// //             if (onRetry != null) ...[
// //               const SizedBox(height: 12),
// //               ElevatedButton(
// //                 onPressed: onRetry,
// //                 style: ElevatedButton.styleFrom(
// //                   backgroundColor: const Color(0xFF003366),
// //                   foregroundColor: Colors.white,
// //                 ),
// //                 child: const Text('Retry'),
// //               ),
// //             ],
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
