import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:leco_docket_tracker/services/api_service.dart';
import '../../utils/file_helper.dart';
import '../docketGrabbing/http_post_docket_details.dart';
import 'post_capture_options_page.dart';

class ImagePreviewPage extends StatefulWidget {
  final XFile? capturedFile;
  final String? filePath; // Keep for backward compatibility
  final String docketType;

  const ImagePreviewPage({
    super.key,
    this.capturedFile,
    this.filePath,
    required this.docketType,
  }) : assert(
         capturedFile != null || filePath != null,
         'Either capturedFile or filePath must be provided',
       );

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  bool _isUploading = false;
  bool? _uploadSuccess;
  bool _dbSuccess = false;
  
  // Controllers for location details
  final TextEditingController _transformerController = TextEditingController();
  final TextEditingController _poleController = TextEditingController();
  final TextEditingController _meterShiftingController = TextEditingController();
  
  @override
  void dispose() {
    _transformerController.dispose();
    _poleController.dispose();
    _meterShiftingController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    developer.log(
      'ImagePreviewPage: initState called.',
      name: 'ImagePreviewPage',
    );
    // Don't auto-upload anymore - let user preview first
  }

  String get _imagePath {
    return widget.capturedFile?.path ?? widget.filePath!;
  }

  Future<void> _startUpload() async {
    print('DEBUG: _startUpload called!');
    
    // Validate required fields
    if (_transformerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter transformer number')),
      );
      return;
    }
    
    setState(() {
      _isUploading = true;
      _uploadSuccess = null;
    });

    try {
      File fileToUpload;
      if (widget.capturedFile != null) {
        // Need to save and compress the captured file first
        developer.log(
          'ImagePreviewPage: Saving and compressing captured file',
          name: 'ImagePreviewPage',
        );
        // Get abbreviation for docket type
        final docketTypeMap = {
          'Service Line Maintenance': 'SLM',
          'Meter Testing': 'MT',
          'Estimate': 'EST',
          'Per Visit': 'PV',
          'Pole Disconnection': 'PD',
          'Material Remove': 'MR',
          'Meter Replacement Only': 'MRO',
          'Visit with Contractor': 'VC',
          'Pole Top Maintenance': 'PTM',
        };
        final abbr = docketTypeMap[widget.docketType] ?? "UNK";
        // Generate timestamped filename
        final now = DateTime.now();
        final formattedDate =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_"
            "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        final newFileName = "${abbr}_$formattedDate.jpg";
        // Get app storage directory
        final folderPath = await getAppStoragePath();
        final targetPath = "$folderPath/$newFileName";
        // Compress and save the image
        final XFile? compressedXFile =
            await FlutterImageCompress.compressAndGetFile(
              widget.capturedFile!.path,
              targetPath,
              quality: 20,
            );
        if (compressedXFile == null) {
          throw Exception('Failed to compress image');
        }
        fileToUpload = File(compressedXFile.path);
      } else {
        // Use existing file path
        fileToUpload = File(widget.filePath!);
      }

      developer.log(
        'ImagePreviewPage: Uploading file: ${fileToUpload.path}',
        name: 'ImagePreviewPage',
      );
      // Get just the file name without path
      final fileName = fileToUpload.path.split('/').last;
      // Log the file details
      print('Uploading file: $fileName');
      print('File exists: ${await fileToUpload.exists()}');
      print('File size: ${await fileToUpload.length()} bytes');
      final imageUploadSuccess = await ApiService.uploadDocketImage(
        fileToUpload,
        fileName,
      );
      print('Image upload status: $imageUploadSuccess');

      // Prepare location details
      final locationDetails = [
        'Transformer: ${_transformerController.text}',
        if (_poleController.text.isNotEmpty) 'Pole: ${_poleController.text}',
        if (_meterShiftingController.text.isNotEmpty) 'Meter Shift: ${_meterShiftingController.text}',
      ].join(', ');
      
      // Upload to database
      final dbUploadSuccess = await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HttpPostDocketDetails(
            docketType: widget.docketType,
            fileName: fileName,
            filePath: fileToUpload.path,
            locationDetails: locationDetails,
          ),
        ),
      );
      // stop execution so we don’t run the old flow


      // Update state
      setState(() {
        _dbSuccess = dbUploadSuccess;
      });

      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _uploadSuccess = imageUploadSuccess;
      });

      if (imageUploadSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload successful'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PostCaptureOptionsPage(
              filePath: fileToUpload.path,
              docketType: widget.docketType,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image upload failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error during upload: $e',
        name: 'ImagePreviewPage',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadSuccess = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildLocationInputField(TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        ),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildLocationDetailsSection() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location Details *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildLocationInputField(
              _transformerController,
              'Transformer Number *',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            _buildLocationInputField(
              _poleController,
              'Pole Number',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            _buildLocationInputField(
              _meterShiftingController,
              'Meter Shifting Details',
              keyboardType: TextInputType.text,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isUploading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Preview & Upload')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Image.file(
                          File(_imagePath),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLocationDetailsSection(),
                const SizedBox(height: 16),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_isUploading) {
      return const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Uploading image and details...'),
        ],
      );
    }

    if (_uploadSuccess == true) {
      // Upload successful, show success message and navigation
      return Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 8),
          Text(
            _dbSuccess ? 'Image and details uploaded!' : 'Image uploaded, details failed',
            style: TextStyle(color: _dbSuccess ? Colors.green : Colors.orange, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => PostCaptureOptionsPage(
                  filePath: _imagePath,
                  docketType: widget.docketType,
                ),
              ),
            ),
            child: const Text('Continue'),
          ),
        ],
      );
    }

    if (_uploadSuccess == false) {
      // Upload failed, show Retry and Delete
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _deleteImage(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _startUpload(), // Retry
              child: const Text('Retry Upload'),
            ),
          ),
        ],
      );
    }

    // Initial state - show preview options
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retake'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _startUpload,
            child: const Text('Save & Upload'),
          ),
        ),
      ],
    );
  }

  void _deleteImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Image',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this image? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _confirmDelete(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    try {
      File(_imagePath).deleteSync();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image deleted successfully'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
