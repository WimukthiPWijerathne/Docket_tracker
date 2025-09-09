import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../service/dockey_service.dart';
import '../models/dockets.dart';
import '../pages/assign.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:io' show Platform;

class ShowDocketsPage extends StatefulWidget {
  final String title;

  const ShowDocketsPage({super.key, required this.title});

  @override
  State<ShowDocketsPage> createState() => _ShowDocketsPageState();
}

class _ShowDocketsPageState extends State<ShowDocketsPage>
    with TickerProviderStateMixin {
  final DocketService _docketService = DocketService();
  final TextEditingController _searchController = TextEditingController();
  List<Docket> dockets = [];
  List<Docket> filteredDockets = [];
  List<bool> status = [];
  bool isLoading = true;
  bool isRefreshing = false;
  String? errorMessage;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  bool _isSearchExpanded = false;

  // API bases
  static const String httpImageBase = 'http://124.43.181.243:8000';

  @override
  void initState() {
    super.initState();
    _loadDockets();
    _searchController.addListener(_onSearchChanged);
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredDockets = dockets.where((docket) {
        return docket.docketType.toLowerCase().contains(query) ||
               docket.depot.toLowerCase().contains(query) ||
               docket.docketSerial.toLowerCase().contains(query);
      }).toList();
      // Reset status array when search results change
      status = List<bool>.filled(filteredDockets.length, false);
    });
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
    return httpImageBase;
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

  Future<void> _loadDockets({bool isRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      if (!isRefresh) {
        isLoading = true;
      } else {
        isRefreshing = true;
      }
      errorMessage = null;
    });

    try {
      final fetchedDockets = await _docketService.fetchDockets();
      if (mounted) {
        setState(() {
          dockets = fetchedDockets;
          filteredDockets = fetchedDockets
              .where((docket) => docket.docketType == widget.title)
              .toList();
          status = List<bool>.filled(filteredDockets.length, false);
          isLoading = false;
          isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
          isRefreshing = false;
          dockets = _generateDummyDockets();
          filteredDockets = dockets.where((docket) => docket.docketType == widget.title).toList();
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
        assignedTo: index % 3 == 0 ? 'John Doe' : '',
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
      _showSnackBar(
        'Please select at least one docket',
        Colors.orange,
        Icons.info_outline,
      );
      return;
    }

    final selectedDockets =
        selectedIndices.map((i) => filteredDockets[i]).toList();

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignPage(
          dockets: selectedDockets,
          depot: 'All',
        ),
      ),
    );

    // If assignment was successful, refresh the data
    if (result == true) {
      _loadDockets(isRefresh: true);
      setState(() {
        status = List<bool>.filled(filteredDockets.length, false);
      });
      _fabAnimationController.reverse();
    }
  }

  void _onCancel() {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < status.length; i++) {
        status[i] = false;
      }
    });
    _fabAnimationController.reverse();
    _showSnackBar(
      'All selections cleared',
      Colors.green,
      Icons.check_circle_outline,
    );
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.red[400],
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Unable to load dockets',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your connection and try again',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _loadDockets,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No dockets found',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchController.text.isNotEmpty
                    ? 'Try adjusting your search terms'
                    : 'New dockets will appear here when available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocketCard(Docket docket, int index) {
    final bool isSelected = status[index];
    final formattedDate = _formatDate(docket.uploadedTime);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF003366) : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected 
                ? const Color(0xFF003366).withOpacity(0.15)
                : Colors.black.withOpacity(0.06),
            blurRadius: isSelected ? 12 : 6,
            offset: const Offset(0, 3),
            spreadRadius: isSelected ? 1 : 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              status[index] = !status[index];
              if (status.any((s) => s)) {
                _fabAnimationController.forward();
              } else {
                _fabAnimationController.reverse();
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with checkbox and status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Custom animated checkbox
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF003366) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF003366) : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Docket number
                    Expanded(
                      child: Text(
                        'Docket #${docket.docketSerial}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF003366),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    
                    // Status badge
                    _buildStatusBadge(docket.assignedTo),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Location with icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.blue[600],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        docket.depot,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Bottom row with date and actions
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    
                    // Image preview button
                    if (docket.imageName != null && docket.imageName!.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.photo_library_outlined,
                            color: Colors.green[600],
                            size: 20,
                          ),
                          onPressed: () => _showImagePreview(docket),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          tooltip: 'View Image',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? assignedTo) {
    final bool isAssigned = assignedTo != null && assignedTo.isNotEmpty;
    final color = isAssigned ? Colors.green : Colors.orange;
    final text = isAssigned ? 'Assigned' : 'Pending';
    final icon = isAssigned ? Icons.assignment_turned_in : Icons.schedule;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null || status.isEmpty) return Colors.grey;
    if (status.toLowerCase().contains('complete')) return Colors.green;
    if (status.toLowerCase().contains('pending')) return Colors.orange;
    return Colors.blue;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;
      
      if (difference == 0) {
        return 'Today • ${DateFormat('hh:mm a').format(date)}';
      } else if (difference == 1) {
        return 'Yesterday • ${DateFormat('hh:mm a').format(date)}';
      } else if (difference < 7) {
        return '${difference}d ago • ${DateFormat('hh:mm a').format(date)}';
      } else {
        return DateFormat('MMM d, y • hh:mm a').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  void _showImagePreview(Docket docket) {
    if (docket.imageName == null || docket.imageName!.isEmpty) return;
    
    final imageUrl = _imageUrlFor(docket.docketType, docket.imageName!);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      placeholder: (context, url) => Container(
                        height: 300,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 300,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, 
                                color: Colors.white, 
                                size: 48,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Unable to load image',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = status.where((s) => s).length;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Text(
              '${filteredDockets.length} ${filteredDockets.length == 1 ? 'docket' : 'dockets'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF003366),
        elevation: 0,
        centerTitle: false,
        actions: [
          if (selectedCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$selectedCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle, color: Colors.white, size: 16),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced search bar
          Container(
            color: const Color(0xFF003366),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search by docket number, location...',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600], size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: Colors.grey[600], size: 20),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  isDense: true,
                ),
              ),
            ),
          ),
          
          // Selection summary bar
          if (selectedCount > 0)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[50]!, Colors.blue[100]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.checklist, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$selectedCount ${selectedCount == 1 ? 'docket' : 'dockets'} selected',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _onCancel,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear All'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          
          // Main content
          Expanded(
            child: Builder(
              builder: (context) {
                if (isLoading) {
                  return _buildLoadingShimmer();
                } else if (errorMessage != null) {
                  return _buildErrorState();
                } else if (filteredDockets.isEmpty) {
                  return _buildEmptyState();
                } else {
                  return RefreshIndicator(
                    onRefresh: () => _loadDockets(isRefresh: true),
                    color: const Color(0xFF003366),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 12, bottom: 100),
                      itemCount: filteredDockets.length,
                      itemBuilder: (context, index) {
                        final docket = filteredDockets[index];
                        return _buildDocketCard(docket, index);
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      // Enhanced floating action button
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: FloatingActionButton.extended(
          onPressed: _onAssign,
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
          elevation: 8,
          icon: const Icon(Icons.assignment_ind_rounded, size: 22),
          label: Text(
            'Assign ${selectedCount > 1 ? '($selectedCount)' : ''}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}