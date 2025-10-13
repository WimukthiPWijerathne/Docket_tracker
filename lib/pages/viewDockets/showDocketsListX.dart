// lib/pages/viewDockets/showDocketsListX.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/docketsX.dart';
import '../../service/dockey_serviceX.dart';
import '../loginScreen/fetchUserAccess.dart';
import 'showDocketDetailsX.dart';

/// List of dockets for a given type, honoring optional depot + status filters.
/// - depot == null or 'All' → show all depots
/// - filterStatus: -1 = All, 0..4 (Unassigned, Assigned, Completed, Reassigned, Issue)
class ShowDocketsListX extends StatefulWidget {
  final String title; // docket type
  final String? depot; // null or 'All' -> all depots
  final int? filterStatus; // -1 (All) or 0..4

  const ShowDocketsListX({
    super.key,
    required this.title,
    this.depot,
    this.filterStatus,
  });

  @override
  State<ShowDocketsListX> createState() => _ShowDocketsListXState();
}

class _ShowDocketsListXState extends State<ShowDocketsListX> {
  final _svc = DocketServiceX();
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
      '[ShowDocketsListX] Opened with -> '
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

  /// Read status from the Docket model.
  int _statusOf(Docket d) {
    try {
      final s = d.status.toString().trim();
      return int.tryParse(s) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resolve filters coming from summary page (or fallback to user's depot)
    String? userDepot;
    try {
      // Try to get UserAccess, but don't crash if not available
      final ua = context.read<UserAccess>();
      userDepot = ua.depot;
    } catch (e) {
      // If UserAccess provider is not found, no depot fallback
      userDepot = null;
    }

    final effectiveDepot = _isAllDepots(widget.depot)
        ? null
        : (widget.depot ?? userDepot);

    final int effectiveStatus = (widget.filterStatus == null)
        ? -1
        : widget.filterStatus!;
    final statusLabel = _statusLabel[effectiveStatus] ?? 'All';

    // 🔎 Debug: resolved filters
    debugPrint(
      '[ShowDocketsListX] Resolved filters -> '
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
              debugPrint('[ShowDocketsListX] Error: ${snap.error}');
              return _ErrorState(
                message: 'Failed to load dockets:\n${snap.error}',
                onRetry: _reload,
              );
            }

            final all = (snap.data ?? <Docket>[]);
            debugPrint('[ShowDocketsListX] Total fetched: ${all.length}');

            // Step 1: Type filter
            var step = all.where(
              (d) =>
                  d.docketType.toLowerCase().trim() ==
                  widget.title.toLowerCase().trim(),
            );
            debugPrint(
              '[ShowDocketsListX] After type("${widget.title}"): ${step.length}',
            );

            // Step 2: Depot filter (if any)
            if (effectiveDepot != null) {
              final dep = effectiveDepot.toLowerCase().trim();
              step = step.where((d) => d.depot.toLowerCase().trim() == dep);
              debugPrint(
                '[ShowDocketsListX] After depot("$dep"): ${step.length}',
              );
            } else {
              debugPrint('[ShowDocketsListX] Depot filter: ALL');
            }

            // Step 3: Status filter
            if (effectiveStatus != -1) {
              final st = effectiveStatus;
              // Debug summary of status values in current data set
              final statusCounts = <int, int>{};
              step.forEach((d) {
                final status = _statusOf(d);
                statusCounts[status] = (statusCounts[status] ?? 0) + 1;
              });

              debugPrint(
                '[Status Debug] Status counts before filtering: $statusCounts',
              );
              step = step.where((d) => _statusOf(d) == st);
              debugPrint(
                '[ShowDocketsListX] After status($st): ${step.length}',
              );
            } else {
              debugPrint('[ShowDocketsListX] Status filter: ALL');
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
                  onTap: () => _viewDocket(context, filtered[i]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  DateTime _parse(String date) {
    try {
      return DateTime.parse(date);
    } catch (_) {
      return DateTime(1970);
    }
  }

  Future<void> _viewDocket(BuildContext context, Docket docket) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocketDetailsXPage(docket: docket),
      ),
    );

    if (result == true) {
      _reload(); // Refresh if docket was updated
    }
  }
}

class _DocketListTile extends StatelessWidget {
  final Docket docket;
  final VoidCallback onTap;

  const _DocketListTile({required this.docket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Extract data
    final type = docket.docketType;
    final id = docket.id;

    // Format date
    final formatter = DateFormat('MMM dd, yyyy • hh:mm a');
    final uploaded = (docket.uploadedTime.isEmpty)
        ? '-'
        : formatter.format(DateTime.parse(docket.uploadedTime));

    // Other fields
    final depot = docket.depot;
    final status = _getStatusLabel(docket.status);
    final statusColor = _getStatusColor(docket.status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    type,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('ID: $id', style: const TextStyle(color: Colors.black87)),
              Text(
                'Depot: $depot',
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      docket.imageName,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    uploaded,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusLabel(String statusStr) {
    final status = int.tryParse(statusStr) ?? 0;
    switch (status) {
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

  Color _getStatusColor(String statusStr) {
    final status = int.tryParse(statusStr) ?? 0;
    switch (status) {
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
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onRefresh;

  const _EmptyState({
    required this.title,
    this.subtitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRefresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
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
