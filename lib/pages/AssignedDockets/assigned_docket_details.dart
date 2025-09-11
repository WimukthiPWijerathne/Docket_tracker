import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/assigned_docket.dart';
import '../../service/assigned_docket_service.dart';
import 'complete_assignment_form.dart';

class AssignedDocketDetailsPage extends StatefulWidget {
  final AssignedDocket docket;

  const AssignedDocketDetailsPage({
    super.key,
    required this.docket,
  });

  @override
  State<AssignedDocketDetailsPage> createState() => _AssignedDocketDetailsPageState();
}

class _AssignedDocketDetailsPageState extends State<AssignedDocketDetailsPage> {
  final AssignedDocketService _service = AssignedDocketService();

  // Image related variables
  String? docketImageName;
  bool isLoadingImage = true;
  String? imageError;
  String? docketType;

  static const String httpImageBase = 'http://124.43.181.243:8000';
  static const String docketDetailsApiBase = 'https://powerprox.sltidc.lk/GETDocketDetails2.php';

  String _imageBaseForPlatform() {
    return httpImageBase;
  }

  @override
  void initState() {
    super.initState();
    _fetchDocketImageName();
  }

  // Fetch image name from docket details API
  Future<void> _fetchDocketImageName() async {
    try {
      final response = await http.get(
        Uri.parse(docketDetailsApiBase),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Find the matching docket
        final record = data.firstWhere(
          (item) => item['ID'].toString() == widget.docket.docketID,
          orElse: () => null,
        );

        if (record != null && record['ImageName'] != null && record['DocketType'] != null) {
          setState(() {
            docketImageName = record['ImageName'];
            docketType = record['DocketType'];
            isLoadingImage = false;
          });

          debugPrint(
              "📷 Image for docket ${widget.docket.docketID}: $docketType, $docketImageName");
        } else {
          setState(() {
            imageError = 'No image found for this docket';
            isLoadingImage = false;
          });
        }
      } else {
        setState(() {
          imageError = 'Failed to fetch docket details';
          isLoadingImage = false;
        });
      }
    } catch (e) {
      setState(() {
        imageError = 'Error fetching image: $e';
        isLoadingImage = false;
      });
    }
  }

  // Get docket type number for image URL
  String _getDocketTypeNumber(String docketType) {
    switch (docketType.toLowerCase().trim()) {
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

  // Check if filename has image extension
  bool _hasImageExtension(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  // Ensure image name has extension
  String _safeImageName(String name) {
    return _hasImageExtension(name) ? name : '$name.jpg';
  }

  // Build final image URL
  String _imageUrlFor(String docketType, String imageName) {
    final type = _getDocketTypeNumber(docketType);
    final safeName = _safeImageName(imageName);
    return '${_imageBaseForPlatform()}/api/fetch-testdocket-image/$type/$safeName';
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue = widget.docket.isOverdue();
    final isInProgress = widget.docket.isOngoing && !isOverdue;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Text(
              "Docket ${widget.docket.docketID}",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            if (isOverdue) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "OVERDUE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isInProgress) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green.shade800,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "IN PROGRESS",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Card (Small and Rounded)
            _buildImageCard(),
            const SizedBox(height: 16),

            // Header Card
            _buildHeaderCard(),
            const SizedBox(height: 16),

            // Details Section
            _buildDetailsSection(),
            const SizedBox(height: 16),

            // Timeline Section
            _buildTimelineSection(),
            const SizedBox(height: 16),

            // Action Buttons
            if (widget.docket.isOngoing) _buildActionButtons(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage() {
    if (docketImageName == null || imageError != null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black87,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                _imageUrlFor(docketType ?? "unknown", docketImageName!),
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.white70, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return GestureDetector(
      onTap: _showFullScreenImage,
      child: Container(
        height: 250, // Increased height for better visibility
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isLoadingImage
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Loading image...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : imageError != null || docketImageName == null
                  ? Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              imageError ?? 'No image available',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          _imageUrlFor(docketType ?? "unknown", docketImageName!),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fullscreen, size: 16, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'View Fullscreen',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final isOverdue = widget.docket.isOverdue();
    final isInProgress = widget.docket.isOngoing && !isOverdue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                "Assignment ID",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.docket.assignmentID,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          // Status badge
          if (isOverdue || isInProgress)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isOverdue
                    ? Colors.red.shade100
                    : Colors.green.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? Colors.red.shade800
                          : Colors.green.shade800,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOverdue ? "OVERDUE" : "IN PROGRESS",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOverdue
                          ? Colors.red.shade800
                          : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      "Assigned Persons",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.docket.assignedPersons.isNotEmpty
                      ? widget.docket.assignedPersons
                      : "Not assigned",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Details",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow("Assignment ID", widget.docket.assignmentID, Icons.fingerprint),
          _buildDetailRow("Docket ID", widget.docket.docketID, Icons.receipt),
          _buildDetailRow("Uploaded By", widget.docket.uploadedBy, Icons.person),
          _buildDetailRow("Assigned Time", widget.docket.formattedUploadedTime, Icons.cloud_upload),
          _buildDetailRow("Reassignment Count", "${widget.docket.reassignmentCount}", Icons.repeat),
          if (widget.docket.isCompleted)
            _buildDetailRow("Work Duration", widget.docket.formattedWorkDuration, Icons.timer),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : "N/A",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Timeline",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildTimelineItem(
            "Uploaded",
            widget.docket.formattedUploadedTime,
            Icons.cloud_upload,
            isCompleted: true,
          ),
          _buildTimelineItem(
            "Assigned",
            widget.docket.formattedAssignedTime,
            Icons.assignment_turned_in,
            isCompleted: true,
          ),
          if (widget.docket.isCompleted)
            _buildTimelineItem(
              "Completed",
              widget.docket.formattedCompletedTime,
              Icons.check_circle,
              isCompleted: true,
              isLast: true,
            )
          else
            _buildTimelineItem(
              widget.docket.isOverdue() ? "Overdue" : "In Progress",
              widget.docket.timeSinceAssignment,
              widget.docket.isOverdue() ? Icons.warning : Icons.hourglass_empty,
              isCompleted: false,
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    String time,
    IconData icon, {
    required bool isCompleted,
    bool isLast = false,
  }) {
    final isOverdue = title == "Overdue";
    final isInProgress = title == "In Progress";
    final color = isOverdue ? Colors.red : (isCompleted ? Colors.green : Colors.orange);

    return Row(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isCompleted ? color : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                icon,
                color: isCompleted ? Colors.white : color,
                size: 14,
              ),
            ),
            if (!isLast)
              Container(
                height: 20,
                width: 2,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                if (isOverdue || isInProgress)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOverdue ? Colors.red.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOverdue ? "OVERDUE" : "IN PROGRESS",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? Colors.red.shade800 : Colors.green.shade800,
                      ),
                    ),
                  ),
                if (isOverdue || isInProgress) const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isOverdue ? Colors.red : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final isOverdue = widget.docket.isOverdue();
    final isInProgress = widget.docket.isOngoing && !isOverdue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? Colors.red.shade300
              : Colors.green.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Actions",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isOverdue
                        ? Colors.red.shade800
                        : Colors.green.shade800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? Colors.red.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOverdue ? "OVERDUE" : "IN PROGRESS",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isOverdue
                        ? Colors.red.shade800
                        : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  "Mark Completed",
                  Icons.check_circle,
                  isOverdue ? Colors.red : Colors.green,
                  () => _markAsCompleted(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  "Reassign",
                  Icons.repeat,
                  Colors.grey[700]!,
                  () => _reassignDocket(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 1,
      ),
    );
  }

  void _markAsCompleted() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => CompleteAssignmentForm(
        assignmentId: widget.docket.assignmentID,
        docketId: widget.docket.docketID,
      ),
    ),
  ).then((success) {
    if (success == true) {
      // Refresh the parent screen if needed
      if (mounted) {
        Navigator.of(context).pop(true); // Return success to previous screen
      }
    }
  });
}

  void _reassignDocket() {
    final TextEditingController personController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text("Reassign Docket"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Reassign Assignment ID: ${widget.docket.assignmentID}"),
              const SizedBox(height: 16),
              TextField(
                controller: personController,
                decoration: const InputDecoration(
                  labelText: "New Assigned Persons",
                  hintText: "Enter comma-separated person IDs",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (personController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  _performReassignment(personController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
              child: const Text("Reassign"),
            ),
          ],
        );
      },
    );
  }

  void _performMarkAsCompleted() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      final success = await _service.markAsCompleted(widget.docket.assignmentID);
      
      Navigator.of(context).pop(); // Close loading dialog
      
      if (success) {
        _showSnackBar(
          "Assignment marked as completed successfully!",
          Colors.green,
          Icons.check_circle,
        );
        Navigator.of(context).pop();
      } else {
        _showSnackBar(
          "Failed to mark assignment as completed.",
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showSnackBar(
        "Error: $e",
        Colors.red,
        Icons.error,
      );
    }
  }

  void _performReassignment(String newAssignedPersons) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      final success = await _service.reassignDocket(
        widget.docket.assignmentID,
        newAssignedPersons,
      );
      
      Navigator.of(context).pop();
      
      if (success) {
        _showSnackBar(
          "Assignment has been reassigned successfully!",
          Colors.green,
          Icons.check_circle,
        );
        Navigator.of(context).pop();
      } else {
        _showSnackBar(
          "Failed to reassign assignment.",
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showSnackBar(
        "Error: $e",
        Colors.red,
        Icons.error,
      );
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}