// Model for Docket Assignment returned by GETDocketAssignmentX.php
class DocketAssignmentModel {
  final String assignmentID;
  final String docketID;
  final String assignedPersons;
  final String? assignedTime;
  final String? status;
  final String? uploadedBy;
  final String? uploadedTime;
  final String? completedTime;

  DocketAssignmentModel({
    required this.assignmentID,
    required this.docketID,
    required this.assignedPersons,
    this.assignedTime,
    this.status,
    this.uploadedBy,
    this.uploadedTime,
    this.completedTime,
  });

  factory DocketAssignmentModel.fromJson(Map<String, dynamic> json) {
    return DocketAssignmentModel(
      assignmentID: (json['assignmentID'] ?? '').toString(),
      docketID: (json['docketID'] ?? '').toString(),
      assignedPersons: (json['assignedPersons'] ?? '').toString(),
      assignedTime:
          json.containsKey('assignedTime') && json['assignedTime'] != null
          ? json['assignedTime'].toString()
          : null,
      status: json.containsKey('status') && json['status'] != null
          ? json['status'].toString()
          : null,
      uploadedBy: json.containsKey('uploadedBy') && json['uploadedBy'] != null
          ? json['uploadedBy'].toString()
          : null,
      uploadedTime:
          json.containsKey('uploadedTime') && json['uploadedTime'] != null
          ? json['uploadedTime'].toString()
          : null,
      completedTime:
          json.containsKey('completedTime') && json['completedTime'] != null
          ? json['completedTime'].toString()
          : null,
    );
  }
}
