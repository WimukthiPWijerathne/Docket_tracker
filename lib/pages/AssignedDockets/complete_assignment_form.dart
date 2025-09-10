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
      // First upload the image
      final imageUrl = await _uploadImage(_imageFile!);
      
      // Then mark as completed with remarks and image URL
      final success = await _service.markAsCompleted(
        widget.assignmentId,
        remarks: _remarksController.text.trim(),
        completionImageUrl: imageUrl,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment marked as completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to mark assignment as completed');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
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
      // First, get the original docket details to get the original image name
      final response = await http.get(
        Uri.parse('https://powerprox.sltidc.lk/GETDocketDetails2.php'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch docket details');
      }

      final List<dynamic> data = json.decode(response.body);
      final record = data.firstWhere(
        (item) => item['ID'] == widget.docketId,
        orElse: () => null,
      );

      if (record == null || record['ImageName'] == null) {
        throw Exception('Original docket image not found');
      }

      // Get the original image name and remove the extension
      String originalName = record['ImageName'].toString();
      String baseName = originalName.replaceAll(RegExp(r'\.jpg$'), '');
      
      // Create new filename with _a suffix
      String newFileName = '${baseName}_a.jpg';
      
      // Get app storage directory
      final folderPath = await getAppStoragePath();
      final targetPath = "$folderPath/$newFileName";

      // Compress and save the image with the new name
      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: 100,
      );

      if (compressedXFile == null) {
        throw Exception('Failed to compress image');
      }

      // Now upload the file
      final uri = Uri.parse('https://powerprox.sltidc.lk/upload-completion-image.php');
      final request = http.MultipartRequest('POST', uri);
      
      final file = await http.MultipartFile.fromPath(
        'image',
        compressedXFile.path,
        contentType: MediaType('image', 'jpeg'),
      );
      
      request.files.add(file);
      request.fields['assignment_id'] = widget.assignmentId;
      request.fields['docket_id'] = widget.docketId;
      request.fields['original_image_name'] = originalName;
      request.fields['new_image_name'] = newFileName;
      
      final uploadResponse = await request.send();
      final responseData = await uploadResponse.stream.bytesToString();
      
      if (uploadResponse.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        if (jsonResponse['success'] == true) {
          return jsonResponse['imageUrl'] ?? newFileName; // Return the new filename if no URL is provided
        }
      }
      throw Exception('Failed to upload image');
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
                  hintText: 'Enter any remarks about the completed work (optional)...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
