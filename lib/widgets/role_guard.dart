import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/role_navigation.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';

class RoleGuard extends StatelessWidget {
  final Set<UserRole> allowedRoles;
  final Widget child;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final canAccessAsAdmin =
        auth.isAdmin && allowedRoles.contains(UserRole.admin);

    if (!auth.isSignedIn || user == null) {
      return const LoginScreen();
    }

    if (!allowedRoles.contains(user.role) && !canAccessAsAdmin) {
      final targetRoute = canAccessAsAdmin ? '/admin' : routeForUser(user);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil(targetRoute, (_) => false);
      });

      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return child;
  }
}
