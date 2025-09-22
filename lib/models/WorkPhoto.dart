class WorkPhoto {
  final String id;
  final String workLogId;
  final String kind;
  final String imageName;
  final String caption;
  final String sequence;
  final String uploadedBy;
  final String uploadedAt;
  final String updatedAt;

  WorkPhoto({
    required this.id,
    required this.workLogId,
    required this.kind,
    required this.imageName,
    required this.caption,
    required this.sequence,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.updatedAt,
  });

  // Factory constructor to create WorkPhoto from JSON
  factory WorkPhoto.fromJson(Map<String, dynamic> json) {
    return WorkPhoto(
      id: json['id']?.toString() ?? '',
      workLogId: json['workLogId']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      imageName: json['imageName']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      sequence: json['sequence']?.toString() ?? '',
      uploadedBy: json['uploadedBy']?.toString() ?? '',
      uploadedAt: json['uploadedAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  // Convert WorkPhoto to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workLogId': workLogId,
      'kind': kind,
      'imageName': imageName,
      'caption': caption,
      'sequence': sequence,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt,
      'updatedAt': updatedAt,
    };
  }

  @override
  String toString() {
    return 'WorkPhoto{id: $id, workLogId: $workLogId, kind: $kind, imageName: $imageName}';
  }
}
