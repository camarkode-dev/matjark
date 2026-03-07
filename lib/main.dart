import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/role_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/customer/main_screen.dart';
import 'screens/customer/categories_screen.dart';
import 'screens/customer/settings_screen.dart';
import 'screens/customer/order_tracking_screen.dart';
import 'screens/customer/seller_center_screen.dart';
import 'screens/customer/notifications_screen.dart';
import 'screens/seller/seller_dashboard.dart';
import 'screens/seller/seller_waiting_approval_screen.dart';
import 'screens/supplier/supplier_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'core/firebase_status.dart' as fs;
import 'widgets/role_guard.dart';
import 'models/user_model.dart';

const _supportedLocales = <Locale>[Locale('ar'), Locale('en')];
const _fallbackLocale = Locale('ar');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  var firebaseInitialized = false;

  // Initialize Firebase safely and allow app boot even if initialization fails.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kIsWeb) {
      _validateFirebaseWebConfig();
      final auth = firebase_auth.FirebaseAuth.instance;
      await auth.setPersistence(firebase_auth.Persistence.LOCAL);
      try {
        await auth.initializeRecaptchaConfig();
      } catch (error) {
        debugPrint(
          '[Firebase Auth] reCAPTCHA config warmup skipped. Confirm the web app domain is authorized and reCAPTCHA is enabled in Firebase Authentication. Details: $error',
        );
      }
      try {
        await auth.getRedirectResult();
      } catch (error) {
        debugPrint('[Firebase Auth] redirect result check skipped: $error');
      }
    }
    firebaseInitialized = true;
    debugPrint('[Firebase] initialized successfully.');
  } catch (e, stackTrace) {
    debugPrint('[Firebase] initialization failed: $e');
    debugPrint('[Firebase] stacktrace: $stackTrace');
    debugPrint('[Firebase] Check Firebase config via: flutterfire configure');
  }
  fs.setFirebaseAvailable(firebaseInitialized);

  runApp(
    EasyLocalization(
      supportedLocales: _supportedLocales,
      path: 'assets/translations',
      fallbackLocale: _fallbackLocale,
      startLocale: _fallbackLocale,
      saveLocale: true,
      child: const MyApp(),
    ),
  );
}

void _validateFirebaseWebConfig() {
  const options = DefaultFirebaseOptions.web;
  final missing = <String>[];
  if (options.apiKey.isEmpty) missing.add('apiKey');
  if ((options.authDomain ?? '').isEmpty) missing.add('authDomain');
  if (options.projectId.isEmpty) missing.add('projectId');
  if (options.appId.isEmpty) missing.add('appId');
  if (missing.isNotEmpty) {
    debugPrint(
      '[Firebase Web Config] Missing required fields: ${missing.join(', ')}',
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth state management
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // Theme management
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()..loadSavedThemeMode(),
        ),

        // Role-based routing, synced with AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, RoleProvider>(
          create: (_) => RoleProvider(),
          update: (_, authProvider, previousRoleProvider) {
            final roleProvider = previousRoleProvider ?? RoleProvider();
            roleProvider.updateFromUserRole(authProvider.currentUser?.role);
            return roleProvider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final locale = context.locale;
          final isArabic = locale.languageCode == 'ar';

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppStrings.appTitle,
            locale: locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            localeResolutionCallback: (deviceLocale, supportedLocales) {
              if (deviceLocale == null) return _fallbackLocale;
              for (final supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == deviceLocale.languageCode) {
                  return supportedLocale;
                }
              }
              return _fallbackLocale;
            },
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/forgot-password': (_) => const ForgotPasswordScreen(),
              '/otp-login': (_) => const OtpVerificationScreen(),
              '/customer': (_) => const RoleGuard(
                    allowedRoles: {UserRole.customer, UserRole.seller},
                    child: CustomerMainScreen(),
                  ),
              '/customer/categories': (_) => const RoleGuard(
                    allowedRoles: {UserRole.customer, UserRole.seller},
                    child: CategoriesScreen(),
                  ),
              '/customer/cart': (_) => const RoleGuard(
                    allowedRoles: {UserRole.customer, UserRole.seller},
                    child: CustomerMainScreen(initialIndex: 1),
                  ),
              '/customer/orders': (_) => const RoleGuard(
                    allowedRoles: {UserRole.customer, UserRole.seller},
                    child: CustomerMainScreen(initialIndex: 2),
                  ),
              '/customer/favorites': (_) => const RoleGuard(
                    allowedRoles: {UserRole.customer, UserRole.seller},
                    child: CustomerMainScreen(initialIndex: 3),
                  ),
              '/customer/profile': (_) => const RoleGuard(
                    allowedRoles: {UserRole.customer, UserRole.seller},
                    child: CustomerMainScreen(initialIndex: 4),
                  ),
              '/customer/settings': (_) => const RoleGuard(
                    allowedRoles: {UserRole.customer, UserRole.seller},
                    child: SettingsScreen(),
                  ),
              '/customer/tracking': (_) => const RoleGuard(
                    allowedRoles: {UserRole.customer, UserRole.seller},
                    child: OrderTrackingScreen(),
                  ),
              '/customer/seller-center': (_) => const RoleGuard(
                    allowedRoles: {
                      UserRole.customer,
                      UserRole.seller,
                      UserRole.admin,
                    },
                    child: SellerCenterScreen(),
                  ),
              '/customer/notifications': (_) => const RoleGuard(
                    allowedRoles: {
                      UserRole.customer,
                      UserRole.seller,
                      UserRole.admin,
                    },
                    child: NotificationsScreen(),
                  ),
              '/seller': (_) => const RoleGuard(
                    allowedRoles: {UserRole.seller},
                    child: SellerDashboard(),
                  ),
              '/seller/waiting': (_) => const RoleGuard(
                    allowedRoles: {UserRole.seller, UserRole.customer},
                    child: SellerWaitingApprovalScreen(),
                  ),
              '/supplier': (_) => const RoleGuard(
                    allowedRoles: {UserRole.supplier},
                    child: SupplierDashboard(),
                  ),
              '/admin': (_) => const RoleGuard(
                    allowedRoles: {UserRole.admin},
                    child: AdminDashboard(),
                  ),
            },
            builder: (context, child) {
              return Directionality(
                textDirection:
                    isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
