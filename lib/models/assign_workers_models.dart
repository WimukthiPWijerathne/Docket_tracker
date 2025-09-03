class AssignmentRequest {
  final String docketID;
  final String assignedPersons;
  final String assignedTime;
  final bool reassigned;
  final String uploadedBy;
  final String uploadedTime;

  AssignmentRequest({
    required this.docketID,
    required this.assignedPersons,
    required this.assignedTime,
    required this.reassigned,
    required this.uploadedBy,
    required this.uploadedTime,
  });

  Map<String, dynamic> toJson() => {
    'docketID': docketID,
    'assignedPersons': assignedPersons,
    'assignedTime': assignedTime,
    'reassigned': reassigned,
    'uploadedBy': uploadedBy,
    'uploadedTime': uploadedTime,
  };
}

class AssignmentResponse {
  final String status;
  final String message;
  final int? assignmentID;

  AssignmentResponse({required this.status, required this.message, this.assignmentID});

  factory AssignmentResponse.fromJson(Map<String, dynamic> json) {
    return AssignmentResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      assignmentID: json['assignmentID'] is int
          ? json['assignmentID']
          : int.tryParse(json['assignmentID']?.toString() ?? ''),
    );
  }

  bool get isSuccess => status.toLowerCase() == 'success';
}