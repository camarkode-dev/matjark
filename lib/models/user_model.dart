import 'package:cloud_firestore/cloud_firestore.dart';

/// Representation of a user stored in Firestore.
/// Includes role information used for RBAC.

enum UserRole { customer, seller, supplier, admin, guest }

class AppUser {
  final String uid;
  final String? name;
  final String? email;
  final String? phone;
  final UserRole role;
  final bool isApproved;
  final String language;
  final Timestamp createdAt;

  AppUser({
    required this.uid,
    this.name,
    this.email,
    this.phone,
    required this.role,
    this.isApproved = false,
    this.language = 'ar',
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      name: map['name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      role: _roleFromString(map['role'] as String?),
      isApproved: map['isApproved'] as bool? ?? false,
      language: map['language'] as String? ?? 'ar',
      createdAt: map['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'isApproved': isApproved,
      'language': language,
      'createdAt': createdAt,
    };
  }

  static UserRole _roleFromString(String? value) {
    switch (value) {
      case 'seller':
        return UserRole.seller;
      case 'supplier':
        return UserRole.supplier;
      case 'admin':
        return UserRole.admin;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }
}
