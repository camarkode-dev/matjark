import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/adaptive_app_bar_leading.dart';
import '../../widgets/marketplace_drawer.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _resolveTitle({
    required String type,
    required String fallback,
    required String refShort,
  }) {
    final key = 'notifications.types.$type.title';
    final translated = key.tr(namedArgs: {'id': refShort});
    return translated == key ? fallback : translated;
  }

  String _resolveBody({
    required String type,
    required String fallback,
    required String refShort,
  }) {
    final key = 'notifications.types.$type.body';
    final translated = key.tr(namedArgs: {'id': refShort});
    return translated == key ? fallback : translated;
  }

  String _relativeTime(Timestamp? ts, bool isAr) {
    if (ts == null) {
      return '';
    }
    final now = DateTime.now();
    final diff = now.difference(ts.toDate());
    if (diff.inMinutes < 1) {
      return isAr ? 'الآن' : 'now';
    }
    if (diff.inHours < 1) {
      return isAr ? '${diff.inMinutes} د' : '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return isAr ? '${diff.inHours} س' : '${diff.inHours}h';
    }
    return isAr ? '${diff.inDays} يوم' : '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    final isAr = context.locale.languageCode == 'ar';

    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(hasDrawer: true),
        title: Text('notifications.title'.tr()),
      ),
      drawer: const MarketplaceDrawer(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Text('notifications.none'.tr()));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final type = (data['type'] ?? '').toString();
              final referenceId = (data['referenceId'] ?? '').toString();
              final refShort = referenceId.length > 8
                  ? referenceId.substring(0, 8)
                  : referenceId;
              final fallbackTitle =
                  (data['title'] ??
                          data['titleEn'] ??
                          'common.notification'.tr())
                      .toString();
              final fallbackBody = (data['body'] ?? data['bodyEn'] ?? '')
                  .toString();
              final title = _resolveTitle(
                type: type,
                fallback: fallbackTitle,
                refShort: refShort,
              );
              final body = _resolveBody(
                type: type,
                fallback: fallbackBody,
                refShort: refShort,
              );
              final read = data['isRead'] == true;
              final createdAt = data['createdAt'] as Timestamp?;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await docs[index].reference.set({
                    'isRead': true,
                  }, SetOptions(merge: true));
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: read
                        ? AppTheme.panel(context)
                        : AppTheme.panelSoft(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: read ? AppTheme.border(context) : AppTheme.primary,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: read
                              ? AppTheme.panelSoft(context)
                              : AppTheme.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          read
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          size: 18,
                          color: read
                              ? AppTheme.secondaryText(context)
                              : AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: read
                                              ? FontWeight.w600
                                              : FontWeight.w800,
                                        ),
                                  ),
                                ),
                                Text(
                                  _relativeTime(createdAt, isAr),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppTheme.secondaryText(context),
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.secondaryText(context),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
