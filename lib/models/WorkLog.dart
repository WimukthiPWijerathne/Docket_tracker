class WorkLog {
  final String id;
  final String assignmentId;
  final String docketId;
  final String employeeNo;
  final String? acknowledgedAt;
  final String? attendingAt;
  final String? startedAt;
  final String? completedAt;
  final String? remarks;
  final String? createdAt;
  final String? updatedAt;

  WorkLog({
    required this.id,
    required this.assignmentId,
    required this.docketId,
    required this.employeeNo,
    this.acknowledgedAt,
    this.attendingAt,
    this.startedAt,
    this.completedAt,
    this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  // Factory constructor to create WorkLog from JSON
  factory WorkLog.fromJson(Map<String, dynamic> json) {
    return WorkLog(
      id: json['id']?.toString() ?? '',
      assignmentId:
          json['assignmentId']?.toString() ??
          json['assignmentID']?.toString() ??
          '',
      docketId:
          json['docketId']?.toString() ?? json['docketID']?.toString() ?? '',
      employeeNo: json['employeeNo']?.toString() ?? '',
      acknowledgedAt: json['acknowledgedAt']?.toString(),
      attendingAt: json['attendingAt']?.toString(),
      startedAt: json['startedAt']?.toString(),
      completedAt: json['completedAt']?.toString(),
      remarks: json['remarks']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  // Convert WorkLog to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignmentId': assignmentId,
      'docketId': docketId,
      'employeeNo': employeeNo,
      'acknowledgedAt': acknowledgedAt,
      'attendingAt': attendingAt,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'remarks': remarks,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  @override
  String toString() {
    return 'WorkLog{id: $id, assignmentId: $assignmentId, docketId: $docketId, employeeNo: $employeeNo}';
  }
}
