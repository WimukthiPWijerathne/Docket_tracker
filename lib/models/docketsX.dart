class Docket {
  final String id;
  final String docketType;
  final String depot;
  final String imageName;
  final String? uploadedBy;
  final String uploadedTime;
  final String? assignedTo;
  final String? assignTime;
  final String? completedTime;
  final String? docketSerial;
  final String? locationDetails;
  final String status;

  Docket({
    required this.id,
    required this.depot,
    required this.docketType,
    required this.imageName,
    this.uploadedBy,
    required this.uploadedTime,
    this.assignedTo,
    this.completedTime,
    this.docketSerial,
    this.assignTime,
    this.locationDetails,
    required this.status,
  });

  factory Docket.fromJson(Map<String, dynamic> json) {
    final docketId = json['ID']?.toString() ?? json['id']?.toString() ?? '';

    // Get status directly from API - the field is actually there
    // 0 = Unassigned, 1 = Assigned, 2 = Completed, 3 = Reassigned, 4 = Issue
    String statusValue = '0'; // Default to Unassigned

    // Use the status field provided by the API
    if (json['status'] != null) {
      statusValue = json['status'].toString();
      print('Docket ID: $docketId, status from API: $statusValue');
    } else {
      // Fallback logic if status isn't present in some records
      print('Docket ID: $docketId has no status field, using fallback logic');

      final hasCompletedTime =
          json['CompletedTime'] != null &&
          json['CompletedTime'].toString().isNotEmpty;
      final hasAssignedTo =
          json['AssignedTo'] != null &&
          json['AssignedTo'].toString().isNotEmpty;
      final hasAssignTime =
          json['AssignedTime'] != null &&
          json['AssignedTime'].toString().isNotEmpty;

      if (hasCompletedTime) {
        statusValue = '2'; // Completed
      } else if (hasAssignedTo || hasAssignTime) {
        statusValue = '1'; // Assigned
      }
    }

    return Docket(
      id: docketId,
      depot: json['Depot']?.toString() ?? '',
      docketType: json['DocketType']?.toString() ?? '',
      docketSerial: json['DocketSerial']?.toString(),
      completedTime: json['CompletedTime']?.toString(),
      assignedTo:
          json['AssignedTo']?.toString() ?? json['AssignTo']?.toString(),
      assignTime: json['AssignedTime']?.toString(),
      uploadedTime: json['UploadedTime']?.toString() ?? '',
      uploadedBy:
          json['uploadedBy']?.toString() ?? json['UploadedBy']?.toString(),
      imageName: json['ImageName']?.toString() ?? '',
      locationDetails: json['locationDetails']?.toString(),
      status: statusValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID': id,
      'Depot': depot,
      'DocketType': docketType,
      'DocketSerial': docketSerial,
      'CompletedTime': completedTime,
      'AssignedTo': assignedTo,
      'AssignedTime': assignTime,
      'UploadedTime': uploadedTime,
      'uploadedBy': uploadedBy,
      'ImageName': imageName,
      'locationDetails': locationDetails,
      'status': status,
    };
  }
}
