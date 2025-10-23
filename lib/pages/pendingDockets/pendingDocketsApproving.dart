import 'package:flutter/material.dart';

class PendingDocketsApprovingPage extends StatefulWidget {
  final Map<String, dynamic> docket;

  const PendingDocketsApprovingPage({super.key, required this.docket});

  @override
  State<PendingDocketsApprovingPage> createState() =>
      _PendingDocketsApprovingPageState();
}

class _PendingDocketsApprovingPageState
    extends State<PendingDocketsApprovingPage> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final docket = widget.docket;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(title: const Text('Docket Approval'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docket['docketNo']?.toString() ?? 'N/A',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusChip(docket['status']?.toString() ?? '0'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Docket Images (from imageNames)
              _buildImagesSection(isTablet),

              const SizedBox(height: 16),

              // Customer Information
              _buildSectionCard(
                'Customer Information',
                Icons.person,
                isTablet,
                [
                  _buildDetailRow('Customer Name', docket['customerName']),
                  _buildDetailRow('Account Number', docket['accountNumber']),
                  _buildDetailRow('Address', docket['address']),
                ],
              ),

              const SizedBox(height: 16),

              // Docket Details
              _buildSectionCard('Docket Details', Icons.description, isTablet, [
                _buildDetailRow('Docket ID', docket['docketID']),
                _buildDetailRow('Year', docket['year']),
                _buildDetailRow('Depot', docket['depot']),
                _buildDetailRow('Date & Time', docket['dateTime']),
              ]),

              const SizedBox(height: 16),

              // Meter Information
              _buildSectionCard(
                'Meter Information',
                Icons.electrical_services,
                isTablet,
                [
                  _buildDetailRow('Meter Number', docket['meterNumber']),
                  _buildDetailRow('Meter Reading', docket['meterReading']),
                  _buildDetailRow('Pole Number', docket['poleNumber']),
                ],
              ),

              const SizedBox(height: 16),

              // Error & Remarks
              _buildSectionCard(
                'Error & Remarks',
                Icons.error_outline,
                isTablet,
                [
                  _buildDetailRow('Error Types', docket['errorTypes']),
                  _buildDetailRow('Other Error', docket['otherError']),
                  _buildDetailRow('Remarks', docket['remarks']),
                ],
              ),

              const SizedBox(height: 16),

              // Upload Information
              _buildSectionCard(
                'Upload Information',
                Icons.upload_file,
                isTablet,
                [
                  _buildDetailRow('Uploaded By', docket['uploadedBy']),
                  _buildDetailRow('Uploaded Time', docket['uploadedTime']),
                  _buildDetailRow('Employee No', docket['employeeNo']),
                  _buildDetailRow('Image Names', docket['imageNames']),
                ],
              ),

              const SizedBox(height: 24),

              // Action Buttons
              if (isTablet)
                Row(
                  children: [
                    Expanded(child: _buildRejectButton()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildApproveButton()),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildApproveButton(),
                    const SizedBox(height: 12),
                    _buildRejectButton(),
                  ],
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ============ Images ============
  Widget _buildImagesSection(bool isTablet) {
    final rawNames = widget.docket['imageNames'];
    final images = _parseImageNames(rawNames);

    return _buildSectionCard('Docket Images', Icons.photo_library, isTablet, [
      if (images.isEmpty)
        const Text(
          'No images available',
          style: TextStyle(color: Colors.black54),
        )
      else
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: images.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 4 : 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, i) {
            final name = images[i];
            final url = _buildImageUrl(name);

            return GestureDetector(
              onTap: () => _showFullScreenImage(url, name),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
    ]);
  }

  List<String> _parseImageNames(dynamic imageNames) {
    if (imageNames == null) return [];
    final raw = imageNames.toString();
    if (raw.trim().isEmpty || raw.toLowerCase() == 'null') return [];

    // imageNames may be comma/semicolon separated or a single name
    final parts = raw.split(RegExp(r'[;,]'))
      ..removeWhere((s) => s.trim().isEmpty);
    final cleaned = parts
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    debugPrint('[PendingApprove] Parsed image names: $cleaned');
    return cleaned;
  }

  String _buildImageUrl(String imageName) {
    // Match the POST endpoint storage: subdirectory 1 on 124.43.136.185
    // Upload path: http://124.43.136.185:8000/api/upload-testdocket/1/{image_name}
    // Fetch path:  http://124.43.136.185:8000/api/fetch-testdocket-image/1/{image_name}.jpg
    final clean = imageName.endsWith('.jpg')
        ? imageName.substring(0, imageName.length - 4)
        : imageName;
    final url =
        'http://124.43.181.243:8000/api/fetch-testdocket-image/$clean.jpg';
    debugPrint('[PendingApprove] Image URL for "$imageName" -> $url');
    return url;
  }

  void _showFullScreenImage(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black87,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(title, style: const TextStyle(color: Colors.white)),
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white70,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isPending = status == '0';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPending ? Colors.orange[100] : Colors.green[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending ? Icons.pending : Icons.check_circle,
            size: 16,
            color: isPending ? Colors.orange[800] : Colors.green[800],
          ),
          const SizedBox(width: 4),
          Text(
            isPending ? 'Pending Approval' : 'Approved',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPending ? Colors.orange[800] : Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    bool isTablet,
    List<Widget> children,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    final displayValue = value?.toString().trim();
    final isEmpty =
        displayValue == null || displayValue.isEmpty || displayValue == 'null';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              isEmpty ? '-' : displayValue,
              style: TextStyle(color: isEmpty ? Colors.grey : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApproveButton() {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : _handleApprove,
      icon: _isProcessing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.check_circle),
      label: Text(_isProcessing ? 'Processing...' : 'Approve'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildRejectButton() {
    return OutlinedButton.icon(
      onPressed: _isProcessing ? null : _handleReject,
      icon: const Icon(Icons.cancel),
      label: const Text('Reject'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _handleApprove() async {
    final confirm = await _showConfirmDialog(
      'Approve Docket',
      'Are you sure you want to approve this docket?',
      Colors.green,
    );
    if (!confirm) return;

    setState(() => _isProcessing = true);

    try {
      // TODO: Call your approval API here
      debugPrint('[Approval] Approving docket: ${widget.docket['docketID']}');
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Docket approved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving docket: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleReject() async {
    final confirm = await _showConfirmDialog(
      'Reject Docket',
      'Are you sure you want to reject this docket?',
      Colors.red,
    );
    if (!confirm) return;

    setState(() => _isProcessing = true);

    try {
      // TODO: Call your rejection API here
      debugPrint('[Approval] Rejecting docket: ${widget.docket['docketID']}');
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Docket rejected'),
          backgroundColor: Colors.orange,
        ),
      );

      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting docket: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool> _showConfirmDialog(
    String title,
    String message,
    Color color,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
