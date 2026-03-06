import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  bool _loading = false;
  bool _codeSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _normalizeEgyptPhone(String value) {
    final raw = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (raw.startsWith('+20')) return raw;
    if (raw.startsWith('0020')) return '+${raw.substring(2)}';
    if (raw.startsWith('20')) return '+$raw';
    if (raw.startsWith('01') && raw.length == 11) {
      return '+20${raw.substring(1)}';
    }
    if (raw.startsWith('1') && raw.length == 10) {
      return '+20$raw';
    }
    return raw;
  }

  String get _otpCode => _codeControllers.map((c) => c.text).join();

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    final phone = _normalizeEgyptPhone(_phoneController.text.trim());
    if (email.isEmpty || phone.isEmpty || !phone.startsWith('+20')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.locale.languageCode == 'ar'
                ? 'أدخل البريد والهاتف المصري بشكل صحيح.'
                : 'Enter a valid email and Egyptian phone number.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await context.read<AuthProvider>().sendPhoneOTP(phone);
      if (!mounted) return;
      result.onSuccess((_) {
        setState(() => _codeSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.locale.languageCode == 'ar'
                  ? 'تم إرسال رمز التحقق.'
                  : 'Verification code sent.',
            ),
          ),
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

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final phone = _normalizeEgyptPhone(_phoneController.text.trim());
    final newPassword = _passwordController.text;
    if (_otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.verify_otp'.tr())),
      );
      return;
    }
    if (newPassword.length < 6 || newPassword != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.locale.languageCode == 'ar'
                ? 'تحقق من كلمة المرور الجديدة وتأكيدها.'
                : 'Check the new password and confirmation.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final verifyResult = await auth.verifyPhoneOTP(_otpCode);
      if (!mounted) return;
      final verifyFailure = verifyResult.getErrorOrNull();
      if (verifyFailure != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(verifyFailure.message.tr())));
        return;
      }

      final resetResult = await auth.resetPasswordWithPhoneOtp(
        email: email,
        phone: phone,
        newPassword: newPassword,
      );
      if (!mounted) return;
      final resetFailure = resetResult.getErrorOrNull();
      if (resetFailure != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(resetFailure.message.tr())));
        return;
      }

      await auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.locale.languageCode == 'ar'
                ? 'تم تغيير كلمة المرور. سجل الدخول من جديد.'
                : 'Password updated. Please sign in again.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _otpField(int index) {
    return SizedBox(
      width: 42,
      child: TextField(
        controller: _codeControllers[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: const InputDecoration(counterText: ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(width: 220, height: 130)),
              const SizedBox(height: 12),
              Text(
                isAr ? 'استعادة كلمة المرور' : 'Reset Password',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'أدخل البريد والهاتف المصري، ثم تحقق برمز OTP وحدد كلمة مرور جديدة.'
                    : 'Enter your email and Egyptian phone, verify by OTP, then set a new password.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.secondaryText(context)),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'email'.tr(),
                  hintText: 'name@example.com',
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
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
              ),
              const SizedBox(height: 16),
              if (!_codeSent)
                ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isAr ? 'إرسال OTP' : 'Send OTP'),
                ),
              if (_codeSent) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, _otpField),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isAr ? 'كلمة المرور الجديدة' : 'New password',
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        isAr ? 'تأكيد كلمة المرور' : 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_person_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _resetPassword,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isAr ? 'تغيير كلمة المرور' : 'Update password'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
