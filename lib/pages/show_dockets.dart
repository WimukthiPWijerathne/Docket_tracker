import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../service/dockey_service.dart';
import '../models/dockets.dart';
import '../pages/assign.dart';

class ShowDocketsPage extends StatefulWidget {
  final String title;

  const ShowDocketsPage({super.key, required this.title});

  @override
  State<ShowDocketsPage> createState() => _ShowDocketsPageState();
}

class _ShowDocketsPageState extends State<ShowDocketsPage> {
  final DocketService _docketService = DocketService();
  List<Docket> dockets = [];
  List<Docket> filteredDockets = [];
  List<bool> status = [];
  bool isLoading = true;
  String? errorMessage;

  // ✅ Depot filter
  final List<String> depots = ['All', 'Kadana', 'Mahara', 'Paliyagoda', 'Wattala'];
  String selectedDepot = 'All';

  static const String httpImageBase = 'http://124.43.181.243:8000';

  @override
  void initState() {
    super.initState();
    _loadDockets();
  }

  String _getDocketTypeNumber(String docketType) {
    switch (docketType.toLowerCase().trim()) {
      case 'service line maintainance':
      case 'service line maintenance':
        return '1';
      case 'meter testing':
        return '2';
      case 'estimate':
        return '3';
      default:
        return '4';
    }
  }

  String _imageBaseForPlatform() => httpImageBase;

  bool _hasImageExtension(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  String _safeImageName(String name) {
    return _hasImageExtension(name) ? name : '$name.jpg';
  }

  String _imageUrlFor(String docketType, String imageName) {
    final type = _getDocketTypeNumber(docketType);
    final safeName = _safeImageName(imageName);
    return '${_imageBaseForPlatform()}/api/fetch-testdocket-image/$type/$safeName';
  }

  Future<void> _loadDockets() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final fetchedDockets = await _docketService.fetchDockets();
      if (mounted) {
        // Filter by docket type and depot
        final filtered = fetchedDockets
            .where((docket) => docket.docketType == widget.title)
            .where((docket) =>
                selectedDepot == 'All' ? true : docket.depot == selectedDepot)
            .toList();

        setState(() {
          dockets = fetchedDockets;
          filteredDockets = filtered;
          status = List<bool>.filled(filteredDockets.length, false);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
          dockets = _generateDummyDockets();
          filteredDockets = dockets
              .where((docket) => docket.docketType == widget.title)
              .where((docket) =>
                  selectedDepot == 'All' ? true : docket.depot == selectedDepot)
              .toList();
          status = List<bool>.filled(filteredDockets.length, false);
        });
      }
    }
  }

  List<Docket> _generateDummyDockets() {
    return List.generate(6, (index) {
      final DateTime date = DateTime.now().subtract(Duration(days: index));
      final String formatted =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return Docket(
        id: 'dummy_${index + 1}',
        docketType: widget.title,
        depot: depots[(index % (depots.length - 1)) + 1], // rotate depots
        imageName: 'sample_image_${index + 1}.jpg',
        uploadedBy: 'User ${index + 1}',
        uploadedTime: formatted,
        assignedTo: '',
        assignTime: '',
        completedTime: '',
        docketSerial: 'DS${index + 1}'.padLeft(6, '0'),
      );
    });
  }

  Future<void> _onAssign() async {
    if (!mounted) return;

    final selectedIndices = <int>[];
    for (int i = 0; i < status.length; i++) {
      if (status[i]) selectedIndices.add(i);
    }

    if (selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one docket'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedDockets =
        selectedIndices.map((i) => filteredDockets[i]).toList();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignPage(
          dockets: selectedDockets,
          depot: selectedDepot,
        ),
      ),
    );
  }

  void _onCancel() {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < status.length; i++) {
        status[i] = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All selections cancelled'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildSimpleRow(
    String date,
    String location,
    String docketType,
    String? imageName,
    bool isSelected,
    int index, {
    bool isHeader = false,
  }) {
    if (isHeader) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF003366).withOpacity(0.1),
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: const Row(
          children: [
            Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366)))),
            Expanded(flex: 2, child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366)))),
            Expanded(flex: 2, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366)))),
            Expanded(flex: 2, child: Text('Docket Image', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366)))),
            Expanded(flex: 1, child: Center(child: Text('Select', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366))))),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () {
        if (mounted) {
          setState(() {
            status[index] = !status[index];
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF003366).withOpacity(0.05) : Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(date, style: const TextStyle(fontSize: 12))),
            Expanded(flex: 2, child: Text(location, style: const TextStyle(fontSize: 12))),
            Expanded(flex: 2, child: Text(docketType, style: const TextStyle(fontSize: 12))),
            Expanded(flex: 2, child: Text(imageName ?? 'No image', style: const TextStyle(fontSize: 12))),
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(color: isSelected ? const Color(0xFF003366) : Colors.grey),
                    borderRadius: BorderRadius.circular(3),
                    color: isSelected ? const Color(0xFF003366) : Colors.transparent,
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double rowHeight = 56.0;
    const double headerHeight = 56.0;
    const double maxHeight = 400.0;

    double contentHeight = headerHeight + (filteredDockets.length * rowHeight);
    double tableHeight = contentHeight > maxHeight ? maxHeight : contentHeight;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDockets),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 8),
            Text('Total: ${filteredDockets.length} dockets',
                style: const TextStyle(fontSize: 16, color: Color(0xFF666666))),
            const SizedBox(height: 16),

            // ✅ Depot filter dropdown
            Row(
              children: [
                const Text("Filter by Depot: ",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: selectedDepot,
                  items: depots.map((depot) {
                    return DropdownMenuItem<String>(
                      value: depot,
                      child: Text(depot),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedDepot = value;
                      });
                      _loadDockets();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('API Error: Using demo data. $errorMessage',
                            style: const TextStyle(color: Colors.orange))),
                  ],
                ),
              ),

            // Table
            Container(
              height: tableHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildSimpleRow('Date', 'Location', 'Type', null, false, -1, isHeader: true),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredDockets.isEmpty
                            ? Center(child: Text('No dockets available for "${widget.title}"'))
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: filteredDockets.length,
                                itemBuilder: (context, index) {
                                  final docket = filteredDockets[index];
                                  return _buildSimpleRow(
                                    docket.uploadedTime.isNotEmpty ? docket.uploadedTime : 'N/A',
                                    docket.depot.isNotEmpty ? docket.depot : 'Unknown Location',
                                    docket.docketType.isNotEmpty ? docket.docketType : 'Unknown Type',
                                    docket.imageName,
                                    status.length > index ? status[index] : false,
                                    index,
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _onAssign,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Assign',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _onCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
