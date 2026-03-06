import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/auth_result.dart';
import '../core/constants.dart';
import '../core/role_navigation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../core/firebase_status.dart' as fs;

class AuthProvider extends ChangeNotifier {
  static const bool _allowAdminEmailFallback = bool.fromEnvironment(
    'MATJARK_ALLOW_ADMIN_EMAIL_FALLBACK',
    defaultValue: true,
  );

  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;
  String get landingRoute => _isAdmin ? '/admin' : routeForUser(_currentUser);

  AuthProvider() {
    if (fs.firebaseAvailable) {
      _authSub = _authService.authStateChanges.listen(_onAuthChanged);
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    _userDocSub?.cancel();
    if (user == null) {
      _currentUser = null;
      _isAdmin = false;
      notifyListeners();
      return;
    }

    _isAdmin = await _resolveAdminByClaimsOrEmail(user);
    // listen to user document for real-time updates
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      try {
        if (snap.exists) {
          final profile = AppUser.fromMap(snap.data()!, fallbackUid: user.uid);
          final derivedAdmin = _isAdmin ||
              _isAdminByEmail(user) ||
              profile.role == UserRole.admin;
          if (_isAdmin != derivedAdmin) {
            _isAdmin = derivedAdmin;
            if (_isAdmin) {
              unawaited(user.getIdToken(true));
            }
          }
          _currentUser = _normalizeUserRole(profile);
        } else {
          // document not found; create minimal record
          _currentUser = _fallbackUserForFirebaseUser(user);
        }
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('User profile parsing error: $error');
          debugPrint('$stackTrace');
        }
        _currentUser = _fallbackUserForFirebaseUser(user);
      }
      notifyListeners();
    }, onError: (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('User profile listener error: $error');
      }
      // Fallback profile to avoid breaking auth flow when Firestore rules
      // reject profile read in a given environment.
      _currentUser = _fallbackUserForFirebaseUser(user);
      notifyListeners();
    });
  }

  Future<bool> _resolveAdminByClaimsOrEmail(User user) async {
    try {
      final token = await user.getIdTokenResult();
      final claims = token.claims ?? const <String, dynamic>{};
      if (claims['admin'] == true) return true;
      if ((claims['role'] ?? '').toString() == 'admin') return true;
    } catch (_) {
      // Ignore token failures and fallback to email check.
    }
    if (!_allowAdminEmailFallback) {
      return false;
    }
    return _isAdminByEmail(user);
  }

  bool _isAdminByEmail(User user) {
    final email = (user.email ?? '').toLowerCase();
    return email.isNotEmpty && email == AppStrings.adminEmail.toLowerCase();
  }

  AppUser _fallbackUserForFirebaseUser(User user) {
    return _normalizeUserRole(AppUser(
      uid: user.uid,
      email: user.email,
      name: user.displayName,
      phone: user.phoneNumber,
      role: _isAdmin ? UserRole.admin : UserRole.customer,
      status: 'approved',
      isApproved: true,
      language: 'ar',
      themeMode: 'light',
      createdAt: Timestamp.now(),
    ));
  }

  AppUser _normalizeUserRole(AppUser user) {
    if (!_isAdmin) {
      // Firestore rules in this project rely on auth token claims for admin.
      // If the profile says "admin" without claims, downgrade to customer
      // to avoid navigating to unauthorized admin-only screens.
      if (user.role == UserRole.admin) {
        return user.copyWith(
          role: UserRole.customer,
          status: 'approved',
          isApproved: true,
        );
      }
      return user;
    }
    if (user.role == UserRole.admin && user.isApproved) return user;
    return user.copyWith(
      role: UserRole.admin,
      status: 'approved',
      isApproved: true,
    );
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// Wait for user data to be loaded from Firestore after authentication
  Future<AppUser?> waitForUserData(
      {int maxRetries = 30, int delayMs = 100}) async {
    int retries = 0;
    while (_currentUser == null && retries < maxRetries) {
      await Future.delayed(Duration(milliseconds: delayMs));
      retries++;
    }
    return _currentUser;
  }

  /// Register with email and password
  Future<Result<void, AuthFailure>> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    return _authService.registerWithEmail(
      email: email,
      password: password,
      name: name,
      phone: phone,
      role: role,
    );
  }

  /// Sign in with email
  Future<Result<void, AuthFailure>> signInWithEmail(
    String email,
    String password,
  ) async {
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
  Future<Result<void, AuthFailure>> signInWithGoogle({
    UserRole role = UserRole.customer,
  }) async {
    return _authService.signInWithGoogle(role: role);
  }

  /// Save preferred app language to the user profile.
  Future<Result<void, AuthFailure>> updateLanguagePreference(
    String language,
  ) async {
    return _authService.updateLanguagePreference(language);
  }

  /// Send password reset email.
  Future<Result<void, AuthFailure>> sendPasswordResetEmail(String email) async {
    return _authService.sendPasswordResetEmail(email);
  }

  /// Send email verification for current user.
  Future<Result<void, AuthFailure>> sendEmailVerification() async {
    return _authService.sendEmailVerification();
  }

  /// Reload current firebase user.
  Future<Result<void, AuthFailure>> reloadCurrentUser() async {
    return _authService.reloadCurrentUser();
  }

  Future<Result<void, AuthFailure>> resetPasswordWithPhoneOtp({
    required String email,
    required String phone,
    required String newPassword,
  }) async {
    return _authService.resetPasswordWithPhoneOtp(
      email: email,
      phone: phone,
      newPassword: newPassword,
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
