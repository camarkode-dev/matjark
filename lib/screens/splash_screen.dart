import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// role_provider import not required here
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import 'auth/login_screen.dart';
import 'customer/main_screen.dart';
import 'seller/seller_dashboard.dart';
import 'supplier/supplier_dashboard.dart';
import 'admin/admin_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    final authProvider = context.read<AuthProvider>();
    Widget next = const SizedBox.shrink();
    if (!authProvider.isSignedIn || authProvider.currentUser == null) {
      next = const LoginScreen();
    } else {
      final role = authProvider.currentUser!.role;
      switch (role) {
        case UserRole.customer:
          next = const CustomerMainScreen();
          break;
        case UserRole.seller:
          next = const SellerDashboard();
          break;
        case UserRole.supplier:
          next = const SupplierDashboard();
          break;
        case UserRole.admin:
          next = const AdminDashboard();
          break;
        case UserRole.guest:
          next = const LoginScreen();
          break;
      }
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'متجرك',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
    );
  }
}
