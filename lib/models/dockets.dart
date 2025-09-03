class Docket {
  final String id;
  final String docketType;
  final String depot;
  final String imageName;
  final String uploadedBy;
  final String uploadedTime;
  final String assignedTo;
  final String assignTime;
  final String completedTime;
  final String docketSerial;

  Docket({
    required this.id,
    required this.depot,
    required this.docketType,
    required this.imageName,
    required this.uploadedBy,
    required this.uploadedTime,
    required this.assignedTo,
    required this.completedTime,
    required this.docketSerial,
    required this.assignTime,
  });

  factory Docket.fromJson(Map<String, dynamic> json) {
    return Docket(
      id: json['ID']?.toString() ?? json['id']?.toString() ?? '',
      depot: json['Depot']?.toString() ?? '',
      docketType: json['DocketType']?.toString() ?? '',
      docketSerial: json['DocketSerial']?.toString() ?? '',
      completedTime: json['CompletedTime']?.toString() ?? '',
      assignedTo: json['AssignedTo']?.toString() ?? json['AssignTo']?.toString() ?? '',
      assignTime: json['AssignedTime']?.toString() ?? '',
      uploadedTime: json['UploadedTime']?.toString() ?? '',
      uploadedBy: json['uploadedBy']?.toString() ?? json['UploadedBy']?.toString() ?? '',
      imageName: json['ImageName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'Depot': depot,
      'DocketType': docketType,
      'DocketSerial': docketSerial,
      'CompletedTime': completedTime,
      'AssignTo': assignedTo,
      'AssignedTime': assignTime,
      'UploadedTime': uploadedTime,
      'UploadedBy': uploadedBy,
      'ImageName': imageName,
    };
  }
}