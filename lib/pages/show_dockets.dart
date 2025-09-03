import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http; // Add this import for debugging
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

  static const String httpImageBase = 'http://124.43.136.185:8000';

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

  String _imageBaseForPlatform() {
    return httpImageBase;
  }

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

  // Add this method to debug image URLs and server connectivity
  Future<void> _debugImageResponse(String url) async {
    debugPrint('=== IMAGE RESPONSE DEBUG START ===');
    debugPrint('Testing URL: $url');
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'image/*'},
      );
      
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Content-Type: ${response.headers['content-type']}');
      debugPrint('Content-Length: ${response.headers['content-length']}');
      
      if (response.statusCode == 200) {
        debugPrint('First 100 bytes: ${response.bodyBytes.take(100).toList()}');
      } else {
        debugPrint('Error response: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    
    debugPrint('=== IMAGE RESPONSE DEBUG END ===');
  }

  Future<void> _debugImageUrl(String url) async {
    debugPrint('=== IMAGE URL DEBUG START ===');
    debugPrint('Testing URL: $url');
    
    try {
      // First, test basic server connectivity
      final baseUri = Uri.parse(httpImageBase);
      debugPrint('Testing base server connectivity: $httpImageBase');
      
      final pingResponse = await http.get(baseUri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Server connection timeout');
        },
      );
      
      debugPrint('Base server response: ${pingResponse.statusCode}');
      
      // Now test the specific image URL
      final imageUri = Uri.parse(url);
      debugPrint('Testing image URL with HEAD request...');
      
      final response = await http.head(imageUri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Image URL timeout');
        },
      );
      
      debugPrint('Image URL Response:');
      debugPrint('  Status Code: ${response.statusCode}');
      debugPrint('  Content-Type: ${response.headers['content-type'] ?? 'Not specified'}');
      debugPrint('  Content-Length: ${response.headers['content-length'] ?? 'Not specified'}');
      debugPrint('  Server: ${response.headers['server'] ?? 'Not specified'}');
      
      if (response.statusCode != 200) {
        debugPrint('  ❌ Non-200 response - server error or missing file');
      } else {
        debugPrint('  ✅ Server responded successfully');
      }
      
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('image/')) {
        debugPrint('  ⚠️  WARNING: Content-Type is not an image type: $contentType');
      }
      
      // Try a GET request to see actual content
      if (response.statusCode == 200) {
        debugPrint('Attempting GET request to verify content...');
        final getResponse = await http.get(imageUri).timeout(
          const Duration(seconds: 15),
        );
        debugPrint('GET response length: ${getResponse.bodyBytes.length} bytes');
        
        // Check if it's actually image data
        if (getResponse.bodyBytes.length > 0) {
          final firstBytes = getResponse.bodyBytes.take(10).toList();
          debugPrint('First 10 bytes: ${firstBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          
          // Check for common image file signatures
          if (firstBytes.length >= 2) {
            if (firstBytes[0] == 0xFF && firstBytes[1] == 0xD8) {
              debugPrint('  ✅ Detected JPEG image signature');
            } else if (firstBytes.length >= 8 && 
                      firstBytes[0] == 0x89 && firstBytes[1] == 0x50 && 
                      firstBytes[2] == 0x4E && firstBytes[3] == 0x47) {
              debugPrint('  ✅ Detected PNG image signature');
            } else {
              debugPrint('  ❌ Does not appear to be a valid image file');
              // Show first part of content as text to see what it actually is
              try {
                final contentPreview = String.fromCharCodes(getResponse.bodyBytes.take(200));
                debugPrint('  Content preview: ${contentPreview.replaceAll('\n', '\\n')}');
              } catch (e) {
                debugPrint('  Content is not text-readable');
              }
            }
          }
        }
      }
      
    } catch (e) {
      debugPrint('❌ Failed to check image URL: $url');
      debugPrint('Error details: $e');
      
      if (e.toString().contains('Failed to fetch') || e.toString().contains('timeout')) {
        debugPrint('🔍 DIAGNOSIS: Network connectivity issue');
        debugPrint('   - Server may be down');
        debugPrint('   - Network firewall blocking request');
        debugPrint('   - Server not accessible from your network');
        debugPrint('   - Try accessing the URL in a browser');
      }
    }
    
    debugPrint('=== IMAGE URL DEBUG END ===');
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

        // Debug first few image URLs
        for (int i = 0; i < filteredDockets.length && i < 3; i++) {
          final docket = filteredDockets[i];
          if (docket.imageName.isNotEmpty) {
            final url = _imageUrlFor(docket.docketType, docket.imageName);
            await _debugImageUrl(url);
          }
        }
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
    debugPrint('Loading image from URL: $imageUrl');

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              httpHeaders: {
                'Accept': 'image/*',
                'Cache-Control': 'no-cache',
              },
              memCacheWidth: 48,
              maxHeightDiskCache: 48,
              useOldImageOnUrlChange: true,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) {
                // Log the error with more details
                debugPrint('Image load failed: $url → $error');
                debugPrint('Error type: ${error.runtimeType}');
                debugPrint('Error stack trace: ${StackTrace.current}');
                
                // Debug the image response when there's an error
                _debugImageResponse(url);
                
                // Determine error type
                IconData errorIcon = Icons.error_outline;
                Color errorColor = Colors.red;
                String errorTooltip = 'Error loading image';
                
                if (error.toString().contains('Failed to fetch') ||
                    error.toString().contains('NetworkException')) {
                  errorIcon = Icons.cloud_off;
                  errorColor = Colors.orange;
                  errorTooltip = 'Network error. Check your connection.';
                } else if (error.toString().contains('404')) {
                  errorIcon = Icons.image_not_supported;
                  errorColor = Colors.grey;
                  errorTooltip = 'Image not found on server';
                } else if (error.toString().contains('FormatException') ||
                          error.toString().contains('EncodingError')) {
                  errorIcon = Icons.broken_image;
                  errorColor = Colors.purple;
                  errorTooltip = 'Invalid image format or corrupted file';
                  // Try to debug the actual response
                  _debugImageResponse(url);
                }
                
                return Tooltip(
                  message: errorTooltip,
                  child: GestureDetector(
                    onTap: () => _showImageErrorDialog(url, error.toString()),
                    child: Icon(errorIcon, size: 16, color: errorColor),
                  ),
                );
              },
              // Add timeout and retry options
              fadeInDuration: const Duration(milliseconds: 200),
              fadeOutDuration: const Duration(milliseconds: 200),
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

  void _showImageErrorDialog(String url, String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                error.contains('Failed to fetch') || error.contains('timeout') 
                  ? Icons.cloud_off 
                  : Icons.error,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Image Load Error')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Failed to load image:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(url, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                ),
                const SizedBox(height: 12),
                const Text('Error Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(error, style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
                const SizedBox(height: 16),
                _buildTroubleshootingSection(error),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _debugImageUrl(url);
              },
              child: const Text('Run Diagnostics'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Force refresh the cached network image
                CachedNetworkImage.evictFromCache(url);
                setState(() {}); // Trigger rebuild to retry loading
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTroubleshootingSection(String error) {
    if (error.contains('Failed to fetch') || error.contains('timeout')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.blue.shade600, size: 18),
                const SizedBox(width: 8),
                const Text('Network Connectivity Issue', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '• Check if the server is running and accessible\n'
              '• Verify your internet connection\n'
              '• Try accessing the URL in a web browser\n'
              '• Check if firewall is blocking the request\n'
              '• Server may be temporarily down',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                const SizedBox(width: 4),
                Text('Server: $httpImageBase', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      );
    } else if (error.contains('EncodingError')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image_not_supported, color: Colors.orange.shade600, size: 18),
                const SizedBox(width: 8),
                const Text('Image Format Issue', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '• Server may be returning HTML error page instead of image\n'
              '• Image file may be corrupted on the server\n'
              '• Incorrect file format or missing file\n'
              '• Check server logs for errors',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('General Troubleshooting:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              '• Check server logs for detailed error information\n'
              '• Verify the API endpoint is correct\n'
              '• Ensure proper authentication if required\n'
              '• Try accessing the URL directly in a browser',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Docket Image',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(imageName,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
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
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        httpHeaders: const {
                          'Accept': 'image/jpeg,image/png,image/webp,image/*,*/*;q=0.8',
                          'User-Agent': 'Flutter App',
                        },
                        placeholder: (context, url) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text("Loading image..."),
                            ],
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              const Text("Failed to load image", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              SelectableText("URL: $imageUrl", style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 8),
                              Text("Error: $error", style: const TextStyle(fontSize: 12, color: Colors.red)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  await _debugImageUrl(imageUrl);
                                },
                                child: const Text('Debug URL'),
                              ),
                            ],
                          ),
                        ),
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