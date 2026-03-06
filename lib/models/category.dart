import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String nameAr;
  final String nameEn;
  final String? imageUrl;
  final Timestamp createdAt;

  Category({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.imageUrl,
    required this.createdAt,
  });

  factory Category.fromMap(Map<String, dynamic> map, String id) {
    return Category(
      id: id,
      nameAr: map['nameAr'] ?? '',
      nameEn: map['nameEn'] ?? '',
      imageUrl: map['imageUrl'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  factory Category.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Category.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'imageUrl': imageUrl,
        'createdAt': createdAt,
      };

  String get name => nameAr; // For simplicity, return Arabic name
}
