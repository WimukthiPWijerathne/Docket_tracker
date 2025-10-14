// lib/pages/addDocket/imageDataCollection.dart
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:leco_docket_tracker/services/api_service.dart';
import '../../../utils/file_helper.dart';
import '../cameraCapture/captureImage.dart';
import '../uploadContent/completeCapturePage.dart';
import '../uploadContent/http_post_docket_details.dart';

/// Preview screen shown right after taking a photo.
class ImagePreviewPage extends StatefulWidget {
  final XFile capturedFile;

  const ImagePreviewPage({super.key, required this.capturedFile});

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  // ------- Config / Lookups -------
  static const List<String> _allDocketTypes = [
    'Service Line Maintenance',
    'Meter Testing',
    'Estimate',
    'Per Visit',
    'Pole Disconnection',
    'Material Remove',
    'Meter Replacement Only',
    'Visit with Contractor',
    'Pole Top Maintenance',
  ];

  static const Map<String, String> _abbr = {
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

  static const Map<String, int> _subdirectoryMap = {
    'Service Line Maintenance': 1,
    'Meter Testing': 2,
    'Estimate': 3,
    // everything else → 4
  };

  // ------- State -------
  String? _selectedType;
  late final TextEditingController _filenameCtrl;
  final TextEditingController _transformerCtrl = TextEditingController();
  final TextEditingController _transformerDigitsCtrl =
      TextEditingController(); // For 4 digits only
  String _transformerPrefix = ""; // "AZ" or "BZ"
  final TextEditingController _poleCtrl = TextEditingController();
  final TextEditingController _meterShiftCtrl = TextEditingController();
  final TextEditingController _docketSerialCtrl =
      TextEditingController(); // ✅ NEW

  bool _isUploading = false;
  bool? _uploadSuccess;
  final bool _dbSuccess = false;

  String? _savedCompressedPath;

  @override
  void initState() {
    super.initState();
    _filenameCtrl = TextEditingController(text: _suggestedFilename(null));
  }

  @override
  void dispose() {
    _filenameCtrl.dispose();
    _transformerCtrl.dispose();
    _transformerDigitsCtrl.dispose();
    _poleCtrl.dispose();
    _meterShiftCtrl.dispose();
    _docketSerialCtrl.dispose(); // ✅ NEW
    super.dispose();
  }

  String get _rawPath => widget.capturedFile.path;

  String _suggestedFilename(String? docketType) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final prefix = _abbr[docketType ?? ''] ?? 'IMG';
    return '${prefix}_$stamp.jpg';
  }

  Future<void> _onTypeChanged(String? value) async {
    setState(() {
      _selectedType = value;
      final current = _filenameCtrl.text.trim();
      final idx = current.indexOf('_');
      final tail = (idx > 0 && idx < current.length - 1)
          ? current.substring(idx + 1)
          : null;
      final newPrefix = _abbr[_selectedType ?? ''] ?? 'IMG';
      _filenameCtrl.text = tail != null
          ? '${newPrefix}_$tail'
          : _suggestedFilename(_selectedType);
    });
  }

  bool get _canSave {
    final name = _filenameCtrl.text.trim().toLowerCase();
    final transformerOk =
        _transformerPrefix.isNotEmpty &&
        _transformerDigitsCtrl.text.length == 4;
    final hasJpgExt = name.endsWith('.jpg') || name.endsWith('.jpeg');
    return !_isUploading && _selectedType != null && transformerOk && hasJpgExt;
  }

  Future<void> _startUpload() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a docket type')),
      );
      return;
    }
    if (_transformerPrefix.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select either AZ or BZ prefix')),
      );
      return;
    }
    if (_transformerDigitsCtrl.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 4-digit transformer number'),
        ),
      );
      return;
    }
    final rawName = _normalizeJpegName(_filenameCtrl.text.trim());
    if (rawName.isEmpty || !rawName.toLowerCase().endsWith('.jpg')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid filename ending with .jpg'),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadSuccess = null;
    });

    try {
      // 1) Compress → save to app storage
      final folderPath = await getAppStoragePath();
      final targetPath = '$folderPath/$rawName';

      developer.log('Compressing to: $targetPath', name: 'ImagePreview');

      final srcFile = File(_rawPath);
      final srcSize = await srcFile.length();
      developer.log(
        'Before compress: ${(srcSize / 1024).toStringAsFixed(1)} KB',
        name: 'ImagePreview',
      );

      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        _rawPath,
        targetPath,
        quality: 20,
      );
      if (compressed == null) {
        throw Exception('Failed to compress image');
      }
      _savedCompressedPath = compressed.path;
      final fileToUpload = File(_savedCompressedPath!);
      final outSize = await fileToUpload.length();
      developer.log(
        'After compress:  ${(outSize / 1024).toStringAsFixed(1)} KB',
        name: 'ImagePreview',
      );

      // 2) Upload image
      // Always use subdirectory 4 for all docket types
      const subDir = 4;
      final imageUploadSuccess = await ApiService.uploadDocketImage(
        fileToUpload,
        rawName,
        subDir,
      );

      // 3) Build details
      final locationDetails = [
        'Transformer: ${_transformerCtrl.text.trim()}',
        if (_poleCtrl.text.trim().isNotEmpty) 'Pole: ${_poleCtrl.text.trim()}',
        if (_meterShiftCtrl.text.trim().isNotEmpty)
          'Meter Shift: ${_meterShiftCtrl.text.trim()}',
      ].join(', ');

      // ✅ Get docket serial from controller
      final docketSerial = _docketSerialCtrl.text.trim().isNotEmpty
          ? _docketSerialCtrl.text.trim()
          : null;

      developer.log(
        'Docket Serial: ${docketSerial ?? "NOT PROVIDED"}',
        name: 'ImagePreview',
      );

      // 4) Post DB record
      bool dbUploadSuccess = false;
      if (mounted) {
        dbUploadSuccess =
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => HttpPostDocketDetails(
                  docketType: _selectedType!,
                  fileName: rawName,
                  filePath: fileToUpload.path,
                  locationDetails: locationDetails,
                  docketSerial: docketSerial, // ✅ Pass the serial number
                ),
              ),
            ) ??
            false;
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CaptureResultPage(
            docketType: _selectedType!,
            fileName: rawName,
            localPath: _savedCompressedPath,
            imageUploaded: imageUploadSuccess,
            detailsRecorded: dbUploadSuccess,
            errorMessage: !imageUploadSuccess
                ? 'Image upload failed.'
                : (dbUploadSuccess
                      ? null
                      : 'Image uploaded, but saving details failed.'),
          ),
        ),
      );
    } catch (e, st) {
      developer.log('Upload error: $e', name: 'ImagePreview', stackTrace: st);
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

  String _normalizeJpegName(String name) {
    if (name.isEmpty) return name;
    final n = name.toLowerCase();
    if (n.endsWith('.jpeg')) {
      name = '${name.substring(0, name.length - 5)}.jpg';
    } else if (!n.endsWith('.jpg')) {
      name = '$name.jpg';
    }
    return name.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  // -------- UI --------

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isUploading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review & Submit'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                color: const Color(0xFFF5F7FA),
                child: Row(
                  children: [
                    const Icon(Icons.description, color: Color(0xFF003366)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedType == null
                            ? 'Pick a docket type to continue'
                            : 'Docket Type: $_selectedType',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003366),
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preview
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Preview',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              aspectRatio: 3 / 4,
                              child: Image.file(
                                File(_rawPath),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Docket Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Docket Info',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF003366),
                                      ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedType,
                                  items: _allDocketTypes
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _isUploading
                                      ? null
                                      : _onTypeChanged,
                                  decoration: const InputDecoration(
                                    labelText: 'Docket Type *',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _filenameCtrl,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'File name',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(
                                      Icons.drive_file_rename_outline,
                                    ),
                                    suffixIcon: Icon(Icons.lock),
                                    helperText:
                                        'Auto-generated from type & timestamp',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Location details
                      _buildLocationDetailsSection(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom bar
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

  Widget _buildLocationDetailsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 8),
            _buildTransformerField(),
            _buildField(
              _poleCtrl,
              'Pole Number',
              helper: 'Optional. If applicable, enter the pole number.',
            ),
            _buildField(
              _meterShiftCtrl,
              'Meter Shifting Details',
              helper:
                  'Optional. Provide details if this involves meter shifting.',
            ),
            // ✅ NEW: Docket Serial field
            _buildField(
              _docketSerialCtrl,
              'Docket Serial Number',
              helper: 'Optional. Enter the docket serial number if available.',
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTransformerField() {
    void _updateTransformerValue() {
      // Update the main transformer controller with combined value
      _transformerCtrl.text =
          '$_transformerPrefix${_transformerDigitsCtrl.text}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Transformer Number',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: 6),
          // Prefix Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _transformerPrefix = 'AZ';
                      _updateTransformerValue();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _transformerPrefix == 'AZ'
                        ? const Color(0xFF003366)
                        : Colors.grey[300],
                    foregroundColor: _transformerPrefix == 'AZ'
                        ? Colors.white
                        : Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('AZ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _transformerPrefix = 'BZ';
                      _updateTransformerValue();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _transformerPrefix == 'BZ'
                        ? const Color(0xFF003366)
                        : Colors.grey[300],
                    foregroundColor: _transformerPrefix == 'BZ'
                        ? Colors.white
                        : Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('BZ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 4-digit input field with prefix
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                // Prefix display
                if (_transformerPrefix.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15,
                    ),
                    color: const Color(0xFF003366).withOpacity(0.1),
                    child: Text(
                      _transformerPrefix,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                // Digit input
                Expanded(
                  child: TextField(
                    controller: _transformerDigitsCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    onChanged: (value) {
                      _updateTransformerValue();
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: _transformerPrefix.isEmpty
                          ? 'Select AZ/BZ above first'
                          : 'Enter 4 digits',
                      helperText: null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Required. Enter a 4-digit transformer number.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController c,
    String label, {
    bool isRequired = false,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isRequired)
                const Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Enter ${label.toLowerCase()}',
              helperText: helper,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_isUploading) {
      return Column(
        children: const [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF003366)),
          ),
          SizedBox(height: 12),
          Text('Uploading your docket...'),
          SizedBox(height: 2),
          Text(
            'Please wait while we process your request',
            style: TextStyle(color: Colors.black54),
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
                color: (_dbSuccess ? Colors.green : Colors.orange).withOpacity(
                  0.25,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _dbSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: _dbSuccess ? Colors.green : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _dbSuccess
                        ? 'Upload successful'
                        : 'Image uploaded; details submission had an issue',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    openDocketCamera(context);
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Capture Another'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Done'),
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

    if (_uploadSuccess == false) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _deleteImage(context),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _canSave ? _startUpload : null,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Retry Upload'),
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
      );
    }

    // Initial state
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Retake'),
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
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _canSave ? _startUpload : null,
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
    );
  }

  void _deleteImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Delete this image? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    try {
      File(_rawPath).deleteSync();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image deleted')));
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
