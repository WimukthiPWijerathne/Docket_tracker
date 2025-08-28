class DocketDetails {
  final int? id;
  final String depot;
  final String docketType;
  final String imageName;
  final String uploadedBy;
  final DateTime? uploadedTime;
  final String assignedTo;
  final String assignedTime;
  final String completedTime;
  final String docketSerial;

  DocketDetails({
    this.id,
    required this.depot,
    required this.docketType,
    required this.imageName,
    required this.uploadedBy,
    this.uploadedTime,
    required this.assignedTo,
    required this.assignedTime,
    required this.completedTime,
    required this.docketSerial,
  });

  Map<String, dynamic> toJson() => {
    'Depot': depot,
    'DocketType': docketType,
    'ImageName': imageName,
    'uploadedBy': uploadedBy,
    'UploadedTime': uploadedTime?.toIso8601String(),
    'AssignedTo': assignedTo,
    'AssignedTime': assignedTime,
    'CompletedTime': completedTime,
    'DocketSerial': docketSerial,
  };
}
