import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
    Key? key,
    required this.assignmentId,
    required this.docketId,
  }) : super(key: key);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a photo of the completed work')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload the image
      final imageUrl = await _uploadImage(_imageFile!);
      
      if (!mounted) return;

      // Show success message with the image URL
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image uploaded successfully!\nURL: $imageUrl'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      
      // Close the form after successful upload
      Navigator.of(context).pop(true);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
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

  Future<String> _uploadImage(XFile imageFile) async {
    try {
      // Generate timestamp for the filename
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      
      // Create the new filename: {assignmentId}_{docketType}_{timestamp}_a.jpg
      final newFileName = '${widget.assignmentId}_${widget.docketId}_${timestamp}_a.jpg';
      
      // Get app storage directory
      final folderPath = await getAppStoragePath();
      final targetPath = "$folderPath/$newFileName";

      // Compress and save the image with the new name
      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: 20, // Reduced quality for smaller file size
      );

      if (compressedXFile == null) {
        throw Exception('Failed to compress image');
      }

      // Upload to the 4th subdirectory (4 is for 'All other')
      final uploadSuccess = await ApiService.uploadDocketImage(
        File(compressedXFile.path),
        newFileName,
        4, // 4th subdirectory for completed work images
      );

      if (!uploadSuccess) {
        throw Exception('Failed to upload image to server');
      }
      
      // Return the access URL for the uploaded image
      // The server returns the path as upload/TestDocket/4/filename.jpg
      // But we need to construct the full URL
      final baseUrl = 'http://124.43.136.185:8000';
      final imagePath = 'upload/TestDocket/4/$newFileName';
      return '$baseUrl/$imagePath';
    } catch (e) {
      throw Exception('Image upload failed: $e');
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Assignment Completion',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please provide details of the completed work',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              
              // Photo Section
              const Text(
                'Photo of Completed Work',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Tap to take photo'),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_imageFile!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Remarks Section
              const Text(
                'Remarks',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _remarksController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter any remarks about the completed work...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter remarks';
                  }
                  return null;
                },
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
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'SUBMIT COMPLETION',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
