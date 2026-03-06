import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matjark/core/role_navigation.dart';
import 'package:matjark/models/user_model.dart';

AppUser _user({required UserRole role, required bool approved}) {
  return AppUser(
    uid: 'u1',
    name: 'Demo',
    email: 'demo@example.com',
    role: role,
    status: approved ? 'approved' : 'pending',
    isApproved: approved,
    language: 'ar',
    themeMode: 'light',
    createdAt: Timestamp.now(),
  );
}

void main() {
  group('Role routing validation', () {
    test('customer goes to customer app', () {
      expect(
        routeForUser(_user(role: UserRole.customer, approved: true)),
        '/customer',
      );
    });

    test('approved seller goes to seller dashboard', () {
      expect(
        routeForUser(_user(role: UserRole.seller, approved: true)),
        '/seller',
      );
    });

    test('pending seller goes to waiting approval page', () {
      expect(
        routeForUser(_user(role: UserRole.seller, approved: false)),
        '/seller/waiting',
      );
    });

    test('admin goes to admin dashboard', () {
      expect(
        routeForUser(_user(role: UserRole.admin, approved: true)),
        '/admin',
      );
    });
  });
}
