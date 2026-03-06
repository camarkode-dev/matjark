import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = false;
  UserRole _selectedRole = UserRole.customer;

  int _passwordStrengthScore(String password) {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    return score;
  }

  String _passwordStrengthLabel(BuildContext context, int score) {
    final isAr = context.locale.languageCode == 'ar';
    if (score <= 1) {
      return isAr ? 'ضعيفة' : 'Weak';
    }
    if (score == 2) {
      return isAr ? 'متوسطة' : 'Fair';
    }
    if (score == 3) {
      return isAr ? 'جيدة' : 'Good';
    }
    return isAr ? 'قوية' : 'Strong';
  }

  Color _passwordStrengthColor(int score) {
    if (score <= 1) return const Color(0xFFFF5D73);
    if (score == 2) return const Color(0xFFFFC857);
    if (score == 3) return const Color(0xFF4C8DFF);
    return const Color(0xFF2ED573);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.locale.languageCode == 'ar'
                ? 'الرجاء الموافقة على الشروط وسياسة الخصوصية.'
                : 'Please agree to terms and privacy policy.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final result = await auth.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
      );
      if (!mounted) return;

      result.onSuccess((_) async {
        await auth.waitForUserData();
        if (!mounted) return;
        await _showPostRegistrationDialog();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          auth.landingRoute,
          (_) => false,
        );
      }).onFailure((failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message.tr())));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final result = await auth.signInWithGoogle(role: _selectedRole);
      if (!mounted) return;
      result.onSuccess((_) async {
        // Wait for user data to be loaded from Firestore
        await auth.waitForUserData();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          auth.landingRoute,
          (_) => false,
        );
      }).onFailure((failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message.tr())));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPostRegistrationDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('auth.account_created_success'.tr()),
          content: Text('auth.check_email_to_verify'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common.submit'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                await _openEmailApp();
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Text('auth.open_mail_app'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEmailApp() async {
    final email = _emailController.text.trim();
    final candidates = <Uri>[
      if (!kIsWeb) Uri.parse('message://'),
      if (!kIsWeb) Uri.parse('googlegmail://'),
      if (!kIsWeb) Uri.parse('ms-outlook://'),
      Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: email.isEmpty ? null : {'subject': 'Verify account'},
      ),
      if (kIsWeb) Uri.parse('https://mail.google.com/mail/u/0/#inbox'),
    ];

    for (final uri in candidates) {
      try {
        final launched = await launchUrl(
          uri,
          mode: uri.scheme == 'http' || uri.scheme == 'https'
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );
        if (launched) return;
      } catch (_) {
        // Try the next available mail target.
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.locale.languageCode == 'ar'
              ? 'تعذر فتح تطبيق البريد على هذا الجهاز.'
              : 'Unable to open a mail app on this device.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strengthScore = _passwordStrengthScore(_passwordController.text);
    final strengthColor = _passwordStrengthColor(strengthScore);
    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        context.locale.languageCode == 'ar'
                            ? 'تسجيل الدخول'
                            : 'Login',
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Center(
                  child: AppLogo(width: 220, height: 130),
                ),
                const SizedBox(height: 14),
                Text(
                  context.locale.languageCode == 'ar'
                      ? 'إنشاء حساب جديد'
                      : 'Create New Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.locale.languageCode == 'ar'
                      ? 'انضم إلى عائلة متجرك اليوم'
                      : 'Join Matjark community today',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.secondaryText(context),
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.panel(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.locale.languageCode == 'ar'
                            ? 'بيانات الحساب'
                            : 'Account Details',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'name'.tr(),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'name_required'.tr()
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'email'.tr(),
                          hintText: 'name@example.com',
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'email_invalid'.tr();
                          }
                          final valid = RegExp(
                            r'^[^@]+@[^@]+\.[^@]+$',
                          ).hasMatch(value.trim());
                          return valid ? null : 'email_invalid'.tr();
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'phone_number'.tr(),
                          hintText: '+20 10 1234 5678',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'phone_required'.tr();
                          }
                          if (value.trim().length < 9) {
                            return 'phone_invalid'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'password'.tr(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'password_min_6'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: strengthScore / 4,
                                minHeight: 6,
                                backgroundColor: AppTheme.panelSoft(context),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  strengthColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _passwordStrengthLabel(context, strengthScore),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: strengthColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.locale.languageCode == 'ar'
                            ? 'يفضّل استخدام 8 أحرف على الأقل مع أرقام وحروف كبيرة وصغيرة.'
                            : 'Use at least 8 characters with upper/lower letters and numbers.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.secondaryText(context),
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'confirm_password'.tr(),
                          prefixIcon: const Icon(Icons.lock_person_outlined),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              );
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value != _passwordController.text
                            ? 'passwords_dont_match'.tr()
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleChoiceChip(
                              label: 'roles.customer'.tr(),
                              icon: Icons.person_outline,
                              selected: _selectedRole == UserRole.customer,
                              onTap: () {
                                setState(
                                  () => _selectedRole = UserRole.customer,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RoleChoiceChip(
                              label: 'roles.seller'.tr(),
                              icon: Icons.storefront_outlined,
                              selected: _selectedRole == UserRole.seller,
                              onTap: () {
                                setState(
                                  () => _selectedRole = UserRole.seller,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreeTerms,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          context.locale.languageCode == 'ar'
                              ? 'أوافق على سياسة الخصوصية وشروط الخدمة'
                              : 'I agree to privacy policy and terms',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onChanged: (value) {
                          setState(() => _agreeTerms = value ?? false);
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0A1430),
                                ),
                              )
                            : Text(
                                context.locale.languageCode == 'ar'
                                    ? 'إنشاء الحساب'
                                    : 'Create Account',
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        context.locale.languageCode == 'ar'
                            ? 'أو سجل من خلال'
                            : 'or continue with',
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/otp-login'),
                        icon: const Icon(Icons.phone_iphone_outlined),
                        label: const Text('OTP'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _continueWithGoogle,
                        icon: const Icon(Icons.g_mobiledata_rounded),
                        label: const Text('Google'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    'already_have_account'.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.16)
              : AppTheme.panelSoft(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? AppTheme.primary : null),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? AppTheme.primary : null,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
