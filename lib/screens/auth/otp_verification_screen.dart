import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _phoneController = TextEditingController();
  final List<TextEditingController> _digitControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _digitFocusNodes = List.generate(6, (_) => FocusNode());

  bool _codeSent = false;
  bool _loading = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    for (final node in _digitFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _digitControllers.map((c) => c.text).join();

  void _clearOtpInput() {
    for (final controller in _digitControllers) {
      controller.clear();
    }
  }

  void _fillOtpFromInput(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    for (var i = 0; i < _digitControllers.length; i++) {
      _digitControllers[i].text = i < digits.length ? digits[i] : '';
    }
    if (digits.length >= _digitFocusNodes.length) {
      _digitFocusNodes.last.unfocus();
    } else {
      _digitFocusNodes[digits.length].requestFocus();
    }
    setState(() {});
  }

  void _onOtpDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 1) {
      _fillOtpFromInput(digits);
      return;
    }

    if (digits.isEmpty) {
      _digitControllers[index].clear();
      if (index > 0) {
        _digitFocusNodes[index - 1].requestFocus();
      }
      setState(() {});
      return;
    }

    _digitControllers[index].text = digits;
    _digitControllers[index].selection = const TextSelection.collapsed(
      offset: 1,
    );
    if (index < _digitFocusNodes.length - 1) {
      _digitFocusNodes[index + 1].requestFocus();
    } else {
      _digitFocusNodes[index].unfocus();
    }
    setState(() {});
  }

  Widget _buildOtpBox(BuildContext context, int index) {
    return SizedBox(
      width: 46,
      child: TextField(
        controller: _digitControllers[index],
        focusNode: _digitFocusNodes[index],
        enabled: _codeSent && !_loading,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        onChanged: (value) => _onOtpDigitChanged(index, value),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
          ),
        ),
      ),
    );
  }

  String _normalizePhone(String value) {
    final raw = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('00')) return '+${raw.substring(2)}';
    if (raw.startsWith('20')) {
      return '+$raw';
    }
    if (raw.startsWith('01') && raw.length == 11) {
      return '+20${raw.substring(1)}';
    }
    if (raw.startsWith('1') && raw.length == 10) {
      return '+20$raw';
    }
    if (raw.length >= 10 && raw.length <= 15) {
      return '+$raw';
    }
    return raw;
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _seconds = 55);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_seconds == 0) {
        timer.cancel();
      } else {
        setState(() => _seconds -= 1);
      }
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    final normalizedPhone = _normalizePhone(phone);
    if (phone.isEmpty ||
        !normalizedPhone.startsWith('+') ||
        normalizedPhone.length < 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('phone_invalid'.tr())));
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await context.read<AuthProvider>().sendPhoneOTP(
            normalizedPhone,
          );
      if (!mounted) return;
      result.onSuccess((_) {
        _clearOtpInput();
        setState(() => _codeSent = true);
        _startCountdown();
        _digitFocusNodes.first.requestFocus();
      }).onFailure((failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message.tr())));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCode.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('auth.verify_otp'.tr())));
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final result = await auth.verifyPhoneOTP(code);
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

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(
        title: Text(isAr ? 'التحقق من الرمز' : 'OTP Verification'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.panel(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.primary,
                      size: 34,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAr ? 'رمز التحقق' : 'Verification Code',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAr
                          ? 'أدخل الرمز المكون من 6 أرقام المرسل إلى رقم هاتفك'
                          : 'Enter the 6-digit code sent to your phone',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.secondaryText(context),
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_codeSent || _seconds == 0,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'phone_number'.tr(),
                        hintText: '+20 10 1234 5678',
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_codeSent)
                      Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            _digitControllers.length,
                            (index) => _buildOtpBox(context, index),
                          ),
                        ),
                      ),
                    if (_codeSent) const SizedBox(height: 8),
                    if (_codeSent)
                      Text(
                        isAr
                            ? 'أدخل الرمز المكوّن من 6 أرقام'
                            : 'Enter the 6-digit code',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.secondaryText(context),
                            ),
                      ),
                    const SizedBox(height: 10),
                    if (_codeSent)
                      Row(
                        children: [
                          Text(
                            isAr ? 'لم يصلك الرمز؟' : "Didn't receive code?",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          TextButton(
                            onPressed:
                                (_seconds > 0 || _loading) ? null : _sendOtp,
                            child: Text(
                              _seconds > 0
                                  ? (isAr
                                      ? 'إعادة الإرسال بعد $_seconds'
                                      : 'Resend in $_seconds')
                                  : (isAr ? 'إعادة الإرسال' : 'Resend'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed:
                    _loading ? null : (_codeSent ? _verifyOtp : _sendOtp),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0A1430),
                        ),
                      )
                    : Text(_codeSent ? 'verify_otp'.tr() : 'send_otp'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
