import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart' as auth_provider;
import '../../providers/theme_provider.dart';
import '../../widgets/adaptive_app_bar_leading.dart';
import '../../widgets/marketplace_drawer.dart';
import '../splash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _orderNotifications = true;
  bool _promoNotifications = true;
  bool _savingNotifications = false;
  bool _securityBusy = false;
  bool _updatingTheme = false;

  Future<void> _saveNotificationSettings(String uid) async {
    setState(() => _savingNotifications = true);
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'preferences': {
        'orderNotifications': _orderNotifications,
        'promoNotifications': _promoNotifications,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    setState(() => _savingNotifications = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('settings.preferences_saved'.tr())));
  }

  Future<void> _changeLanguage(String code) async {
    final auth = context.read<auth_provider.AuthProvider>();
    final result = await auth.updateLanguagePreference(code);
    result.onSuccess((_) async {
      await context.setLocale(Locale(code));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      }
    }).onFailure((failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message.tr())));
    });
  }

  Future<void> _setThemeMode({
    required ThemeMode mode,
    required String uid,
  }) async {
    setState(() => _updatingTheme = true);
    await context.read<ThemeProvider>().setThemeMode(mode);
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'themeMode': mode.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) {
      setState(() => _updatingTheme = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    await Navigator.of(context).pushNamed('/forgot-password');
  }

  Future<void> _openChangePasswordDialog() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final email = firebaseUser?.email?.trim() ?? '';
    if (firebaseUser == null || email.isEmpty) {
      return;
    }

    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool submitting = false;
    bool obscureOld = true;
    bool obscureNew = true;
    final isArabic = context.locale.languageCode == 'ar';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('settings.change_password'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPasswordController,
                obscureText: obscureOld,
                decoration: InputDecoration(
                  labelText: context.locale.languageCode == 'ar'
                      ? 'كلمة المرور القديمة'
                      : 'Current password',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setDialogState(() => obscureOld = !obscureOld),
                    icon: Icon(
                      obscureOld
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPasswordController,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: context.locale.languageCode == 'ar'
                      ? 'كلمة المرور الجديدة'
                      : 'New password',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                    icon: Icon(
                      obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _sendPasswordReset();
                  },
                  child: Text(
                    context.locale.languageCode == 'ar'
                        ? 'هل نسيت كلمة المرور؟'
                        : 'Forgot password?',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final oldPassword = oldPasswordController.text.trim();
                      final newPassword = newPasswordController.text.trim();
                      if (oldPassword.isEmpty || newPassword.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.locale.languageCode == 'ar'
                                  ? 'أدخل كلمة المرور القديمة وكلمة جديدة لا تقل عن 6 أحرف.'
                                  : 'Enter the current password and a new password with at least 6 characters.',
                            ),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        final credential = EmailAuthProvider.credential(
                          email: email,
                          password: oldPassword,
                        );
                        await firebaseUser.reauthenticateWithCredential(
                          credential,
                        );
                        await firebaseUser.updatePassword(newPassword);
                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isArabic
                                  ? 'تم تحديث كلمة المرور بنجاح.'
                                  : 'Password updated successfully.',
                            ),
                          ),
                        );
                      } on FirebaseAuthException catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(error.message ?? error.code),
                          ),
                        );
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => submitting = false);
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('settings.change_password'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  /// helper for launching the mail client so user can follow a verification link
  /// after receiving an email from Firebase.  Works on Android, iOS and web.
  Future<void> _openEmailApp() async {
    final email = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
    if (email.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmailVerification() async {
    setState(() => _securityBusy = true);
    final result = await context
        .read<auth_provider.AuthProvider>()
        .sendEmailVerification();
    if (!mounted) return;
    result.onSuccess((_) async {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.verification_email_sent'.tr())),
      );
      await _openEmailApp();
    }).onFailure((failure) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message.tr())));
    });
    setState(() => _securityBusy = false);
  }

  Future<void> _refreshVerificationState() async {
    setState(() => _securityBusy = true);
    final result =
        await context.read<auth_provider.AuthProvider>().reloadCurrentUser();
    if (!mounted) return;
    result.onSuccess((_) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.verification_status_refreshed'.tr()),
        ),
      );
    }).onFailure((failure) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message.tr())));
    });
    setState(() => _securityBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<auth_provider.AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.currentUser;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final emailVerified = firebaseUser?.emailVerified ?? false;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final isAr = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(hasDrawer: true),
        title: Text('settings.title'.tr()),
      ),
      drawer: const MarketplaceDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
        children: [
          _SettingsSection(
            title: isAr ? 'اللغة والمظهر' : 'Language & Appearance',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: user.language == 'en' ? 'en' : 'ar',
                  decoration: InputDecoration(
                    labelText: 'settings.language'.tr(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'ar',
                      child: Text('settings.arabic_rtl'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text('settings.english_ltr'.tr()),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _changeLanguage(value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('settings.appearance'.tr())),
                    Expanded(
                      flex: 2,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ThemeModeChip(
                            label: 'settings.theme_system'.tr(),
                            icon: Icons.brightness_auto_outlined,
                            selected: themeProvider.themeMode == ThemeMode.system,
                            onTap: _updatingTheme
                                ? null
                                : () => _setThemeMode(
                                      mode: ThemeMode.system,
                                      uid: user.uid,
                                    ),
                          ),
                          _ThemeModeChip(
                            label: 'settings.theme_light'.tr(),
                            icon: Icons.light_mode_outlined,
                            selected: themeProvider.themeMode == ThemeMode.light,
                            onTap: _updatingTheme
                                ? null
                                : () => _setThemeMode(
                                      mode: ThemeMode.light,
                                      uid: user.uid,
                                    ),
                          ),
                          _ThemeModeChip(
                            label: 'settings.theme_dark'.tr(),
                            icon: Icons.dark_mode_outlined,
                            selected: themeProvider.themeMode == ThemeMode.dark,
                            onTap: _updatingTheme
                                ? null
                                : () => _setThemeMode(
                                      mode: ThemeMode.dark,
                                      uid: user.uid,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _SettingsSection(
            title: 'settings.security'.tr(),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text('settings.email_verification'.tr()),
                  subtitle: Text(
                    emailVerified
                        ? 'settings.email_verified'.tr()
                        : 'settings.email_not_verified'.tr(),
                  ),
                  trailing: OutlinedButton(
                    onPressed: _securityBusy ? null : _refreshVerificationState,
                    child: Text('settings.refresh'.tr()),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _securityBusy ? null : _sendEmailVerification,
                  icon: _securityBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mark_email_read_outlined),
                  label: Text('settings.send_verification_email'.tr()),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _securityBusy ? null : _openChangePasswordDialog,
                  icon: const Icon(Icons.lock_reset_outlined),
                  label: Text('settings.change_password'.tr()),
                ),
              ],
            ),
          ),
          _SettingsSection(
            title: 'settings.notification_preferences'.tr(),
            child: Column(
              children: [
                SwitchListTile(
                  value: _orderNotifications,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _orderNotifications = v),
                  title: Text('settings.order_updates'.tr()),
                ),
                SwitchListTile(
                  value: _promoNotifications,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _promoNotifications = v),
                  title: Text('settings.offers_promotions'.tr()),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _savingNotifications
                      ? null
                      : () => _saveNotificationSettings(user.uid),
                  icon: _savingNotifications
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text('settings.save_preferences'.tr()),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: auth.signOut,
            icon: const Icon(Icons.logout),
            label: Text('nav.logout'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ThemeModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _ThemeModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.animationFast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.18)
              : AppTheme.panelSoft(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? AppTheme.primary : null),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? AppTheme.primary : null,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
