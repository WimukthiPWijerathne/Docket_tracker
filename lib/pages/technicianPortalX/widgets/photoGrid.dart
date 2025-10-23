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
                  imageUri.startsWith('http://') ||
                      imageUri.startsWith('https://')
                  ? Image.network(
                      imageUri,
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
                  : File(imageUri).existsSync()
                  ? Image.file(File(imageUri), fit: BoxFit.contain)
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

        // Use the official WorkLogService.getImageUrl method for consistency
        final uri = WorkLogService.getImageUrl(workPhoto);

        // Debug print to see what URL is being used
        print('DEBUG PhotoGrid: Photo ${i + 1}');
        print(
          'DEBUG PhotoGrid: WorkPhoto.imageName = "${workPhoto.imageName}"',
        );
        print('DEBUG PhotoGrid: WorkPhoto.kind = "${workPhoto.kind}"');
        print('DEBUG PhotoGrid: Official getImageUrl URI = "$uri"');

        final isNet = uri.startsWith('http://') || uri.startsWith('https://');
        final widget = isNet
            ? Image.network(
                uri,
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
                errorBuilder: (context, error, stackTrace) {
                  print('DEBUG PhotoGrid: Image load error for URI "$uri"');
                  print('DEBUG PhotoGrid: Error = $error');
                  print('DEBUG PhotoGrid: StackTrace = $stackTrace');

                  // Try to provide more helpful error information
                  String errorMsg = 'Load Failed';
                  if (error.toString().contains('404')) {
                    errorMsg = 'Not Found';
                  } else if (error.toString().contains('403')) {
                    errorMsg = 'Forbidden';
                  } else if (error.toString().contains('500')) {
                    errorMsg = 'Server Error';
                  } else if (error.toString().contains('timeout')) {
                    errorMsg = 'Timeout';
                  }

                  return Container(
                    color: Colors.grey[300],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          errorMsg,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
