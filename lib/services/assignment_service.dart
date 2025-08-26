import 'package:flutter/foundation.dart';

class AssignmentService extends ChangeNotifier {
  static final AssignmentService _instance = AssignmentService._internal();
  factory AssignmentService() => _instance;
  AssignmentService._internal() {
    _initializeData();
  }

  void _initializeData() {
    // Ensure data is initialized when service is created
    if (_docketCounts.isEmpty) {
      _docketCounts.addAll({
        'Service Line Maintenance': 12,
        'Meter Testing': 8,
        'Estimate': 15,
        'Per Visit': 23,
        'Pole Disconnection': 5,
        'Material Remove': 9,
        'Meter Replacement Only': 17,
        'Visit with Contractor': 11,
        'Pole Top Maintenance': 6,
      });
    }
  }

  // All available workers initially
  final List<String> _allWorkers = [
    'කමල්', 'අමල්', 'සුනිල්', 'චමින්ද',
    'රුවන්', 'නිමල්', 'සමන්', 'ජයන්ත',
  ];

  // Track assigned workers globally
  final Set<String> _assignedWorkers = <String>{};

  // Track docket counts - initialized in constructor
  final Map<String, int> _docketCounts = <String, int>{};

  // Track assignments (docket type -> list of assigned workers)
  final Map<String, List<String>> _assignments = <String, List<String>>{};

  // Getters
  List<String> get availableWorkers => 
      _allWorkers.where((worker) => !_assignedWorkers.contains(worker)).toList();
  
  Set<String> get assignedWorkers => Set.from(_assignedWorkers);
  
  Map<String, int> get docketCounts => Map.from(_docketCounts);
  
  Map<String, List<String>> get assignments => Map.from(_assignments);

  // Check if a worker is available
  bool isWorkerAvailable(String worker) {
    return !_assignedWorkers.contains(worker);
  }

  // Assign workers to a docket type
  void assignWorkers(String docketType, List<String> workers) {
    if (workers.isEmpty) return;

    // Add workers to assigned set
    _assignedWorkers.addAll(workers);

    // Track the assignment
    if (_assignments.containsKey(docketType)) {
      _assignments[docketType]!.addAll(workers);
    } else {
      _assignments[docketType] = List.from(workers);
    }

    // Reduce docket count by number of workers assigned
    if (_docketCounts.containsKey(docketType)) {
      _docketCounts[docketType] = 
          (_docketCounts[docketType]! - workers.length).clamp(0, double.infinity).toInt();
    }

    notifyListeners();
  }

  // Get workers assigned to a specific docket type
  List<String> getAssignedWorkers(String docketType) {
    return _assignments[docketType] ?? [];
  }

  // Reset all assignments (for testing/demo purposes)
  void resetAssignments() {
    _assignedWorkers.clear();
    _assignments.clear();
    
    // Reset docket counts to original values
    _docketCounts.clear();
    _docketCounts.addAll({
      'Service Line Maintenance': 12,
      'Meter Testing': 8,
      'Estimate': 15,
      'Per Visit': 23,
      'Pole Disconnection': 5,
      'Material Remove': 9,
      'Meter Replacement Only': 17,
      'Visit with Contractor': 11,
      'Pole Top Maintenance': 6,
    });

    notifyListeners();
  }

  // Get total number of assignments
  int get totalAssignments => _assignedWorkers.length;

  // Get available docket types (with count > 0)
  List<String> get availableDocketTypes => 
      _docketCounts.entries
          .where((entry) => entry.value > 0)
          .map((entry) => entry.key)
          .toList();
}
