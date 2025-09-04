import 'dart:io';
import 'package:flutter/material.dart';

class SimplePreviewPage extends StatelessWidget {
  final String filePath;
  final String docketType;

  const SimplePreviewPage({
    super.key,
    required this.filePath,
    required this.docketType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Preview'),
        backgroundColor: const Color(0xFF003366), // LECO primary color
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 3.0,
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load image: $error'),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
