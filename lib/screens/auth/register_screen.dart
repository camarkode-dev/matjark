import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/theme.dart';
import '../../core/auth_result.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  UserRole _selectedRole = UserRole.customer;
  bool _loading = false;
  AuthFailure? _error;
  late final AnimationController _animController;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final result = await auth.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: _selectedRole,
      );
      if (!mounted) return;

      result
          .onSuccess((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account created successfully')));
          Navigator.of(context).pop();
        }
      })
          .onFailure((failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
          setState(() => _error = failure);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    WidgetsBinding.instance.addPostFrameCallback((_) => _animController.forward());
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('register'.tr()),
        elevation: AppTheme.elevationSmall,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: FadeTransition(
                opacity: _animController.drive(CurveTween(curve: Curves.easeIn)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppTheme.spacing24),
                      Center(
                        child: SizedBox(
                          height: 96,
                          width: 96,
                          child: Image.asset('assets/logo.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => CircleAvatar(radius: 48, backgroundColor: AppTheme.primary, child: Text('M', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)))),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      Text('Register', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: AppTheme.spacing8),
                      Text('Create your account to get started', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: AppTheme.spacing24),
                      TextFormField(controller: _nameController, enabled: !_loading, focusNode: _nameFocus, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: 'name'.tr(), prefixIcon: const Icon(Icons.person_outline)), validator: (v) => v == null || v.isEmpty ? 'name_required'.tr() : null, onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus)),
                      const SizedBox(height: AppTheme.spacing16),
                      TextFormField(controller: _emailController, enabled: !_loading, focusNode: _emailFocus, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: 'email'.tr(), prefixIcon: const Icon(Icons.email_outlined)), validator: (v) { if (v == null || v.isEmpty) return 'email_invalid'.tr(); final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$'); return !emailRegex.hasMatch(v) ? 'email_invalid'.tr() : null; }, onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus)),
                      const SizedBox(height: AppTheme.spacing16),
                      TextFormField(controller: _passwordController, enabled: !_loading, focusNode: _passwordFocus, decoration: InputDecoration(labelText: 'password'.tr(), prefixIcon: const Icon(Icons.lock_outline)), obscureText: true, validator: (v) => v == null || v.length < 6 ? 'password_min_6'.tr() : null),
                      const SizedBox(height: AppTheme.spacing16),
                      TextFormField(controller: _confirmController, enabled: !_loading, decoration: InputDecoration(labelText: 'confirm_password'.tr(), prefixIcon: const Icon(Icons.lock_outline)), obscureText: true, validator: (v) => v != _passwordController.text ? 'passwords_dont_match'.tr() : null),
                      const SizedBox(height: AppTheme.spacing16),
                      DropdownButtonFormField<UserRole>(initialValue: _selectedRole, isExpanded: true, decoration: InputDecoration(labelText: 'role'.tr(), prefixIcon: const Icon(Icons.admin_panel_settings_outlined)), items: UserRole.values.where((r) => r != UserRole.admin).map((r) => DropdownMenuItem(value: r, child: Text(r.name.toUpperCase()))).toList(), onChanged: _loading ? null : (r) { if (r != null) setState(() => _selectedRole = r); }),
                      const SizedBox(height: AppTheme.spacing24),
                      if (_error != null) Container(padding: const EdgeInsets.all(AppTheme.spacing12), decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(AppTheme.radiusInput), border: Border.all(color: AppTheme.error.withOpacity(0.3))), child: Text(_error!.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.error))),
                      if (_error != null) const SizedBox(height: AppTheme.spacing16),
                      ElevatedButton.icon(onPressed: _loading ? null : _register, icon: _loading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))) : const Icon(Icons.person_add), label: Text(_loading ? 'creating_account'.tr() : 'register'.tr()), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12))),
                      const SizedBox(height: AppTheme.spacing16),
                      TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(), child: Text('already_have_account'.tr())),
                    ],
                  ),
                ),
              ),
            ),
            if (_loading) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3), child: const Center(child: CircularProgressIndicator()))),
          ],
        ),
      ),
    );
  }
}
