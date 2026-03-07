import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/adaptive_app_bar_leading.dart';
import '../../widgets/marketplace_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _sellerModeEnabled = false;

  Future<void> _changeLanguage(BuildContext context, String code) async {
    final auth = context.read<AuthProvider>();
    final result = await auth.updateLanguagePreference(code);
    if (!mounted) return;

    result
        .onSuccess((_) async {
          await context.setLocale(Locale(code));
        })
        .onFailure((failure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message.tr())));
        });
  }

  void _toggleSellerMode(bool enabled) {
    setState(() => _sellerModeEnabled = enabled);
    if (enabled) {
      Navigator.of(context).pushNamedAndRemoveUntil('/seller', (_) => false);
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/customer/profile', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isAr = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      drawer: const MarketplaceDrawer(),
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(hasDrawer: true),
        title: Text('nav.profile'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E3A9A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    (user.name?.isNotEmpty ?? false)
                        ? user.name!.substring(0, 1).toUpperCase()
                        : 'M',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user.name ?? 'common.user'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? '',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    'roles.${user.role.name}'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ProfileTile(
            icon: Icons.shopping_bag_outlined,
            title: isAr ? 'طلباتي' : 'My Orders',
            onTap: () => Navigator.of(context).pushNamed('/customer/orders'),
          ),
          _ProfileTile(
            icon: Icons.local_shipping_outlined,
            title: isAr ? 'تتبع الطلب' : 'Order Tracking',
            onTap: () => Navigator.of(context).pushNamed('/customer/tracking'),
          ),
          _ProfileTile(
            icon: Icons.favorite_outline,
            title: isAr ? 'المفضلة' : 'Favorites',
            onTap: () => Navigator.of(context).pushNamed('/customer/favorites'),
          ),
          _ProfileTile(
            icon: Icons.settings_outlined,
            title: 'settings.title'.tr(),
            onTap: () => Navigator.of(context).pushNamed('/customer/settings'),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.panel(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: user.language == 'en' ? 'en' : 'ar',
              decoration: InputDecoration(
                labelText: 'settings.language'.tr(),
                border: InputBorder.none,
                isDense: true,
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
                _changeLanguage(context, value);
              },
            ),
          ),
          if (user.role == UserRole.seller && user.isApproved) ...[
            const SizedBox(height: 10),
            _ProfileTile(
              icon: Icons.inventory_2_outlined,
              title: isAr ? 'إدارة المنتجات' : 'Manage Products',
              onTap: () => Navigator.of(context).pushNamed('/seller'),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.panel(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: SwitchListTile(
                value: _sellerModeEnabled,
                onChanged: _toggleSellerMode,
                title: Text('profile.switch_to_seller'.tr()),
                subtitle: Text('seller_center.steps_info'.tr()),
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await auth.signOut();
            },
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

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
