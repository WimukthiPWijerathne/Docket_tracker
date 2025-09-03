import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
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
    final encodedName = Uri.encodeComponent(safeName);
    final url = '${_imageBaseForPlatform()}/api/fetch-testdocket-image/$type/$encodedName';
    
    // Debug log the URL
    debugPrint('🔍 Generated image URL: $url');
    debugPrint('  - Base: ${_imageBaseForPlatform()}');
    debugPrint('  - Type: $type (from "$docketType")');
    debugPrint('  - Original name: $imageName');
    debugPrint('  - Safe name: $safeName');
    debugPrint('  - Encoded name: $encodedName');
    
    return url;
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

  Widget _buildDocketCard(Docket docket, int index) {
    final isSelected = status[index];
    final imageUrl = docket.imageName != null
        ? _imageUrlFor(docket.docketType, docket.imageName!)
        : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Color(0xFF003366), width: 2)
            : BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            status[index] = !status[index];
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with selection and basic info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE8F4FD) : null,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        status[index] = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF003366),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${docket.docketSerial}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF003366),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          docket.depot,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003366).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      docket.uploadedTime,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF003366),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Image preview
            if (imageUrl != null)
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF003366),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Footer with actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      // View details action
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      // Share action
                    },
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF003366),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterDockets(String query) {
    setState(() {
      filteredDockets = dockets
          .where((docket) {
            final titleMatch = docket.docketType.toLowerCase().contains(query.toLowerCase());
            final depotMatch = docket.depot.toLowerCase().contains(query.toLowerCase());
            final serialMatch = docket.docketSerial.toLowerCase().contains(query.toLowerCase());
            return titleMatch || depotMatch || serialMatch;
          })
          .where((docket) => docket.docketType == widget.title)
          .toList();
      status = List<bool>.filled(filteredDockets.length, false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;
    final crossAxisCount = isWideScreen ? 2 : 1;
    final childAspectRatio = isWideScreen ? 2.5 : 3.0;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search dockets...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: _filterDockets,
              )
            : Text(
                '${widget.title} Dockets',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
        backgroundColor: const Color(0xFF003366),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterDockets('');
                }
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDockets,
        color: const Color(0xFF003366),
        child: _buildBody(crossAxisCount, childAspectRatio),
      ),
      floatingActionButton: status.any((element) => element)
          ? Padding(
              padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'cancel',
                    onPressed: _onCancel,
                    backgroundColor: Colors.grey[600],
                    child: const Icon(Icons.clear, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.extended(
                    heroTag: 'assign',
                    onPressed: _onAssign,
                    backgroundColor: const Color(0xFF003366),
                    icon: const Icon(Icons.assignment_ind, color: Colors.white),
                    label: const Text('Assign Selected', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildBody(int crossAxisCount, double childAspectRatio) {
    if (isLoading) {
      return _buildLoadingGrid(crossAxisCount, childAspectRatio);
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (filteredDockets.isEmpty) {
      return _buildEmptyState();
    }

    return _buildDocketsGrid(crossAxisCount, childAspectRatio);
  }

  Widget _buildLoadingGrid(int crossAxisCount, double childAspectRatio) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Card(
      elevation: 2,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 20,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 16,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[200],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load dockets',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'An unknown error occurred',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadDockets,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF003366),
                    side: const BorderSide(color: Color(0xFF003366)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      dockets = _generateDummyDockets();
                      filteredDockets = dockets
                          .where((docket) => docket.docketType == widget.title)
                          .toList();
                      status = List<bool>.filled(filteredDockets.length, false);
                      errorMessage = null;
                    });
                  },
                  icon: const Icon(Icons.visibility, size: 20),
                  label: const Text('Use Demo Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No dockets found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or check back later',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDockets,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocketsGrid(int crossAxisCount, double childAspectRatio) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: filteredDockets.length,
      itemBuilder: (context, index) {
        final docket = filteredDockets[index];
        return _buildDocketCard(docket, index);
      },
    );
  }
}
