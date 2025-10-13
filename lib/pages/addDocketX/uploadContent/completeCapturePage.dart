// lib/pages/addDocket/capture_result_page.dart
import 'dart:io';
import 'package:flutter/material.dart';

// Your existing helper to open the camera again
import '../cameraCapture/captureImage.dart';

class CaptureResultPage extends StatelessWidget {
  final String docketType;
  final String fileName; // server filename (e.g., SLM_20250914_112233.jpg)
  final String?
  localPath; // compressed image path on device (for fallback preview)
  final bool imageUploaded; // true if image upload to FastAPI/SFTP succeeded
  final bool
  detailsRecorded; // true if DB POST (HttpPostDocketDetails) succeeded
  final String? errorMessage; // optional error text to show on failures

  const CaptureResultPage({
    super.key,
    required this.docketType,
    required this.fileName,
    required this.localPath,
    required this.imageUploaded,
    required this.detailsRecorded,
    this.errorMessage,
  });

  bool get overallSuccess => imageUploaded && detailsRecorded;

  // Compute the network image only when both steps succeeded
  String? get _networkUrl {
    if (!overallSuccess) return null;
    final dir = _typeFolder(docketType);
    final file = Uri.encodeComponent(_ensureJpg(fileName));
    // NOTE: keep this base consistent with your DocketDetailsPage
    return 'http://124.43.181.243:8000/api/fetch-testdocket-image/$dir/$file';
  }

  static String _ensureJpg(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg')) return name;
    if (lower.endsWith('.jpeg'))
      return name.substring(0, name.length - 5) + '.jpg';
    return name.endsWith('.png') || name.endsWith('.webp') ? name : '$name.jpg';
  }

  static String _typeFolder(String t) {
    // Always return '1' for all docket types
    return '1';
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final ok = overallSuccess;

    final Color bannerColor = ok ? Colors.green.shade50 : Colors.red.shade50;
    final Color bannerBorder = ok ? Colors.green.shade200 : Colors.red.shade200;
    final Color iconColor = ok ? Colors.green.shade700 : Colors.red.shade700;
    final IconData icon = ok ? Icons.check_circle : Icons.error_outline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Docket Captured'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => _goHome(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Result banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: bannerColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: bannerBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(icon, color: iconColor, size: 34),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ok
                          ? 'Docket Captured Successfully!'
                          : 'Capture Incomplete',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ok ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.blueGrey.shade200),
                      ),
                      child: Text(
                        docketType.toUpperCase(),
                        style: const TextStyle(
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF003366),
                        ),
                      ),
                    ),
                    if (!ok) ...[
                      const SizedBox(height: 14),
                      _FailureDetails(
                        imageUploaded: imageUploaded,
                        detailsRecorded: detailsRecorded,
                        extra: errorMessage,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action: Capture Another
              _ActionTile(
                icon: Icons.camera_alt_outlined,
                title: 'Capture Another Docket',
                subtitle: 'Same type: $docketType',
                onTap: () => openDocketCamera(context),
              ),

              const SizedBox(height: 12),

              // Action: Preview Captured Image
              _ActionTile(
                icon: Icons.image_outlined,
                title: 'Preview Captured Image',
                subtitle: overallSuccess
                    ? 'From server'
                    : (localPath == null ? 'Not available' : 'From device'),
                enabled:
                    _networkUrl != null ||
                    (localPath != null && localPath!.isNotEmpty),
                onTap: () {
                  if (_networkUrl != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _CapturedImagePreviewPage.network(
                          url: _networkUrl!,
                        ),
                      ),
                    );
                  } else if (localPath != null && localPath!.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            _CapturedImagePreviewPage.file(path: localPath!),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),

      // ---- Fixed bottom bar: Home + Capture Another ----
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _goHome(context),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Home'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => openDocketCamera(context),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture Another'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureDetails extends StatelessWidget {
  final bool imageUploaded;
  final bool detailsRecorded;
  final String? extra;

  const _FailureDetails({
    required this.imageUploaded,
    required this.detailsRecorded,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(bool ok, String label) => Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: ok ? Colors.green.shade800 : Colors.red.shade800,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(imageUploaded, 'Image uploaded'),
        const SizedBox(height: 6),
        row(detailsRecorded, 'Details saved to database'),
        if (extra != null && extra!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(extra!, style: const TextStyle(color: Colors.black87)),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF003366);
    final fg = enabled ? Colors.black87 : Colors.black38;

    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE8EEF6),
                child: Icon(icon, color: primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: fg,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: enabled ? Colors.black45 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapturedImagePreviewPage extends StatelessWidget {
  final String? url;
  final String? path;

  const _CapturedImagePreviewPage.network({required this.url}) : path = null;
  const _CapturedImagePreviewPage.file({required this.path}) : url = null;

  @override
  Widget build(BuildContext context) {
    final img = url != null
        ? Image.network(
            url!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Center(child: Text('Image unavailable')),
          )
        : Image.file(
            File(path!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Center(child: Text('Image unavailable')),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: Center(child: img),
    );
  }
}
