import 'package:flutter/material.dart';

import 'docket_type_selection_page.dart';
import 'simple_preview_page.dart';
import '../../utils/docket_camera_helper.dart';
import '../../pages/docket_selection_page.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Docket Captured'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Header Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Docket Captured Successfully!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            docketType.toUpperCase(),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Action Buttons
                _buildActionButton(
                  context,
                  icon: Icons.camera_alt_rounded,
                  label: 'Capture Another Docket',
                  subtitle: 'Same type: $docketType',
                  onPressed: () async {
                    await openCustomCameraForDocket(context, docketType: docketType);
                  },
                ),
                
                const SizedBox(height: 16),
                
                _buildActionButton(
                  context,
                  icon: Icons.preview_rounded,
                  label: 'Preview Captured Image',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SimplePreviewPage(
                          filePath: filePath,
                          docketType: docketType,
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                _buildActionButton(
                  context,
                  icon: Icons.list_alt_rounded,
                  label: 'View All Dockets',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DocketSelectionPage(),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                _buildActionButton(
                  context,
                  icon: Icons.category_rounded,
                  label: 'Docket Type ',
                  color: colorScheme.surface,
                  textColor: colorScheme.onSurface,
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DocketTypeSelectionPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    Color? color,
    Color? textColor,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final isDefaultColor = color == null;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDefaultColor
                      ? theme.primaryColor.withOpacity(0.1)
                      : theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDefaultColor ? theme.primaryColor : textColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textColor ?? theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

}
