import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leco_docket_tracker/pages/viewDockets/showDocketDetails.dart';
import 'package:provider/provider.dart';

import '../../models/dockets.dart';
import '../../service/dockey_service.dart';
import '../loginScreen/fetchUserAccess.dart';

/// List of dockets for a given type, honoring optional depot + status filters.
/// - depot == null or 'All' → show all depots
/// - filterStatus: -1 = All, 0..4 (Unassigned, Assigned, Completed, Reassigned, Issue)
class ShowDocketsList extends StatefulWidget {
  final String title;        // docket type
  final String? depot;       // null or 'All' -> all depots
  final int? filterStatus;   // -1 (All) or 0..4

  const ShowDocketsList({
    super.key,
    required this.title,
    this.depot,
    this.filterStatus,
  });

  @override
  State<ShowDocketsList> createState() => _ShowDocketsListState();
}

class _ShowDocketsListState extends State<ShowDocketsList> {
  final _svc = DocketService();
  late Future<List<Docket>> _future;

  // Status labels (for AppBar)
  static const Map<int, String> _statusLabel = {
    -1: 'All',
    0: 'Unassigned',
    1: 'Assigned',
    2: 'Completed',
    3: 'Reassigned',
    4: 'Issue',
  };

  @override
  void initState() {
    super.initState();

    // 🔎 Debug: what was passed in?
    debugPrint(
      '[ShowDocketsList] Opened with -> '
          'title="${widget.title}", depot="${widget.depot}", filterStatus=${widget.filterStatus}',
    );

    _future = _svc.fetchDockets();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _svc.fetchDockets();
    });
    await _future;
  }

  bool _isAllDepots(String? depot) =>
      depot == null || depot.trim().isEmpty || depot.toLowerCase() == 'all';

  /// Read AssignedTime from the Docket model.
  /// Your DB returns it as a **string** "0".."4" with exact field name `AssignedTime`.
  /// We also gracefully handle `assignedTime` (camelCase) just in case your model used that.
  int _assignedOf(Docket d) {
    try {
      // Try to access `AssignedTime` (as in DB) first via `dynamic`.
      final dyn = d as dynamic;
      final raw = dyn.AssignedTime ?? dyn.assignedTime; // fallback if model used camelCase
      if (raw == null) return 0;
      final s = raw.toString().trim();
      return int.tryParse(s) ?? 0;
    } catch (_) {
      // If reflection-like access fails, last fallback: assume there is a getter `assignedTime`
      // and try to parse it.
      try {
        final rawFallback = (d as dynamic).assignedTime;
        final s = rawFallback?.toString().trim() ?? '0';
        return int.tryParse(s) ?? 0;
      } catch (_) {
        return 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resolve filters coming from summary page (or fallback to user's depot)
    final ua = context.read<UserAccess>();
    final effectiveDepot =
    _isAllDepots(widget.depot) ? null : (widget.depot ?? ua.depot);

    final int effectiveStatus =
    (widget.filterStatus == null) ? -1 : widget.filterStatus!;
    final statusLabel = _statusLabel[effectiveStatus] ?? 'All';

    // 🔎 Debug: resolved filters
    debugPrint(
      '[ShowDocketsList] Resolved filters -> '
          'type="${widget.title}", depot=${effectiveDepot ?? "ALL"}, status=$effectiveStatus($statusLabel)',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            'Dockets • ${widget.title}',
            if (!_isAllDepots(effectiveDepot)) '• ${effectiveDepot!}',
            if (effectiveStatus != -1) '• $statusLabel',
          ].join(' '),
        ),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Docket>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF003366)),
              );
            }
            if (snap.hasError) {
              debugPrint('[ShowDocketsList] Error: ${snap.error}');
              return _ErrorState(
                message: 'Failed to load dockets:\n${snap.error}',
                onRetry: _reload,
              );
            }

            final all = (snap.data ?? <Docket>[]);
            debugPrint('[ShowDocketsList] Total fetched: ${all.length}');

            // Step 1: Type filter
            var step = all.where((d) =>
            (d.docketType ?? '').toLowerCase().trim() ==
                widget.title.toLowerCase().trim());
            debugPrint('[ShowDocketsList] After type("${widget.title}"): ${step.length}');

            // Step 2: Depot filter (if any)
            if (effectiveDepot != null) {
              final dep = effectiveDepot.toLowerCase().trim();
              step = step.where((d) =>
              (d.depot ?? '').toLowerCase().trim() == dep);
              debugPrint('[ShowDocketsList] After depot("$dep"): ${step.length}');
            } else {
              debugPrint('[ShowDocketsList] Depot filter: ALL');
            }

            // Step 3: Status filter
            if (effectiveStatus != -1) {
              final st = effectiveStatus;
              step = step.where((d) => _assignedOf(d) == st);
              debugPrint('[ShowDocketsList] After status($st): ${step.length}');
            } else {
              debugPrint('[ShowDocketsList] Status filter: ALL');
            }

            final filtered = step.toList()
              ..sort((a, b) {
                // newest first if possible
                final at = _parse(a.uploadedTime);
                final bt = _parse(b.uploadedTime);
                return bt.compareTo(at);
              });

            if (filtered.isEmpty) {
              return _EmptyState(
                title: 'No dockets found',
                subtitle: [
                  'Type: "${widget.title}"',
                  if (!_isAllDepots(effectiveDepot)) 'Depot: "$effectiveDepot"',
                  if (effectiveStatus != -1) 'Status: "$statusLabel"',
                ].join(' • '),
                onRefresh: _reload,
              );
            }

            return RefreshIndicator(
              onRefresh: _reload,
              color: const Color(0xFF003366),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _DocketListTile(
                  docket: filtered[i],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocketDetailsPage(docket: filtered[i]),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  DateTime _parse(String? ts) {
    if (ts == null || ts.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      // Handles "2025-08-29 10:18:24" and ISO-like
      return DateTime.parse(ts);
    } catch (_) {
      try {
        return DateFormat('yyyy-MM-dd HH:mm:ss').parse(ts);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
  }
}

class _DocketListTile extends StatelessWidget {
  final Docket docket;
  final VoidCallback onTap;

  const _DocketListTile({required this.docket, required this.onTap});

  // Map docket type → remote image subdirectory index
  int _dirForType(String type) {
    switch (type.toLowerCase()) {
      case 'service line maintenance':
        return 1;
      case 'meter testing':
        return 2;
      case 'estimate':
        return 3;
      default:
        return 4; // everything else
    }
  }

  String _imageUrl(Docket d) {
    final type = d.docketType ?? '';
    final dir = _dirForType(type);
    final file = d.imageName ?? '';
    return 'http://124.43.181.243:8000/api/fetch-testdocket-image/$dir/$file';
  }

  @override
  Widget build(BuildContext context) {
    final uploaded = (docket.uploadedTime == null || docket.uploadedTime!.isEmpty)
        ? '-'
        : docket.uploadedTime!;
    final uploadedBy =
    docket.uploadedBy?.isNotEmpty == true ? docket.uploadedBy! : 'Unknown';
    final depot = docket.depot ?? '-';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // tiny thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Image.network(
                    _imageUrl(docket),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF1F3F6),
                      child: const Icon(Icons.image_not_supported, size: 28),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docket.imageName ?? '(no file)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Depot: $depot  •  By: $uploadedBy',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Uploaded: $uploaded',
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Future<void> Function() onRefresh;

  const _EmptyState({
    required this.title,
    this.subtitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF003366),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          const Icon(Icons.inbox, size: 64, color: Colors.black26),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}


//v1
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:leco_docket_tracker/pages/viewDockets/showDocketDetails.dart';
// import 'package:provider/provider.dart';
//
// import '../../models/dockets.dart';
// import '../../service/dockey_service.dart';
// import '../loginScreen/fetchUserAccess.dart';
//
//
// /// List of dockets for a given type. Optional depot filter:
// /// - depot == null or 'All' → show all depots
// /// - otherwise show only that depot
// class ShowDocketsList extends StatefulWidget {
//   final String title;     // docket type
//   final String? depot;    // null or 'All' -> all depots
//
//   const ShowDocketsList({super.key, required this.title, this.depot});
//
//   @override
//   State<ShowDocketsList> createState() => _ShowDocketsListState();
// }
//
// class _ShowDocketsListState extends State<ShowDocketsList> {
//   final _svc = DocketService();
//   late Future<List<Docket>> _future;
//
//   @override
//   void initState() {
//     super.initState();
//     _future = _svc.fetchDockets();
//   }
//
//   Future<void> _reload() async {
//     setState(() {
//       _future = _svc.fetchDockets();
//     });
//     await _future;
//   }
//
//   bool _isAllDepots(String? depot) =>
//       depot == null || depot.trim().isEmpty || depot.toLowerCase() == 'all';
//
//   @override
//   Widget build(BuildContext context) {
//     // grab current user's depot in case the caller forgot to pass one
//     final ua = context.read<UserAccess>();
//     final filterDepot = _isAllDepots(widget.depot) ? null : widget.depot ?? ua.depot;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           _isAllDepots(filterDepot)
//               ? 'Dockets • ${widget.title}'
//               : 'Dockets • ${widget.title} • ${filterDepot!}',
//         ),
//         backgroundColor: const Color(0xFF003366),
//         foregroundColor: Colors.white,
//       ),
//       body: SafeArea(
//         child: FutureBuilder<List<Docket>>(
//           future: _future,
//           builder: (context, snap) {
//             if (snap.connectionState == ConnectionState.waiting) {
//               return const Center(
//                 child: CircularProgressIndicator(color: Color(0xFF003366)),
//               );
//             }
//             if (snap.hasError) {
//               return _ErrorState(
//                 message: 'Failed to load dockets:\n${snap.error}',
//                 onRetry: _reload,
//               );
//             }
//             final all = (snap.data ?? <Docket>[]);
//             final filtered = all.where((d) {
//               final sameType = (d.docketType ?? '').toLowerCase().trim() ==
//                   widget.title.toLowerCase().trim();
//               if (!sameType) return false;
//               if (filterDepot == null) return true; // all depots
//               return (d.depot ?? '').toLowerCase().trim() ==
//                   filterDepot.toLowerCase().trim();
//             }).toList()
//               ..sort((a, b) {
//                 // newest first if possible
//                 final at = _parse(a.uploadedTime);
//                 final bt = _parse(b.uploadedTime);
//                 return bt.compareTo(at);
//               });
//
//             if (filtered.isEmpty) {
//               return _EmptyState(
//                 title: 'No dockets found',
//                 subtitle: _isAllDepots(filterDepot)
//                     ? 'There are no "${widget.title}" dockets yet.'
//                     : 'No "${widget.title}" dockets for depot "$filterDepot".',
//                 onRefresh: _reload,
//               );
//             }
//
//             return RefreshIndicator(
//               onRefresh: _reload,
//               color: const Color(0xFF003366),
//               child: ListView.separated(
//                 physics: const AlwaysScrollableScrollPhysics(),
//                 padding: const EdgeInsets.all(16),
//                 itemCount: filtered.length,
//                 separatorBuilder: (_, __) => const SizedBox(height: 12),
//                 itemBuilder: (context, i) => _DocketListTile(
//                   docket: filtered[i],
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => DocketDetailsPage(docket: filtered[i]),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
//
//   DateTime _parse(String? ts) {
//     if (ts == null || ts.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
//     // try common formats
//     try {
//       return DateTime.parse(ts); // 2025-08-29 10:18:24 or ISO
//     } catch (_) {
//       try {
//         return DateFormat('yyyy-MM-dd HH:mm:ss').parse(ts);
//       } catch (_) {
//         return DateTime.fromMillisecondsSinceEpoch(0);
//       }
//     }
//   }
// }
//
// class _DocketListTile extends StatelessWidget {
//   final Docket docket;
//   final VoidCallback onTap;
//
//   const _DocketListTile({required this.docket, required this.onTap});
//
//   // Map docket type → remote image subdirectory index
//   int _dirForType(String type) {
//     switch (type.toLowerCase()) {
//       case 'service line maintenance':
//         return 1;
//       case 'meter testing':
//         return 2;
//       case 'estimate':
//         return 3;
//       default:
//         return 4; // everything else
//     }
//   }
//
//   String _imageUrl(Docket d) {
//     final type = d.docketType ?? '';
//     final dir = _dirForType(type);
//     final file = d.imageName ?? '';
//     return 'http://124.43.181.243:8000/api/fetch-testdocket-image/$dir/$file';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final uploaded =
//     docket.uploadedTime == null || docket.uploadedTime!.isEmpty
//         ? '-'
//         : docket.uploadedTime!;
//     final uploadedBy = docket.uploadedBy?.isNotEmpty == true
//         ? docket.uploadedBy!
//         : 'Unknown';
//     final depot = docket.depot ?? '-';
//
//     return Material(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(12),
//       elevation: 2,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Container(
//           padding: const EdgeInsets.all(12),
//           child: Row(
//             children: [
//               // tiny thumbnail
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(8),
//                 child: SizedBox(
//                   width: 64,
//                   height: 64,
//                   child: Image.network(
//                     _imageUrl(docket),
//                     fit: BoxFit.cover,
//                     errorBuilder: (_, __, ___) => Container(
//                       color: const Color(0xFFF1F3F6),
//                       child: const Icon(Icons.image_not_supported, size: 28),
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               // text
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       docket.imageName ?? '(no file)',
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontWeight: FontWeight.w700,
//                         fontSize: 15,
//                         color: Color(0xFF003366),
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       'Depot: $depot  •  By: $uploadedBy',
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(color: Colors.black87),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       'Uploaded: $uploaded',
//                       style: const TextStyle(color: Colors.black54, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 8),
//               const Icon(Icons.chevron_right, color: Colors.black45),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _EmptyState extends StatelessWidget {
//   final String title;
//   final String? subtitle;
//   final Future<void> Function() onRefresh;
//
//   const _EmptyState({
//     required this.title,
//     this.subtitle,
//     required this.onRefresh,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return RefreshIndicator(
//       onRefresh: onRefresh,
//       color: const Color(0xFF003366),
//       child: ListView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         children: [
//           SizedBox(height: MediaQuery.of(context).size.height * 0.2),
//           const Icon(Icons.inbox, size: 64, color: Colors.black26),
//           const SizedBox(height: 12),
//           Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
//           if (subtitle != null) ...[
//             const SizedBox(height: 6),
//             Text(
//               subtitle!,
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: Colors.black54),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }
//
// class _ErrorState extends StatelessWidget {
//   final String message;
//   final VoidCallback onRetry;
//
//   const _ErrorState({required this.message, required this.onRetry});
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
//             const SizedBox(height: 12),
//             ElevatedButton(
//               onPressed: onRetry,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF003366),
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
