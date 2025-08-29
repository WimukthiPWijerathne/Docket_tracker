import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../post_capture_options_page.dart';

class UploadResultPage extends StatefulWidget {
  final bool isSuccess;
  final String? filePath;
  final String docketType;
  final String? errorMessage;

  const UploadResultPage({
    super.key,
    required this.isSuccess,
    this.filePath,
    required this.docketType,
    this.errorMessage,
  });

  @override
  State<UploadResultPage> createState() => _UploadResultPageState();
}

class _UploadResultPageState extends State<UploadResultPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSuccess ? 'Upload Success' : 'Upload Failed'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Animated icon
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Opacity(
                  opacity: _animation.value,
                  child: Icon(
                    widget.isSuccess ? Icons.check_circle : Icons.error,
                    size: 80,
                    color: widget.isSuccess ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Success/failure message
            Text(
              widget.isSuccess
                  ? 'Docket details uploaded successfully!'
                  : 'Failed to upload docket details.',
              style: TextStyle(
                fontSize: 20,
                color: widget.isSuccess ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            // Error message if available
            if (!widget.isSuccess && widget.errorMessage != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Error: ${widget.errorMessage}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 40),

            // Action buttons
            if (widget.isSuccess) ...[
              // Success - Continue to post-capture options
              CupertinoButton(
                color: const Color(0xFF00AEE4),
                onPressed: () {
                  if (widget.filePath != null) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => PostCaptureOptionsPage(
                          filePath: widget.filePath!,
                          docketType: widget.docketType,
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Continue'),
              ),
            ] else ...[
              // Failure - Retry and Cancel options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CupertinoButton(
                    color: Colors.grey,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    color: Colors.orange,
                    onPressed: () {
                      // Go back to retry upload
                      Navigator.of(context).pop();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Always show a way to go back
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                'Return to Home',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}