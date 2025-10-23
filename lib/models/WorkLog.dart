class WorkLog {
  final String id;
  final String assignmentId;
  final String docketId;
  final String employeeNo;
  final String? status;
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
    this.status,
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
      status: json['status']?.toString(),
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
      'status': status,
      'acknowledgedAt': acknowledgedAt,
      'attendingAt': attendingAt,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'remarks': remarks,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create a copy of WorkLog with optional parameter updates
  WorkLog copyWith({
    String? id,
    String? assignmentId,
    String? docketId,
    String? employeeNo,
    String? status,
    String? acknowledgedAt,
    String? attendingAt,
    String? startedAt,
    String? completedAt,
    String? remarks,
    String? createdAt,
    String? updatedAt,
  }) {
    return WorkLog(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      docketId: docketId ?? this.docketId,
      employeeNo: employeeNo ?? this.employeeNo,
      status: status ?? this.status,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      attendingAt: attendingAt ?? this.attendingAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'WorkLog{id: $id, assignmentId: $assignmentId, docketId: $docketId, employeeNo: $employeeNo}';
  }
}
