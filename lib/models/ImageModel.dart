class ImageModel {
  final String id;
  final String title;
  final String imageUrl;
  final String? description;
  final DateTime? createdAt;

  ImageModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.description,
    this.createdAt,
  });

  // Factory constructor to create ImageModel from JSON
  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      description: json['description'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  // Convert ImageModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'ImageModel{id: $id, title: $title, imageUrl: $imageUrl}';
  }
}