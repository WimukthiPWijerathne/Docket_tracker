import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/WorkPhoto.dart';
import '../services/workLogService.dart';

class PhotoGrid extends StatelessWidget {
  final List<WorkPhoto> images;
  const PhotoGrid({super.key, required this.images});

  void _showFullScreenPreview(
    BuildContext context,
    String imageUri,
    WorkPhoto workPhoto,
  ) {
    // Use the proper URL construction method for full screen preview
    final properImageUri = WorkLogService.getImageUrl(workPhoto);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black87,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              '${workPhoto.kind} Photo',
              style: const TextStyle(color: Colors.white),
            ),
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
              child:
                  properImageUri.startsWith('http://') ||
                      properImageUri.startsWith('https://')
                  ? Image.network(
                      properImageUri,
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
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.white70,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                    )
                  : File(properImageUri).existsSync()
                  ? Image.file(File(properImageUri), fit: BoxFit.contain)
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.white70,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Image not found',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const Text(
        'No photos yet',
        style: TextStyle(color: Colors.black54),
      );
    }
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) {
        final workPhoto = images[i];
        // Use the proper URL construction method
        final uri = WorkLogService.getImageUrl(workPhoto);

        final isNet = uri.startsWith('http://') || uri.startsWith('https://');
        final widget = isNet
            ? Image.network(
                uri,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, color: Colors.red),
                  );
                },
              )
            : (File(uri).existsSync()
                  ? Image.file(File(uri), fit: BoxFit.cover)
                  : Image.asset(uri, fit: BoxFit.cover));

        return GestureDetector(
          onTap: () => _showFullScreenPreview(context, uri, workPhoto),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget,
                // Add a subtle overlay to indicate it's tappable
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
    );
  }
}
