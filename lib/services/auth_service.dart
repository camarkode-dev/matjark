import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' as functions;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/auth_result.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleSignIn? _googleSignIn;

  /// Returns stream of Firebase [User] provided by firebase_auth.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Phone verification state
  String? _verificationId;

  /// Creates or updates a Firestore user document from Firebase user
  Future<void> _updateFirestoreUser(
    User user, {
    UserRole role = UserRole.customer,
    String? name,
    String? phone,
  }) async {
    try {
      final doc = _firestore.collection('users').doc(user.uid);
      final snapshot = await doc.get();
      if (snapshot.exists) {
        final data = snapshot.data() ?? {};
        final updates = <String, dynamic>{
          'email': user.email,
          'name': name ?? user.displayName,
          'phone': phone ?? user.phoneNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (data['sellerRequestStatus'] == null) {
          updates['sellerRequestStatus'] = 'none';
        }
        if (data['status'] == null) {
          updates['status'] =
              (data['isApproved'] == true) ? 'approved' : 'pending';
        }
        await doc.update(updates);
      } else {
        final approved = role == UserRole.customer;
        await doc.set({
          'uid': user.uid,
          'email': user.email,
          'name': name ?? user.displayName,
          'phone': phone ?? user.phoneNumber,
          'role': role.name,
          'status': approved ? 'approved' : 'pending',
          'isApproved': approved,
          'sellerRequestStatus': 'none',
          'language': 'ar',
          'themeMode': 'light',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Log error only - auth succeeded, Firestore update is secondary
      debugPrint('Error updating Firestore user: $e');
    }
  }

  /// Sign in with email and password
  Future<Result<void, AuthFailure>> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final cred = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      await cred.user!.getIdToken(true);
      await _updateFirestoreUser(cred.user!);
      return const Success(null);
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
    required String phone,
    required UserRole role,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final cred = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      await cred.user!.updateDisplayName(name);
      await cred.user!.sendEmailVerification();
      await _updateFirestoreUser(
        cred.user!,
        role: role,
        name: name,
        phone: phone,
      );
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_mapAuthException(e));
    } catch (e) {
      return Failure(AuthFailureUnknown(e.toString()));
    }
  }

  /// Send OTP to phone number (returns Result with void on success)
  Future<Result<void, AuthFailure>> sendPhoneOTP(String phoneNumber) async {
    final completer = Completer<Result<void, AuthFailure>>();

    try {
      if (kIsWeb) {
        final host = Uri.base.host.toLowerCase();
        if (host == 'localhost' || host == '127.0.0.1') {
          return Failure(
            AuthFailureUnknown('auth.errors.phone_auth_localhost_unsupported'),
          );
        }
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (rare on web)
          await _signInWithPhoneCredential(credential);
          if (!completer.isCompleted) {
            completer.complete(const Success(null));
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
            completer.complete(const Success(null));
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
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_mapPhoneException(e));
    } catch (e) {
      return Failure(AuthFailureUnknown(e.toString()));
    }
  }

  /// Internal method to sign in with phone credential
  Future<void> _signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    final cred = await _auth.signInWithCredential(credential);
    await _updateFirestoreUser(cred.user!);
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn?.signOut();
    _verificationId = null;
  }

  /// Google Sign-In
  Future<Result<void, AuthFailure>> signInWithGoogle({
    UserRole role = UserRole.customer,
  }) async {
    try {
      final UserCredential cred;
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile')
          ..setCustomParameters({
            'prompt': 'select_account',
          });
        cred = await _auth.signInWithPopup(provider);
      } else {
        final googleSignIn = _googleSignIn ??= GoogleSignIn(
          scopes: const ['email', 'profile'],
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          return Failure(
              AuthFailureUnknown('auth.errors.google_sign_in_cancelled'));
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final String? idToken = googleAuth.idToken;
        if (idToken == null) {
          return Failure(AuthFailureUnknown('auth.errors.google_auth_failed'));
        }

        final credential = GoogleAuthProvider.credential(idToken: idToken);
        cred = await _auth.signInWithCredential(credential);
      }

      await cred.user!.getIdToken(true);
      await _updateFirestoreUser(cred.user!, role: role);
      return const Success(null);
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('clientid not set')) {
        return Failure(AuthFailureGoogleClientIdMissing());
      }
      debugPrint('Google sign-in error: $e');
      return Failure(AuthFailureUnknown('auth.errors.unexpected'));
    }
  }

  /// Persist user language preference in Firestore profile.
  Future<Result<void, AuthFailure>> updateLanguagePreference(
    String language,
  ) async {
    try {
      if (language != 'ar' && language != 'en') {
        return Failure(AuthFailureUnknown('auth.errors.unsupported_language'));
      }

      final user = _auth.currentUser;
      if (user == null) {
        return Failure(AuthFailureUnknown('auth.errors.user_not_signed_in'));
      }

      await _firestore.collection('users').doc(user.uid).set({
        'language': language,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return const Success(null);
    } catch (e) {
      return Failure(AuthFailureUnknown(e.toString()));
    }
  }

  /// Send password reset email.
  Future<Result<void, AuthFailure>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_mapAuthException(e));
    } catch (e) {
      return Failure(AuthFailureUnknown(e.toString()));
    }
  }

  /// Send verification email for current user.
  Future<Result<void, AuthFailure>> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Failure(AuthFailureUnknown('auth.errors.user_not_signed_in'));
      }
      await user.sendEmailVerification();
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_mapAuthException(e));
    } catch (e) {
      return Failure(AuthFailureUnknown(e.toString()));
    }
  }

  /// Reload currently signed-in user from FirebaseAuth.
  Future<Result<void, AuthFailure>> reloadCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return const Success(null);
      await user.reload();
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_mapAuthException(e));
    } catch (e) {
      return Failure(AuthFailureUnknown(e.toString()));
    }
  }

  Future<Result<void, AuthFailure>> resetPasswordWithPhoneOtp({
    required String email,
    required String phone,
    required String newPassword,
  }) async {
    try {
      final callable = functions.FirebaseFunctions.instance.httpsCallable(
        'resetPasswordByPhoneOtp',
      );
      await callable.call({
        'email': email,
        'phone': phone,
        'newPassword': newPassword,
      });
      return const Success(null);
    } on functions.FirebaseFunctionsException catch (e) {
      return Failure(AuthFailureUnknown(e.message));
    } catch (e) {
      return Failure(AuthFailureUnknown(e.toString()));
    }
  }

  /// Map Firebase exceptions to AuthFailure
  AuthFailure _mapAuthException(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' => AuthFailureEmailNotFound(),
      'wrong-password' => AuthFailureWrongPassword(),
      'invalid-credential' => AuthFailureWrongPassword(),
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
      'operation-not-allowed' => AuthFailurePhoneSetupRequired(),
      'captcha-check-failed' => AuthFailureRecaptchaCheckFailed(),
      'invalid-app-credential' => AuthFailureRecaptchaCheckFailed(),
      _ => AuthFailurePhoneVerificationFailed(),
    };
  }
}
