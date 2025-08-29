import 'package:flutter/material.dart';

import 'image_preview_page.dart';
import 'docket_type_selection_page.dart';
import '../../utils/docket_camera_helper.dart';

class PostCaptureOptionsPage extends StatelessWidget {
  final String filePath;
  final String docketType;

  const PostCaptureOptionsPage({
    super.key,
    required this.filePath,
    required this.docketType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Docket Captured'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text(
                'Docket Captured',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Type: $docketType',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              
              // Capture Another Docket of Same Type Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await openCustomCameraForDocket(context, docketType: docketType);
                  },
                  child: const Text('Capture Another Docket of Same Type'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Go to Docket Type Selection Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DocketTypeSelectionPage(),
                      ),
                    );
                  },
                  child: const Text('Go to Docket Type Selection'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Preview Captured Image Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ImagePreviewPage(filePath: filePath, docketType: docketType),
                      ),
                    );
                  },
                  child: const Text('Preview Captured Image'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
