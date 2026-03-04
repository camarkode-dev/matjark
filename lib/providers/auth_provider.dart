import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/auth_result.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../core/firebase_status.dart' as fs;

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  AuthProvider() {
    if (fs.firebaseAvailable) {
      _authSub = _authService.authStateChanges.listen(_onAuthChanged);
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    _userDocSub?.cancel();
    if (user == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }
    // listen to user document for real-time updates
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      if (snap.exists) {
        _currentUser = AppUser.fromMap(snap.data()!);
      } else {
        // document not found; create minimal record
        _currentUser = AppUser(
            uid: user.uid,
            email: user.email,
            name: user.displayName,
            phone: user.phoneNumber,
            role: UserRole.customer,
            isApproved: true,
            language: 'ar',
            createdAt: Timestamp.now());
      }
      notifyListeners();
    });
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// Register with email and password
  Future<Result<void, AuthFailure>> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    return _authService.registerWithEmail(email: email, password: password, name: name, role: role);
  }

  /// Sign in with email
  Future<Result<void, AuthFailure>> signInWithEmail(String email, String password) async {
    return _authService.signInWithEmail(email, password);
  }

  /// Send OTP to phone
  Future<Result<void, AuthFailure>> sendPhoneOTP(String phoneNumber) async {
    return _authService.sendPhoneOTP(phoneNumber);
  }

  /// Verify phone OTP
  Future<Result<void, AuthFailure>> verifyPhoneOTP(String code) async {
    return _authService.verifyPhoneOTP(code);
  }

  /// Google Sign-In
  Future<Result<void, AuthFailure>> signInWithGoogle({UserRole role = UserRole.customer}) async {
    return _authService.signInWithGoogle(role: role);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
