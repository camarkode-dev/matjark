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
  final String? categoryId;
  final int salesCount;
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
    this.categoryId,
    this.salesCount = 0,
    required this.createdAt,
  });

  factory Product.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawImages = data['images'];
    final images = rawImages is List
        ? rawImages
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList()
        : <String>[];
    final fallbackImage = (data['imageUrl'] ?? '').toString().trim();
    if (images.isEmpty && fallbackImage.isNotEmpty) {
      images.add(fallbackImage);
    }

    return Product(
      id: doc.id,
      titleAr: data['titleAr'] ?? '',
      titleEn: data['titleEn'] ?? '',
      descriptionAr: data['descriptionAr'] ?? '',
      descriptionEn: data['descriptionEn'] ?? '',
      costPrice: (data['costPrice'] ?? 0).toDouble(),
      sellingPrice: (data['sellingPrice'] ?? 0).toDouble(),
      commissionAmount: (data['commissionAmount'] ?? 0).toDouble(),
      stock: ((data['stock'] ?? 0) as num).toInt(),
      images: images,
      rating: (data['rating'] ?? 0).toDouble(),
      isApproved: data['isApproved'] ?? false,
      sellerId: (data['sellerId'] ?? data['vendorId'] ?? '').toString(),
      supplierId: data['supplierId'],
      categoryId: data['categoryId'] as String?,
      salesCount: ((data['salesCount'] ?? 0) as num).toInt(),
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
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
        'categoryId': categoryId,
        'salesCount': salesCount,
        'createdAt': createdAt,
      };
}
