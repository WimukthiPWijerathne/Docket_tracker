class AssignedDocket {
  final String assignmentID;
  final String docketID;
  final String assignedPersons;
  final String assignedTime;
  final String reassigned;
  final String uploadedBy;
  final String uploadedTime;
  final String? completedTime;

  AssignedDocket({
    required this.assignmentID,
    required this.docketID,
    required this.assignedPersons,
    required this.assignedTime,
    required this.reassigned,
    required this.uploadedBy,
    required this.uploadedTime,
    this.completedTime,
  });

  factory AssignedDocket.fromJson(Map<String, dynamic> json) {
    return AssignedDocket(
      assignmentID: json['assignmentID']?.toString() ?? 
                   json['AssignmentID']?.toString() ?? 
                   json['assignment_id']?.toString() ?? '',
      docketID: json['docketID']?.toString() ?? 
               json['DocketID']?.toString() ?? 
               json['docket_id']?.toString() ?? '',
      assignedPersons: json['assignedPersons']?.toString() ?? 
                      json['AssignedPersons']?.toString() ?? 
                      json['assigned_persons']?.toString() ?? '',
      assignedTime: json['assignedTime']?.toString() ?? 
                   json['AssignedTime']?.toString() ?? 
                   json['assigned_time']?.toString() ?? '',
      reassigned: json['reassigned']?.toString() ?? 
                 json['Reassigned']?.toString() ?? 
                 json['reassign_count']?.toString() ?? '0',
      uploadedBy: json['uploadedBy']?.toString() ?? 
                 json['UploadedBy']?.toString() ?? 
                 json['uploaded_by']?.toString() ?? '',
      uploadedTime: json['uploadedTime']?.toString() ?? 
                   json['UploadedTime']?.toString() ?? 
                   json['uploaded_time']?.toString() ?? '',
      completedTime: json['completedTime']?.toString() ?? 
                    json['CompletedTime']?.toString() ?? 
                    json['completed_time']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assignmentID': assignmentID,
      'docketID': docketID,
      'assignedPersons': assignedPersons,
      'assignedTime': assignedTime,
      'reassigned': reassigned,
      'uploadedBy': uploadedBy,
      'uploadedTime': uploadedTime,
      'completedTime': completedTime,
    };
  }

  // Helper method to check if docket is completed
  bool get isCompleted => completedTime != null && completedTime!.isNotEmpty;

  // Helper method to check if docket is ongoing
  bool get isOngoing => completedTime == null || completedTime!.isEmpty;

  // Helper method to get status string
  String get statusText => isCompleted ? 'Completed' : 'In Progress';

  // Helper method to get status for display
  String get displayStatus => isCompleted ? 'Completed' : 'On Progress';

  // Helper method to get reassignment count as int
  int get reassignmentCount {
    try {
      return int.parse(reassigned);
    } catch (e) {
      return 0;
    }
  }

  // Helper method to check if docket has been reassigned
  bool get hasBeenReassigned => reassignmentCount > 0;

  // Helper method to get list of assigned person IDs
  List<String> get assignedPersonsList {
    if (assignedPersons.isEmpty) return [];
    return assignedPersons.split(',').map((e) => e.trim()).toList();
  }

  // Helper method to parse assigned time as DateTime
  DateTime? get assignedDateTime {
    try {
      return assignedTime.isNotEmpty ? DateTime.parse(assignedTime) : null;
    } catch (e) {
      return null;
    }
  }

  // Helper method to parse completed time as DateTime
  DateTime? get completedDateTime {
    try {
      return (completedTime != null && completedTime!.isNotEmpty) ? DateTime.parse(completedTime!) : null;
    } catch (e) {
      return null;
    }
  }

  // Helper method to parse uploaded time as DateTime
  DateTime? get uploadedDateTime {
    try {
      return uploadedTime.isNotEmpty ? DateTime.parse(uploadedTime) : null;
    } catch (e) {
      return null;
    }
  }

  // Helper method to get formatted assigned time
  String get formattedAssignedTime {
    final dateTime = assignedDateTime;
    if (dateTime == null) return "N/A";
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  // Helper method to get formatted completed time
  String get formattedCompletedTime {
    if (!isCompleted) return "On Progress";
    final dateTime = completedDateTime;
    if (dateTime == null) return "On Progress";
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  // Helper method to get formatted uploaded time
  String get formattedUploadedTime {
    final dateTime = uploadedDateTime;
    if (dateTime == null) return "N/A";
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  // Helper method to calculate duration from assignment to completion
  Duration? get workDuration {
    final assigned = assignedDateTime;
    final completed = completedDateTime;
    if (assigned != null && completed != null) {
      return completed.difference(assigned);
    }
    return null;
  }

  // Helper method to get formatted work duration
  String get formattedWorkDuration {
    if (!isCompleted) return "In Progress";
    
    final duration = workDuration;
    if (duration == null) return "N/A";
    
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    
    if (days > 0) {
      return "${days}d ${hours}h ${minutes}m";
    } else if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
  }

  // Helper method to get time since assignment (for ongoing tasks)
  String get timeSinceAssignment {
    final assigned = assignedDateTime;
    if (assigned == null) return "N/A";
    
    final now = DateTime.now();
    final duration = now.difference(assigned);
    
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    
    if (days > 0) {
      return "${days}d ${hours}h ago";
    } else if (hours > 0) {
      return "${hours}h ${minutes}m ago";
    } else {
      return "${minutes}m ago";
    }
  }

  // Helper method to check if task is overdue (you can customize the threshold)
  bool isOverdue({int hoursThreshold = 24}) {
    if (isCompleted) return false;
    
    final assigned = assignedDateTime;
    if (assigned == null) return false;
    
    final now = DateTime.now();
    final duration = now.difference(assigned);
    
    return duration.inHours > hoursThreshold;
  }

  @override
  String toString() {
    return 'AssignedDocket(assignmentID: $assignmentID, docketID: $docketID, assignedTo: $assignedPersons, status: $statusText)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AssignedDocket && other.assignmentID == assignmentID;
  }

  @override
  int get hashCode => assignmentID.hashCode;

  // Copy method for creating modified instances
  AssignedDocket copyWith({
    String? assignmentID,
    String? docketID,
    String? assignedPersons,
    String? assignedTime,
    String? reassigned,
    String? uploadedBy,
    String? uploadedTime,
    String? completedTime,
  }) {
    return AssignedDocket(
      assignmentID: assignmentID ?? this.assignmentID,
      docketID: docketID ?? this.docketID,
      assignedPersons: assignedPersons ?? this.assignedPersons,
      assignedTime: assignedTime ?? this.assignedTime,
      reassigned: reassigned ?? this.reassigned,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedTime: uploadedTime ?? this.uploadedTime,
      completedTime: completedTime ?? this.completedTime,
    );
  }
}