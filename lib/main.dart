import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/role_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/customer/main_screen.dart';
import 'screens/seller/seller_dashboard.dart';
import 'screens/supplier/supplier_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'core/firebase_status.dart' as fs;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  try {
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    fs.setFirebaseAvailable(true);
    debugPrint('✓ Firebase initialized successfully on ${DefaultFirebaseOptions.currentPlatform.projectId}');
  } catch (e) {
    debugPrint('✗ Firebase initialization failed: $e');
    debugPrint('  [INFO] Run: flutterfire configure');
    fs.setFirebaseAvailable(false);
    // App continues gracefully - UI works but Firebase calls will be guarded
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      child: const MyApp(),
    ),
  );
}

/// Main application widget with complete provider setup and routing
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Primary auth provider - manages user authentication state
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // Role-based routing provider - syncs with AuthProvider
        // Updates whenever AuthProvider.currentUser changes
        ChangeNotifierProxyProvider<AuthProvider, RoleProvider>(
          create: (_) => RoleProvider(),
          update: (_, authProvider, roleProv) {
            roleProv ??= RoleProvider();
            roleProv.updateFromUserRole(authProvider.currentUser?.role);
            return roleProv;
          },
        ),
      ],
      child: MaterialApp(
        // Disable debug banner in production
        debugShowCheckedModeBanner: false,

        // App title for task switcher / system UI
        title: AppStrings.appTitle,

        // Easy Localization integration
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,

        // Theme configuration (Material 3 compliant, supports Light/Dark)
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light, // Change to ThemeMode.system for device preference

        // Initial home screen (splash before auth check)
        home: const SplashScreen(),

        // Named routes for all role-based dashboards
        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/customer': (_) => const CustomerMainScreen(),
          '/seller': (_) => const SellerDashboard(),
          '/supplier': (_) => const SupplierDashboard(),
          '/admin': (_) => const AdminDashboard(),
        },
      ),
    );
  }
}
