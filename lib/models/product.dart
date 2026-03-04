import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final double costPrice;
  final double sellingPrice;
  final double commissionAmount;
  final int stock;
  final List<String> images;
  final double rating;
  final bool isApproved;
  final String sellerId;
  final String? supplierId;
  final Timestamp createdAt;

  Product({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.costPrice,
    required this.sellingPrice,
    required this.commissionAmount,
    required this.stock,
    required this.images,
    required this.rating,
    required this.isApproved,
    required this.sellerId,
    this.supplierId,
    required this.createdAt,
  });

  factory Product.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      titleAr: data['titleAr'] ?? '',
      titleEn: data['titleEn'] ?? '',
      descriptionAr: data['descriptionAr'] ?? '',
      descriptionEn: data['descriptionEn'] ?? '',
      costPrice: (data['costPrice'] ?? 0).toDouble(),
      sellingPrice: (data['sellingPrice'] ?? 0).toDouble(),
      commissionAmount: (data['commissionAmount'] ?? 0).toDouble(),
      stock: data['stock'] ?? 0,
      images: List<String>.from(data['images'] ?? []),
      rating: (data['rating'] ?? 0).toDouble(),
      isApproved: data['isApproved'] ?? false,
      sellerId: data['sellerId'],
      supplierId: data['supplierId'],
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toMap() => {
        'titleAr': titleAr,
        'titleEn': titleEn,
        'descriptionAr': descriptionAr,
        'descriptionEn': descriptionEn,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'commissionAmount': commissionAmount,
        'stock': stock,
        'images': images,
        'rating': rating,
        'isApproved': isApproved,
        'sellerId': sellerId,
        'supplierId': supplierId,
        'createdAt': createdAt,
      };
}
