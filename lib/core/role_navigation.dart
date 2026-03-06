import 'constants.dart';
import '../models/user_model.dart';

String routeForRole(UserRole? role) {
  switch (role) {
    case UserRole.customer:
      return '/customer';
    case UserRole.seller:
      return '/seller';
    case UserRole.supplier:
      return '/supplier';
    case UserRole.admin:
      return '/admin';
    case UserRole.guest:
    case null:
      return '/login';
  }
}

String routeForUser(AppUser? user) {
  if (user == null) return '/login';
  final email = (user.email ?? '').toLowerCase();
  if (email.isNotEmpty && email == AppStrings.adminEmail.toLowerCase()) {
    return '/admin';
  }

  switch (user.role) {
    case UserRole.customer:
      return '/customer';
    case UserRole.seller:
      return user.isApproved ? '/seller' : '/seller/waiting';
    case UserRole.admin:
      return '/admin';
    case UserRole.supplier:
      return '/supplier';
    case UserRole.guest:
      return '/login';
  }
}
