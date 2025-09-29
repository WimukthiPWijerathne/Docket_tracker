import 'package:flutter/material.dart';

class WorkersSummeryPage extends StatelessWidget {
  const WorkersSummeryPage({super.key});

  static const Color _primaryColor = Color(0xFF003366);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workers Summary'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Icon(Icons.groups, size: 64, color: Colors.blueGrey),
              SizedBox(height: 16),
              Text(
                'Workers Summary View',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This is a placeholder. Show worker-wise stats here (counts, completed, ongoing, etc.).',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

