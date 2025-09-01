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
    
    // Removed OCR service functionality
    String? docketSerial;
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
      // Determine subdirectory based on docket type
      final subdirectoryMap = {
        'Service Line Maintenance': 1,
        'Meter Testing': 2,
        'Estimate': 3,
        // All other types go to subdirectory 4
      };
      final subdirectory = subdirectoryMap[widget.docketType] ?? 4;
      
      final imageUploadSuccess = await ApiService.uploadDocketImage(
        fileToUpload,
        fileName,
        subdirectory,
      );
      print('Image upload status: $imageUploadSuccess');

      // Prepare location details
      final locationDetails = [
        'Transformer: ${_transformerController.text}',
        if (_poleController.text.isNotEmpty) 'Pole: ${_poleController.text}',
        if (_meterShiftingController.text.isNotEmpty) 'Meter Shift: ${_meterShiftingController.text}',
      ].join(', ');
      
      // Upload to database
      final dbUploadSuccess = await Navigator.of(context).pushReplacement<bool, bool>(
        MaterialPageRoute<bool>(
          builder: (_) => HttpPostDocketDetails(
            docketType: widget.docketType,
            fileName: fileName,
            filePath: fileToUpload.path,
            locationDetails: locationDetails,
            docketSerial: docketSerial, // Pass the extracted docket serial
          ),
        ),
      ) ?? false;
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

  Widget _buildLocationInputField(TextEditingController controller, String label, 
      {TextInputType? keyboardType, String? helperText, bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (isRequired) const Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter ${label.toLowerCase()}',
              helperText: helperText,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            keyboardType: keyboardType,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDetailsSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Color(0xFF003366),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Location Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: _buildLocationInputField(
              _transformerController,
              'Transformer Number',
              keyboardType: TextInputType.text,
              isRequired: true,
              helperText: 'Required. Enter the transformer number for this docket.',
            ),
          ),
          _buildLocationInputField(
            _poleController,
            'Pole Number',
            keyboardType: TextInputType.text,
            helperText: 'Optional. If applicable, enter the pole number.',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _buildLocationInputField(
              _meterShiftingController,
              'Meter Shifting Details',
              keyboardType: TextInputType.text,
              helperText: 'Optional. Provide details if this involves meter shifting.',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isUploading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait while we finish uploading'),
              backgroundColor: Colors.orange,
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Review & Submit',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with docket type
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: const Color(0xFFF5F7FA),
                child: Text(
                  'Docket Type: ${widget.docketType}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF003366),
                    fontSize: 15,
                  ),
                ),
              ),
              
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image preview with better styling
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          'Preview',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 3/4,
                              child: Image.file(
                                File(_imagePath),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Location details section
                      _buildLocationDetailsSection(),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              
              // Bottom action bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: _buildBottomBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_isUploading) {
      return Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003366)),
          ),
          const SizedBox(height: 16),
          Text(
            'Uploading your docket...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Please wait while we process your request',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_uploadSuccess == true) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _dbSuccess ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _dbSuccess ? Colors.green[100]! : Colors.orange[100]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _dbSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: _dbSuccess ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dbSuccess ? 'Upload Successful!' : 'Partial Upload',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _dbSuccess ? Colors.green[800] : Colors.orange[800],
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dbSuccess 
                            ? 'Your docket has been successfully uploaded.'
                            : 'Image uploaded but there was an issue with the details.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _dbSuccess ? Colors.green[700] : Colors.orange[700],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PostCaptureOptionsPage(
                    filePath: _imagePath,
                    docketType: widget.docketType,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    if (_uploadSuccess == false) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Failed',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.red[800],
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'There was an issue uploading your docket. Please try again.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red[700],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _deleteImage(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _startUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Retry Upload'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Initial state - show preview options
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Retake Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[800],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startUpload,
                icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                label: const Text('Save & Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
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
