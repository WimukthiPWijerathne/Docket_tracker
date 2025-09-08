class AssignedDocket {
  final String docketID;
  final String assignedPersons;
  final String assignedTime;
  final String reassigned;
  final String completedTime;
  final String docketType;

  

  AssignedDocket({
    required this.docketID,
    required this.assignedPersons,
    required this.assignedTime,
    required this.reassigned,
    required this.completedTime,
    required this.docketType,
 
  });

  factory AssignedDocket.fromJson(Map<String, dynamic> json) {
    return AssignedDocket(
      docketID: json['docketID']?.toString() ?? 
                json['DocketID']?.toString() ?? 
                json['id']?.toString() ?? 
                json['ID']?.toString() ?? '',
      assignedPersons: json['assignedPersons']?.toString() ?? 
                      json['AssignedPersons']?.toString() ?? 
                      json['assigned_persons']?.toString() ?? '',
      assignedTime: json['assignedTime']?.toString() ?? 
                   json['AssignedTime']?.toString() ?? 
                   json['assigned_time']?.toString() ?? '',
      reassigned: json['reassigned']?.toString() ?? 
                 json['Reassigned']?.toString() ?? 
                 json['reassign_count']?.toString() ?? '0',
      completedTime: json['completedTime']?.toString() ?? 
                    json['CompletedTime']?.toString() ?? 
                    json['completed_time']?.toString() ?? '',
      docketType: json['docketType']?.toString() ?? 
                 json['DocketType']?.toString() ?? 
                 json['type']?.toString() ?? '',
   
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'docketID': docketID,
      'assignedPersons': assignedPersons,
      'assignedTime': assignedTime,
      'reassigned': reassigned,
      'completedTime': completedTime,
      'docketType': docketType,
    
    };
  }

  // Helper method to check if docket is completed
  bool get isCompleted => completedTime.isNotEmpty;

  // Helper method to check if docket is ongoing
  bool get isOngoing => completedTime.isEmpty;

  // Helper method to get status string
  String get statusText => isCompleted ? 'Completed' : 'Ongoing';

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
      return completedTime.isNotEmpty ? DateTime.parse(completedTime) : null;
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
    final dateTime = completedDateTime;
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

  @override
  String toString() {
    return 'AssignedDocket(docketID: $docketID, assignedTo: $assignedPersons, status: $statusText)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AssignedDocket && other.docketID == docketID;
  }

  @override
  int get hashCode => docketID.hashCode;

  // Copy method for creating modified instances
  AssignedDocket copyWith({
    String? docketID,
    String? assignedPersons,
    String? assignedTime,
    String? reassigned,
    String? completedTime,
    String? docketType,
    String? depot,
    String? priority,
    String? status,
    String? notes,
  }) {
    return AssignedDocket(
      docketID: docketID ?? this.docketID,
      assignedPersons: assignedPersons ?? this.assignedPersons,
      assignedTime: assignedTime ?? this.assignedTime,
      reassigned: reassigned ?? this.reassigned,
      completedTime: completedTime ?? this.completedTime,
      docketType: docketType ?? this.docketType,
 
    );
  }
}