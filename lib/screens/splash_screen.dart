import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/firebase_status.dart' as fs;
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 300), _navigate);
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    final authProvider = context.read<AuthProvider>();
    final hasFirebaseSession = fs.firebaseAvailable
        ? firebase_auth.FirebaseAuth.instance.currentUser != null
        : false;

    // Give auth provider a short time to hydrate profile from Firestore.
    if (authProvider.currentUser == null &&
        hasFirebaseSession &&
        _retryCount < 5) {
      _retryCount += 1;
      Timer(const Duration(milliseconds: 250), _navigate);
      return;
    }

    if (!authProvider.isSignedIn || authProvider.currentUser == null) {
      _navigated = true;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    final user = authProvider.currentUser!;
    if (user.language == 'en' && context.locale.languageCode != 'en') {
      context.setLocale(const Locale('en'));
    } else if (user.language == 'ar' && context.locale.languageCode != 'ar') {
      context.setLocale(const Locale('ar'));
    }
    final themeProvider = context.read<ThemeProvider>();
    if (user.themeMode == 'dark') {
      themeProvider.setThemeMode(ThemeMode.dark);
    } else if (user.themeMode == 'system') {
      themeProvider.setThemeMode(ThemeMode.system);
    } else {
      themeProvider.setThemeMode(ThemeMode.light);
    }

    final targetRoute = authProvider.landingRoute;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'app.title'.tr(),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
    );
  }
}
