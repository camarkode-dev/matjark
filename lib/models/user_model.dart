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
  final String status;
  final bool isApproved;
  final String sellerRequestStatus;
  final String language;
  final String themeMode;
  final Timestamp createdAt;

  AppUser({
    required this.uid,
    this.name,
    this.email,
    this.phone,
    required this.role,
    this.status = 'approved',
    this.isApproved = false,
    this.sellerRequestStatus = 'none',
    this.language = 'ar',
    this.themeMode = 'light',
    required this.createdAt,
  });

  factory AppUser.fromMap(
    Map<String, dynamic> map, {
    String? fallbackUid,
  }) {
    return AppUser(
      uid: _readString(map['uid']) ?? fallbackUid ?? '',
      name: _readString(map['name']),
      email: _readString(map['email']),
      phone: _readString(map['phone']),
      role: _roleFromString(_readString(map['role'])),
      status: _statusFromMap(map),
      isApproved: _readBool(map['isApproved']),
      sellerRequestStatus: _readString(map['sellerRequestStatus']) ??
          (_readString(map['status']) == 'pending' &&
                  _readString(map['role']) == 'seller'
              ? 'pending'
              : 'none'),
      language: _readString(map['language']) ?? 'ar',
      themeMode: _readString(map['themeMode']) ?? 'light',
      createdAt: (map['createdAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'status': status,
      'isApproved': isApproved,
      'sellerRequestStatus': sellerRequestStatus,
      'language': language,
      'themeMode': themeMode,
      'createdAt': createdAt,
    };
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? status,
    bool? isApproved,
    String? sellerRequestStatus,
    String? language,
    String? themeMode,
    Timestamp? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      isApproved: isApproved ?? this.isApproved,
      sellerRequestStatus: sellerRequestStatus ?? this.sellerRequestStatus,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      createdAt: createdAt ?? this.createdAt,
    );
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

  static String _statusFromMap(Map<String, dynamic> map) {
    final raw = _readString(map['status']);
    if (raw != null && raw.isNotEmpty) return raw;
    final role = _readString(map['role']);
    final approved = _readBool(map['isApproved']);
    if (role == 'seller' && !approved) return 'pending';
    return approved ? 'approved' : 'pending';
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }
}
