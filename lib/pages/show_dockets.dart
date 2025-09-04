import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  // API bases
  // static const String httpsImageBase = 'https://powerprox.sltidc.lk'; 
  static const String httpImageBase = 'http://124.43.136.185:8000';

  @override
  void initState() {
    super.initState();
    _loadDockets();
  }

  // Map docket type strings to numeric IDs expected by backend
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

  // Pick base URL depending on platform
  String _imageBaseForPlatform() {
    return  httpImageBase;
  }

  // Check if name already has an extension
  bool _hasImageExtension(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  // Ensure image name ends with extension
  String _safeImageName(String name) {
    return _hasImageExtension(name) ? name : '$name.jpg';
  }

  // Build final image URL
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
        final filtered = fetchedDockets
            .where((docket) => docket.docketType == widget.title)
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
          filteredDockets =
              dockets.where((docket) => docket.docketType == widget.title).toList();
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
        depot: 'Location ${index + 1}',
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
        builder: (context) => AssignPage(dockets: selectedDockets),
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
            Expanded(flex: 2, child: _buildImageCell(imageName, docketType)),
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

  Widget _buildImageCell(String? imageName, String docketType) {
    if (imageName == null || imageName.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.image_not_supported, size: 16, color: Colors.grey),
          SizedBox(width: 4),
          Expanded(
            child: Text('No image', style: TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    }

    final String imageUrl = _imageUrlFor(docketType, imageName);

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: const Color(0xFF003366).withOpacity(0.1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              imageUrl,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Image loading error: $error');
                debugPrint('Failed URL: $imageUrl');
                return const Icon(Icons.broken_image, size: 16, color: Colors.grey);
              },
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            onTap: () => _showImageDialog(imageName, docketType),
            child: Text(
              imageName,
              style: const TextStyle(fontSize: 11, color: Color(0xFF003366), decoration: TextDecoration.underline),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  void _showImageDialog(String imageName, String docketType) {
    final String imageUrl = _imageUrlFor(docketType, imageName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF003366),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Docket Image',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 48),
                              const Text("Failed to load image"),
                              SelectableText("URL: $imageUrl\nError: $error"),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
            Text(widget.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 8),
            Text('Total: ${filteredDockets.length} dockets', style: const TextStyle(fontSize: 16, color: Color(0xFF666666))),
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
                    Expanded(child: Text('API Error: Using demo data. $errorMessage', style: const TextStyle(color: Colors.orange))),
                  ],
                ),
              ),
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
                    child: const Text('Assign', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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