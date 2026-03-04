import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

class RoleProvider extends ChangeNotifier {
  // underlying role state (uses model's UserRole)
  UserRole _role = UserRole.guest;

  UserRole get role => _role;

  RoleProvider();

  /// update role based on an [AppUser] role enum
  void updateFromUserRole(UserRole? r) {
    final newRole = _mapRole(r);
    if (newRole != _role) {
      _role = newRole;
      notifyListeners();
    }
  }

  UserRole _mapRole(UserRole? r) {
    if (r == null) return UserRole.guest;
    switch (r) {
      case UserRole.customer:
        return UserRole.customer;
      case UserRole.seller:
        return UserRole.seller;
      case UserRole.supplier:
        return UserRole.supplier;
      case UserRole.admin:
        return UserRole.admin;
      case UserRole.guest:
        return UserRole.guest;
    }
  }

  bool get isCustomer => _role == UserRole.customer;
  bool get isSeller => _role == UserRole.seller;
  bool get isSupplier => _role == UserRole.supplier;
  bool get isAdmin => _role == UserRole.admin;
}
