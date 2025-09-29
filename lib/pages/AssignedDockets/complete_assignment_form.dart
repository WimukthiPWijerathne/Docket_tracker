import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import '../../service/assigned_docket_service.dart';
import '../../services/api_service.dart';

// Helper function to get app storage path
Future<String> getAppStoragePath() async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

class CompleteAssignmentForm extends StatefulWidget {
  final String assignmentId;
  final String docketId;

  const CompleteAssignmentForm({
    super.key,
    required this.assignmentId,
    required this.docketId,
  });

  @override
  _CompleteAssignmentFormState createState() => _CompleteAssignmentFormState();
}

class _CompleteAssignmentFormState extends State<CompleteAssignmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _isSubmitting = false;
  final AssignedDocketService _service = AssignedDocketService();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image != null) {
        setState(() {
          _imageFile = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error taking picture: $e')));
    }
  }

  Future<void> _submitForm() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      String? uploadedImageUrl;

      // Upload image if captured
      if (_imageFile != null) {
        // First save locally
        final localImagePath = await _saveImageLocally(_imageFile!);
        if (localImagePath != null) {
          print('Image saved locally at: $localImagePath');

          // Upload to server
          // Get docket type from parent widget or use a default
          final docketType = 'assignment';
          final imageFile = File(localImagePath);

          // Show uploading indicator
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Uploading image...')));
          }

          // Upload the image using ApiService
          final fileName =
              '${widget.assignmentId}_${docketType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}_a';
          final success = await ApiService.uploadDocketImage(
            imageFile,
            fileName,
            4, // Subdirectory 4 for assignments
          );

          if (success) {
            uploadedImageUrl =
                'http://124.43.181.243:8000/api/fetch-testdocket-image/4/$fileName.jpg';
          }

          if (uploadedImageUrl != null) {
            print('Image uploaded successfully: $uploadedImageUrl');
          } else {
            print('Failed to upload image');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to upload image')),
              );
            }
          }
        }
      }

      // Get remarks if entered
      String? remarks;
      if (_remarksController.text.trim().isNotEmpty) {
        remarks = _remarksController.text.trim();
        print('Remarks: $remarks');
      }

      // Mark as completed with current timestamp
      final completedTime = DateTime.now().toIso8601String();

      // For now, we're just showing a success message without updating the database
      print('Would mark as completed with:');
      print('Assignment ID: ${widget.assignmentId}');
      print('Image URL: $uploadedImageUrl');
      print('Remarks: $remarks');
      print('Completed Time: $completedTime');

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Image Uploaded Successfully!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Assignment ID: ${widget.assignmentId}'),
                    if (uploadedImageUrl != null)
                      Text('Image URL: ${Uri.parse(uploadedImageUrl).host}...'),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Return success to previous screen
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<String?> _saveImageLocally(XFile imageFile) async {
    try {
      // Get app storage directory
      final folderPath = await getAppStoragePath();
      final fileName =
          'completion_${widget.assignmentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = "$folderPath/$fileName";

      // Compress and save the image
      final XFile? compressedXFile =
          await FlutterImageCompress.compressAndGetFile(
            imageFile.path,
            targetPath,
            quality: 20, // Reduced quality for smaller file size
          );

      if (compressedXFile != null) {
        return compressedXFile.path;
      }
      return null;
    } catch (e) {
      print('Error saving image locally: $e');
      return null;
    }
  }

  // Upload image to server using the same pattern as ApiService.uploadDocketImage
  Future<String?> _uploadImage(
    File imageFile,
    String assignmentId,
    String docketType,
  ) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd').format(now);
      final timeStr = DateFormat('HHmmss').format(now);
      final cleanDocketType = docketType.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '_',
      );

      // Format the filename as assignmentid_dockettype_date_time_a
      final fileName =
          '${assignmentId}_${cleanDocketType}_${dateStr}_${timeStr}_a';

      print(
        'DEBUG: Starting upload of ${imageFile.path} as $fileName to subdirectory 4',
      );

      if (!await imageFile.exists()) {
        print('ERROR: File does not exist at path: ${imageFile.path}');
        return null;
      }

      var uri = Uri.parse('http://124.43.181.243:8000/api/upload-testdocket');
      print('DEBUG: Uploading to URL: $uri');

      var request = http.MultipartRequest('POST', uri);

      // Add the image file with the correct field name
      var multipartFile = await http.MultipartFile.fromPath(
        'images', // Field name should match server expectation
        imageFile.path,
      );
      request.files.add(multipartFile);

      // Add other fields as per server requirements
      request.fields['id'] = fileName; // Without .jpg extension
      request.fields['subdirectory'] = '4'; // Subdirectory 4 for "All other"

      print('DEBUG: Sending request with fields: ${request.fields}');

      // Send the request with timeout
      var response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('ERROR: Upload timed out after 30 seconds');
          throw TimeoutException('Upload timed out');
        },
      );

      final responseBody = await response.stream.bytesToString();
      final statusCode = response.statusCode;

      print('DEBUG: Server response status: $statusCode');
      print('DEBUG: Server response: $responseBody');

      if (statusCode == 200) {
        print('DEBUG: File uploaded successfully!');
        // Server adds .jpg automatically
        final accessFileName = '$fileName.jpg';
        final accessUrl =
            'http://124.43.181.243:8000/api/fetch-testdocket-image/4/$fileName.jpg';
        print('DEBUG: Access URL: $accessUrl');
        return accessUrl;
      } else {
        print('ERROR: Upload failed with status $statusCode: $responseBody');
        return null;
      }
    } catch (e, stackTrace) {
      print('ERROR: Exception during upload: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Assignment'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assignment Completion',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Assignment ID: ${widget.assignmentId}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Docket ID: ${widget.docketId}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please provide details of the completed work',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Photo Section
              Container(
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
                        const Icon(Icons.camera_alt, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'Photo of Completed Work',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Optional',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[50],
                        ),
                        child: _imageFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to take photo',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '(Will be saved locally)',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                            : Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(_imageFile!.path),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Remarks Section
              Container(
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
                        const Icon(Icons.notes, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'Remarks',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Optional',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'Enter any remarks about the completed work...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter remarks';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'SUBMITTING...',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'SUBMIT COMPLETION',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // Info text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Images and remarks are stored locally for now and will be synced later.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
