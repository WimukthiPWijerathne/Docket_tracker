import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'pendingDocketsApproving.dart';

class PendingDocketsPage extends StatefulWidget {
	const PendingDocketsPage({super.key});

	@override
	State<PendingDocketsPage> createState() => _PendingDocketsPageState();
}

class _PendingDocketsPageState extends State<PendingDocketsPage> {
	late Future<List<Map<String, dynamic>>> _pendingFuture;

	@override
	void initState() {
		super.initState();
		_pendingFuture = _fetchPending();
	}

	Future<List<Map<String, dynamic>>> _fetchPending() async {
		final uri = Uri.parse('https://powerprox.sltidc.lk/GETEDockets.php');
		debugPrint('[PendingDockets] Fetching from: $uri');
		final res = await http.get(uri);
		debugPrint('[PendingDockets] Response status: ${res.statusCode}, bytes: ${res.bodyBytes.length}');
		debugPrint('[PendingDockets] Raw response: ${res.body}');
		
		if (res.statusCode != 200) {
			throw Exception('Failed to load pending dockets (${res.statusCode})');
		}

		// Parse the JSON response
		final dynamic decoded = jsonDecode(res.body);
		debugPrint('[PendingDockets] Decoded type: ${decoded.runtimeType}');

		List<dynamic> list = [];

		// Handle different response formats
		if (decoded is List) {
			// Direct array response
			list = decoded;
		} else if (decoded is Map<String, dynamic>) {
			// Object response - check common wrapper keys
			if (decoded.containsKey('data')) {
				list = decoded['data'] is List ? decoded['data'] : [];
			} else if (decoded.containsKey('dockets')) {
				list = decoded['dockets'] is List ? decoded['dockets'] : [];
			} else if (decoded.containsKey('items')) {
				list = decoded['items'] is List ? decoded['items'] : [];
			} else {
				// If no wrapper key found, treat the object as a single item
				list = [decoded];
			}
		}

		debugPrint('[PendingDockets] Total items: ${list.length}');

		// Filter to status == '0' (pending)
		final pending = list
			.whereType<Map<String, dynamic>>()
			.where((m) => (m['status']?.toString() ?? '') == '0')
			.toList();
		
		debugPrint('[PendingDockets] Pending items (status==0): ${pending.length}');
		final sample = pending
			.take(5)
			.map((m) => '${m['docketNo']}@${m['depot']}')
			.join(', ');
		if (sample.isNotEmpty) {
			debugPrint('[PendingDockets] Sample: $sample');
		}
		
		return pending.cast<Map<String, dynamic>>();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Pending Dockets'),
			),
			body: FutureBuilder<List<Map<String, dynamic>>>(
				future: _pendingFuture,
				builder: (context, snapshot) {
					if (snapshot.connectionState == ConnectionState.waiting) {
						return const Center(child: CircularProgressIndicator());
					}
					if (snapshot.hasError) {
						return Center(
							child: Padding(
								padding: const EdgeInsets.all(16.0),
								child: Text(
									'Error: ${snapshot.error}',
									textAlign: TextAlign.center,
								),
							),
						);
					}
					final data = snapshot.data ?? const <Map<String, dynamic>>[];
					if (data.isEmpty) {
						return const Center(
							child: Text('No pending dockets to approve.'),
						);
					}

					return RefreshIndicator(
						onRefresh: () async {
							debugPrint('[PendingDockets] Pull-to-refresh triggered');
							setState(() {
								_pendingFuture = _fetchPending();
							});
							await _pendingFuture;
							debugPrint('[PendingDockets] Refresh completed');
						},
						child: ListView.separated(
							physics: const AlwaysScrollableScrollPhysics(),
							padding: const EdgeInsets.all(16),
							itemBuilder: (context, index) {
								final item = data[index];
								final docketNo = item['docketNo']?.toString() ?? '-';
								final docketType = item['errorTypes']?.toString() ?? '-';
								final depot = item['depot']?.toString() ?? '-';

								return Card(
									elevation: 2,
									shape: RoundedRectangleBorder(
										borderRadius: BorderRadius.circular(12),
									),
									child: ListTile(
										contentPadding:
											const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
										title: Text(
											'Docket: $docketNo',
											style: const TextStyle(fontWeight: FontWeight.w600),
										),
										subtitle: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												const SizedBox(height: 4),
												Text('Type: $docketType'),
												Text('Depot: $depot'),
											],
										),
									trailing: const Icon(Icons.chevron_right),
									onTap: () async {
										debugPrint('[PendingDockets] Navigating to detail for docket: ${item['docketNo']}');
										debugPrint('[PendingDockets] Docket data: ${jsonEncode(item)}');
										debugPrint('[PendingDockets] imageNames field: ${item['imageNames']}');
										final result = await Navigator.of(context).push(
											MaterialPageRoute(
												builder: (_) => PendingDocketsApprovingPage(docket: item),
											),
										);
										// If the user approved/rejected, refresh the list
										if (result == true && mounted) {
											debugPrint('[PendingDockets] Refreshing list after approval/rejection');
											setState(() {
												_pendingFuture = _fetchPending();
											});
										}
									},
									),
								);
							},
							separatorBuilder: (_, __) => const SizedBox(height: 12),
							itemCount: data.length,
						),
					);
				},
			),
		);
	}
}