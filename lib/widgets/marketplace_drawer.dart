import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/common/static_page_screen.dart';

class MarketplaceDrawer extends StatelessWidget {
  const MarketplaceDrawer({super.key});

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  void _openStaticPage(BuildContext context, String pageId, String title) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaticPageScreen(pageId: pageId, fallbackTitle: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';

    final isAdmin = auth.isAdmin || user?.role == UserRole.admin;
    final isSeller = user?.role == UserRole.seller;
    final isApprovedSeller = isSeller && (user?.isApproved ?? false);
    final hasPendingSellerRequest = user?.sellerRequestStatus == 'pending';
    final showBecomeSeller =
        user != null && !isAdmin && user.role == UserRole.customer;
    final sellerEntryRoute = isApprovedSeller ? '/seller' : '/seller/waiting';

    return Drawer(
      backgroundColor: AppTheme.scaffold(context),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.panel(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                    child: Text(
                      (user?.name?.isNotEmpty ?? false)
                          ? user!.name!.substring(0, 1).toUpperCase()
                          : 'M',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'common.user'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _DrawerTile(
                    icon: Icons.home_outlined,
                    title: 'nav.home'.tr(),
                    selected: currentRoute == '/customer',
                    onTap: () => _go(context, '/customer'),
                  ),
                  _DrawerTile(
                    icon: Icons.shopping_cart_outlined,
                    title: 'nav.cart'.tr(),
                    selected: currentRoute == '/customer/cart',
                    onTap: () => _go(context, '/customer/cart'),
                  ),
                  _DrawerTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'drawer.order_tracking'.tr(),
                    selected: currentRoute == '/customer/tracking',
                    onTap: () => _go(context, '/customer/tracking'),
                  ),
                  _DrawerTile(
                    icon: Icons.favorite_outline,
                    title: 'nav.favorites'.tr(),
                    selected: currentRoute == '/customer/favorites',
                    onTap: () => _go(context, '/customer/favorites'),
                  ),
                  _DrawerTile(
                    icon: Icons.person_outline,
                    title: 'nav.profile'.tr(),
                    selected: currentRoute == '/customer/profile',
                    onTap: () => _go(context, '/customer/profile'),
                  ),
                  _DrawerTile(
                    icon: Icons.settings_outlined,
                    title: 'drawer.settings'.tr(),
                    selected: currentRoute == '/customer/settings',
                    onTap: () => _go(context, '/customer/settings'),
                  ),
                  _DrawerTile(
                    icon: Icons.category_outlined,
                    title: 'nav.categories'.tr(),
                    selected: currentRoute == '/customer/categories',
                    onTap: () => _go(context, '/customer/categories'),
                  ),
                  const SizedBox(height: 6),
                  if (showBecomeSeller)
                    _DrawerTile(
                      icon: Icons.app_registration_outlined,
                      title: hasPendingSellerRequest
                          ? 'seller.waiting_approval.title'.tr()
                          : 'drawer.register_as_seller'.tr(),
                      subtitle: hasPendingSellerRequest
                          ? 'seller.waiting_approval.description'.tr()
                          : null,
                      selected:
                          currentRoute == '/customer/seller-center' ||
                          currentRoute == '/seller/waiting',
                      onTap: () => _go(
                        context,
                        hasPendingSellerRequest
                            ? '/seller/waiting'
                            : '/customer/seller-center',
                      ),
                    ),
                  if (isSeller)
                    _DrawerTile(
                      icon: Icons.store_mall_directory_outlined,
                      title: 'seller.dashboard'.tr(),
                      subtitle: isApprovedSeller
                          ? 'seller_center.status.approved'.tr()
                          : 'seller_center.status.pending'.tr(),
                      selected: currentRoute == sellerEntryRoute,
                      onTap: () => _go(context, sellerEntryRoute),
                    ),
                  if (isAdmin)
                    _DrawerTile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'admin.dashboard'.tr(),
                      selected: currentRoute == '/admin',
                      onTap: () => _go(context, '/admin'),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'drawer.policies'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.secondaryText(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _DrawerTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'drawer.privacy_policy'.tr(),
                    onTap: () => _openStaticPage(
                      context,
                      'privacy_policy',
                      'drawer.privacy_policy'.tr(),
                    ),
                  ),
                  _DrawerTile(
                    icon: Icons.gavel_outlined,
                    title: 'drawer.terms_conditions'.tr(),
                    onTap: () => _openStaticPage(
                      context,
                      'terms_conditions',
                      'drawer.terms_conditions'.tr(),
                    ),
                  ),
                  _DrawerTile(
                    icon: Icons.assignment_return_outlined,
                    title: 'drawer.return_policy'.tr(),
                    onTap: () => _openStaticPage(
                      context,
                      'return_policy',
                      'drawer.return_policy'.tr(),
                    ),
                  ),
                  _DrawerTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'drawer.shipping_policy'.tr(),
                    onTap: () => _openStaticPage(
                      context,
                      'shipping_policy',
                      'drawer.shipping_policy'.tr(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await auth.signOut();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (_) => false);
                  }
                },
                icon: const Icon(Icons.logout),
                label: Text('nav.logout'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.16)
            : AppTheme.panel(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppTheme.primary : AppTheme.border(context),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: selected ? AppTheme.primary : null),
        title: Text(
          title,
          style: TextStyle(
            color: selected
                ? AppTheme.primary
                : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
        onTap: onTap,
      ),
    );
  }
}
