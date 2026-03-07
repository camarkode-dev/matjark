import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/adaptive_app_bar_leading.dart';

class SellerWaitingApprovalScreen extends StatelessWidget {
  const SellerWaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isAr = context.locale.languageCode == 'ar';

    if (user != null && user.role == UserRole.seller && user.isApproved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/seller', (_) => false);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(),
        title: Text('seller.waiting_approval.title'.tr()),
        actions: [
          IconButton(onPressed: auth.signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.panel(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppTheme.panelSoft(context),
                  child: const Icon(
                    Icons.hourglass_top_outlined,
                    color: AppTheme.primary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'seller.waiting_approval.description'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'seller.waiting_approval.notification_info'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryText(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (user?.email != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.panelSoft(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${'common.email'.tr()}: ${user!.email}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/customer/profile', (_) => false),
                  child: Text(
                    isAr ? 'العودة لوضع العميل' : 'Back to Customer Mode',
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
