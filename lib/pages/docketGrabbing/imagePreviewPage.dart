// pages/image_preview_page.dart
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../services/api_service.dart';
import '../../utils/file_helper.dart';
import 'http_post_docket_details.dart';

class ImagePreviewPage extends StatefulWidget {
  final XFile? capturedFile;
  final String? filePath;
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

  @override
  void initState() {
    super.initState();
    developer.log(
      'ImagePreviewPage: initState called.',
      name: 'ImagePreviewPage',
    );
  }

  String get _imagePath => widget.capturedFile?.path ?? widget.filePath!;

  Future<void> _startUpload() async {
    setState(() {
      _isUploading = true;
      _uploadSuccess = null;
    });

    try {
      // 1) Prepare the file (compress if needed)
      File fileToUpload;
      if (widget.capturedFile != null) {
        developer.log(
          'Saving & compressing captured file',
          name: 'ImagePreviewPage',
        );

        // Map your docket abbreviations
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

        // Timestamped filename (YYYYMMDD_HHMMSS)
        final now = DateTime.now();
        final ts =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_"
            "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        final newFileName = "${abbr}_$ts.jpg";

        final folderPath = await getAppStoragePath();
        final targetPath = "$folderPath/$newFileName";

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
        fileToUpload = File(widget.filePath!);
      }

      final fileName = fileToUpload.path.split('/').last;
      developer.log('Uploading file: $fileName', name: 'ImagePreviewPage');

      // 2) Upload image binary via HTTP (not SFTP)
      final subdirectoryMap = {
        'Service Line Maintenance': 1,
        'Meter Testing': 2,
        'Estimate': 3,
      };
      final subdirectory = subdirectoryMap[widget.docketType] ?? 4;

      final imageUploadSuccess = await ApiService.uploadDocketImage(
        fileToUpload,
        fileName,
        subdirectory,
      );

      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _uploadSuccess = imageUploadSuccess;
      });

      // 3) If image upload successful -> proceed to database insert
      if (imageUploadSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image upload successful. Saving details...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HttpPostDocketDetails(
              docketType: widget.docketType,
              fileName: fileName,
              filePath: fileToUpload.path,
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
    } catch (e, st) {
      developer.log(
        'Error during upload: $e',
        name: 'ImagePreviewPage',
        stackTrace: st,
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
          Text('Uploading image...'),
        ],
      );
    }

    if (_uploadSuccess == false) {
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
              onPressed: _startUpload,
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
                Navigator.of(context).pop();
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
