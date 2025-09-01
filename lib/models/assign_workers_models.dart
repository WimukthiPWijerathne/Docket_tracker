class AssignmentRequest {
  final String docketId;
  final String assignedTo;

  AssignmentRequest({required this.docketId, required this.assignedTo});

  Map<String, dynamic> toJson() => {
        'docketId': docketId,
        'assignedTo': assignedTo,
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