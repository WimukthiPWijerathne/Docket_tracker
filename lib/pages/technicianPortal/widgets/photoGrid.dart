import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/ImageModel.dart';

class PhotoGrid extends StatelessWidget {
  final List<ImageModel> images;
  const PhotoGrid({super.key, required this.images});

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
        final uri = images[i].imageUrl;
        final isNet = uri.startsWith('http://') || uri.startsWith('https://');
        final widget = isNet
            ? Image.network(uri, fit: BoxFit.cover)
            : (File(uri).existsSync()
                  ? Image.file(File(uri), fit: BoxFit.cover)
                  : Image.asset(uri, fit: BoxFit.cover));
        return ClipRRect(borderRadius: BorderRadius.circular(8), child: widget);
      },
    );
  }
}
