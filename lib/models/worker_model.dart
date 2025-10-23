// worker_model.dart
class Worker {
  final String personID;
  final String name;
  final String depot;
  final String available; // "1" for available, "0" for not available
  final String employeeNo;
  final String designation;
  final String accessLevel;

  Worker({
    required this.personID,
    required this.name,
    required this.depot,
    required this.available,
    required this.employeeNo,
    required this.designation,
    required this.accessLevel,
  });

  /// Factory constructor to create a Worker object from JSON
  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      personID: json['personID']?.toString() ?? '',
      name: "${json['firstName'] ?? ''} ${json['lastName'] ?? ''}".trim(),
      depot: json['depot']?.toString() ?? 'Unknown',
      available: json['available']?.toString() ?? '1',
      employeeNo: json['employeeNo']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      accessLevel: json['accessLevel']?.toString() ?? '',
    );
  }

  /// Convert Worker object back to JSON
  Map<String, dynamic> toJson() {
    return {
      'personID': personID,
      'name': name,
      'depot': depot,
      'available': available,
      'employeeNo': employeeNo,
      'designation': designation,
      'accessLevel': accessLevel,
    };
  }

  /// Helper getters
  bool get isAvailable => available == '1' || available.toLowerCase() == 'yes';
  String get id => personID;
  String get department => depot;
  String get status => isAvailable ? 'active' : 'inactive';
}
