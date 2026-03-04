import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/theme.dart';
import '../../core/auth_result.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../customer/main_screen.dart';
import 'register_screen.dart';

/// Production-ready login screen with Email/Phone toggle
/// Supports: Web, Android, iOS with smooth animations and professional UX
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // Animation controller for fade-in entrance effect
  late AnimationController _animController;

  // Tab state: 0 = Email, 1 = Phone
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Trigger entrance animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Navigate user to appropriate dashboard based on role
  void _navigateToHome(UserRole? role) {
    if (!mounted) return;

    final destination = switch (role) {
      UserRole.customer => const CustomerMainScreen(),
      UserRole.seller => const SizedBox(), // Replace with SellerDashboard()
      UserRole.supplier => const SizedBox(), // Replace with SupplierDashboard()
      UserRole.admin => const SizedBox(), // Replace with AdminDashboard()
      UserRole.guest || null => const SizedBox(),
    };

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Main scrollable content
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: FadeTransition(
                opacity: _animController.drive(CurveTween(curve: Curves.easeIn)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppTheme.spacing24),

                    // Logo section
                    Center(
                      child: SizedBox(
                        height: 96,
                        width: 96,
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => CircleAvatar(
                            radius: 48,
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              'M',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),

                    // Welcome message
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      'Choose your login method',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacing24),

                    // Email / Phone toggle buttons
                    _buildTabToggle(),
                    const SizedBox(height: AppTheme.spacing24),

                    // Animated form switcher between email and phone
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _selectedTab == 0
                          ? _EmailLoginForm(onSuccess: _navigateToHome)
                          : _PhoneLoginForm(onSuccess: _navigateToHome),
                    ),
                    const SizedBox(height: AppTheme.spacing24),

                    // Divider with "or" text
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppTheme.divider,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing12),
                          child: Text(
                            'or'.tr(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppTheme.divider,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing16),

                    // Google Sign-In button
                    _GoogleLoginButton(onSuccess: _navigateToHome),
                    const SizedBox(height: AppTheme.spacing24),

                    // Register link
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            TextSpan(text: "don't_have_account".tr()),
                            TextSpan(
                              text: ' ${"register".tr()}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Email/Phone tab toggle with smooth selection animation
  Widget _buildTabToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Email tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton - 4),
                ),
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.email_outlined,
                      color: _selectedTab == 0 ? Colors.white : AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Email',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _selectedTab == 0 ? Colors.white : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Phone tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton - 4),
                ),
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      color: _selectedTab == 1 ? Colors.white : AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Phone',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _selectedTab == 1 ? Colors.white : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// Email Login Form
// ============================================
class _EmailLoginForm extends StatefulWidget {
  final Function(UserRole?) onSuccess;

  const _EmailLoginForm({required this.onSuccess});

  @override
  State<_EmailLoginForm> createState() => _EmailLoginFormState();
}

class _EmailLoginFormState extends State<_EmailLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _loading = false;
  bool _obscurePassword = true;
  AuthFailure? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Email validation using regex
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'email_invalid'.tr();
    }
    // RFC 5322 simplified regex for email validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return !emailRegex.hasMatch(value) ? 'email_invalid'.tr() : null;
  }

  /// Perform email/password sign-in
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Handle result using chainable pattern
      if (mounted) {
        result
            .onSuccess((_) {
              widget.onSuccess(authProvider.currentUser?.role);
            })
            .onFailure((failure) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(failure.message)),
                );
                setState(() => _error = failure);
              }
            });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email field with proper keyboardType placement
          TextFormField(
            controller: _emailController,
            enabled: !_loading,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress, // ✓ Correct placement (not in InputDecoration)
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'email'.tr(),
              prefixIcon: const Icon(Icons.email_outlined),
              hintText: 'user@example.com',
            ),
            validator: _validateEmail,
            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Password field
          TextFormField(
            controller: _passwordController,
            enabled: !_loading,
            focusNode: _passwordFocus,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'password'.tr(),
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'password_min_6'.tr() : null,
            onFieldSubmitted: (_) => _login(),
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Error message display
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Text(
                _error!.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.error,
                    ),
              ),
            ),
          if (_error != null) const SizedBox(height: AppTheme.spacing16),

          // Login button
          ElevatedButton.icon(
            onPressed: _loading ? null : _login,
            icon: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                : const Icon(Icons.login),
            label: Text(_loading ? 'signing_in'.tr() : 'login'.tr()),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// Phone OTP Login Form
// ============================================
class _PhoneLoginForm extends StatefulWidget {
  final Function(UserRole?) onSuccess;

  const _PhoneLoginForm({required this.onSuccess});

  @override
  State<_PhoneLoginForm> createState() => _PhoneLoginFormState();
}

class _PhoneLoginFormState extends State<_PhoneLoginForm> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _loading = false;
  bool _otpSent = false;
  int _resendCountdown = 0;
  AuthFailure? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// Send OTP to phone number
  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = AuthFailureInvalidPhoneNumber());
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.sendPhoneOTP(phone);

      if (mounted) {
        result
            .onSuccess((_) {
              setState(() {
                _otpSent = true;
                _resendCountdown = 60;
              });
              _startResendTimer();
            })
            .onFailure((failure) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(failure.message)),
                );
                setState(() => _error = failure);
              }
            });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Verify OTP code and sign in
  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      setState(() => _error = AuthFailureInvalidVerificationCode());
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.verifyPhoneOTP(otp);

      if (mounted) {
        result
            .onSuccess((_) {
              widget.onSuccess(authProvider.currentUser?.role);
            })
            .onFailure((failure) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(failure.message)),
                );
                setState(() => _error = failure);
              }
            });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Recursive countdown timer for OTP resend
  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() => _resendCountdown--);
        _startResendTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_otpSent) ...[
          // Phase 1: Enter phone number
          TextFormField(
            controller: _phoneController,
            enabled: !_loading,
            keyboardType: TextInputType.phone, // ✓ Correct placement
            decoration: InputDecoration(
              labelText: 'phone_number'.tr(),
              prefixIcon: const Icon(Icons.phone_outlined),
              hintText: '+1 (555) 000-0000',
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Text(
                _error!.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.error,
                    ),
              ),
            ),
          if (_error != null) const SizedBox(height: AppTheme.spacing16),
          ElevatedButton.icon(
            onPressed: _loading ? null : _sendOTP,
            icon: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(_loading ? 'sending'.tr() : 'send_otp'.tr()),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
            ),
          ),
        ] else ...[
          // Phase 2: Enter OTP
          Text(
            'We sent a code to ${_phoneController.text}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing16),
          TextFormField(
            controller: _otpController,
            enabled: !_loading,
            keyboardType: TextInputType.number, // ✓ Correct placement
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'otp_code'.tr(),
              prefixIcon: const Icon(Icons.key_outlined),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Text(
                _error!.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.error,
                    ),
              ),
            ),
          if (_error != null) const SizedBox(height: AppTheme.spacing16),
          ElevatedButton.icon(
            onPressed: _loading ? null : _verifyOTP,
            icon: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                : const Icon(Icons.verified_outlined),
            label: Text(_loading ? 'verifying'.tr() : 'verify_otp'.tr()),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          if (_resendCountdown > 0)
            Text(
              'Resend code in $_resendCountdown seconds',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            )
          else
            TextButton(
              onPressed: _loading ? null : () => setState(() => _otpSent = false),
              child: Text('resend_code'.tr()),
            ),
        ],
      ],
    );
  }
}

// ============================================
// Google Sign-In Button
// ============================================
class _GoogleLoginButton extends StatefulWidget {
  final Function(UserRole?) onSuccess;

  const _GoogleLoginButton({required this.onSuccess});

  @override
  State<_GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<_GoogleLoginButton> {
  bool _loading = false;

  /// Sign in with Google account
  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.signInWithGoogle();

      if (mounted) {
        result
            .onSuccess((_) {
              widget.onSuccess(authProvider.currentUser?.role);
            })
            .onFailure((failure) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(failure.message)),
                );
              }
            });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _loginWithGoogle,
      icon: const Icon(Icons.login_rounded),
      label: Text('sign_in_with_google'.tr()),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
      ),
    );
  }
}
