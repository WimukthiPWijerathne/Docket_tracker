import 'package:flutter/material.dart';

class DailyAssignmentsPage extends StatelessWidget {
  const DailyAssignmentsPage({super.key});

  static const Color _primaryColor = Color(0xFF003366);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Assignments'),
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
              Icon(Icons.today, size: 64, color: Colors.blueGrey),
              SizedBox(height: 16),
              Text(
                'Daily Assignments View',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This is a placeholder. Integrate the filters and charts you need here.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
