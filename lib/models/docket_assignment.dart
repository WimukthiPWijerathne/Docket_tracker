class DocketAssignment {
  final String docketId;
  final String assignedPersons;
  final String assignedTime;
  final String reassigned;
  final String uploadedBy;
  final String uploadedTime;
  final String? assignmentId;
  final String? completedTime;

  DocketAssignment({
    required this.docketId,
    required this.assignedPersons,
    required this.assignedTime,
    this.reassigned = 'false',
    required this.uploadedBy,
    required this.uploadedTime,
    this.assignmentId,
    this.completedTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'docketID': docketId,
      'assignmentId': assignmentId, // Fallback to docketId if assignmentId is null
      'assignedPersons': assignedPersons,
      'assignedTime': assignedTime,
      'reassigned': reassigned,
      'uploadedBy': uploadedBy,
      'uploadedTime': uploadedTime,
      'completedTime': completedTime,
    };
  }

  factory DocketAssignment.fromJson(Map<String, dynamic> json) {
    return DocketAssignment(
      docketId: json['docketID'] ?? json['docketId'] ?? '', // Support both docketID and docketId
      assignedPersons: json['assignedPersons'] ?? '',
      assignedTime: json['assignedTime'] ?? '',
      reassigned: (json['reassigned'] ?? 'false').toString(),
      assignmentId: json['assignmentId']?.toString() ?? json['docketID']?.toString(), // Fallback to docketID if assignmentId is null
      completedTime: json['completedTime']?.toString(),
      uploadedBy: json['uploadedBy'] ?? '',
      uploadedTime: json['uploadedTime'] ?? '',
    );
  }

  @override
  String toString() {
    return 'DocketAssignment(docketId: $docketId, assignedPersons: $assignedPersons, assignedTime: $assignedTime, reassigned: $reassigned, uploadedBy: $uploadedBy, uploadedTime: $uploadedTime)';
  }
}

class AssignmentResult {
  final String docketId;
  final String worker;
  final bool isSuccess;
  final String? errorMessage;
  final DateTime timestamp;

  AssignmentResult({
    required this.docketId,
    required this.worker,
    required this.isSuccess,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'AssignmentResult(docketId: $docketId, worker: $worker, isSuccess: $isSuccess, errorMessage: $errorMessage, timestamp: $timestamp)';
  }
}

class AssignmentResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  AssignmentResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory AssignmentResponse.fromJson(Map<String, dynamic> json) {
    return AssignmentResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'],
    );
  }

  @override
  String toString() {
    return 'AssignmentResponse(success: $success, message: $message, data: $data)';
  }
}