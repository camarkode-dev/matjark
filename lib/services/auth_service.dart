import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/auth_result.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns stream of Firebase [User] provided by firebase_auth.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Phone verification state
  String? _verificationId;

  /// Creates or updates a Firestore user document from Firebase user
  Future<void> _updateFirestoreUser(User user, {UserRole role = UserRole.customer}) async {
    try {
      final doc = _firestore.collection('users').doc(user.uid);
      final snapshot = await doc.get();
      if (snapshot.exists) {
        await doc.update({'email': user.email, 'name': user.displayName, 'phone': user.phoneNumber});
      } else {
        await doc.set({
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName,
          'phone': user.phoneNumber,
          'role': role.name,
          'isApproved': role == UserRole.customer ? true : false,
          'language': 'ar',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Log error only - auth succeeded, Firestore update is secondary
      debugPrint('Error updating Firestore user: $e');
    }
  }

  /// Sign in with email and password
  Future<Result<void, AuthFailure>> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _updateFirestoreUser(cred.user!);
      return Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_mapAuthException(e));
    } catch (e) {
      return Failure(AuthFailureUnknown(e.toString()));
    }
  }

  /// Register with email and password
  Future<Result<void, AuthFailure>> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user!.updateDisplayName(name);
      await _updateFirestoreUser(cred.user!, role: role);
      return Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_mapAuthException(e));
    } catch (e) {
      return Failure(AuthFailureUnknown(e.toString()));
    }
  }

  /// Send OTP to phone number (returns Result<void, AuthFailure>)
  Future<Result<void, AuthFailure>> sendPhoneOTP(String phoneNumber) async {
    final completer = Completer<Result<void, AuthFailure>>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (rare on web)
          await _signInWithPhoneCredential(credential);
          if (!completer.isCompleted) {
            completer.complete(Success(null));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.complete(Failure(_mapPhoneException(e)));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete(Success(null));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      return Failure(AuthFailureNetwork(e.toString()));
    }

    return completer.future;
  }

  /// Verify OTP code
  Future<Result<void, AuthFailure>> verifyPhoneOTP(String code) async {
    try {
      if (_verificationId == null) {
        return Failure(AuthFailureInvalidVerificationCode());
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      await _signInWithPhoneCredential(credential);
      return Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_mapPhoneException(e));
    } catch (e) {
      return Failure(AuthFailureUnknown(e.toString()));
    }
  }

  /// Internal method to sign in with phone credential
  Future<void> _signInWithPhoneCredential(PhoneAuthCredential credential) async {
    final cred = await _auth.signInWithCredential(credential);
    await _updateFirestoreUser(cred.user!);
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn.instance.signOut();
    _verificationId = null;
  }

  /// Google Sign-In
  Future<Result<void, AuthFailure>> signInWithGoogle({UserRole role = UserRole.customer}) async {
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      await _updateFirestoreUser(cred.user!, role: role);
      return Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_mapAuthException(e));
    } catch (e) {
      return Failure(AuthFailureNetwork(e.toString()));
    }
  }

  /// Map Firebase exceptions to AuthFailure
  AuthFailure _mapAuthException(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' => AuthFailureEmailNotFound(),
      'wrong-password' => AuthFailureWrongPassword(),
      'invalid-email' => AuthFailureInvalidEmail(),
      'weak-password' => AuthFailureWeakPassword(),
      'email-already-in-use' => AuthFailureEmailInUse(),
      'user-disabled' => AuthFailureUserDisabled(),
      'too-many-requests' => AuthFailureTooManyRequests(),
      _ => AuthFailureUnknown(e.message),
    };
  }

  /// Map phone auth exceptions
  AuthFailure _mapPhoneException(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-phone-number' => AuthFailureInvalidPhoneNumber(),
      'too-many-requests' => AuthFailureTooManyRequests(),
      'invalid-verification-code' => AuthFailureInvalidVerificationCode(),
      _ => AuthFailurePhoneVerificationFailed(),
    };
  }
}
