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

  factory Category.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      nameAr: data['nameAr'],
      nameEn: data['nameEn'],
      imageUrl: data['imageUrl'],
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toMap() => {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'imageUrl': imageUrl,
        'createdAt': createdAt,
      };
}
