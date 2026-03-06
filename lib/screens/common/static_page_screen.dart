import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

class StaticPageScreen extends StatelessWidget {
  final String pageId;
  final String fallbackTitle;

  const StaticPageScreen({
    super.key,
    required this.pageId,
    required this.fallbackTitle,
  });

  ({String titleAr, String titleEn, String contentAr, String contentEn})?
      _localFallback() {
    switch (pageId) {
      case 'privacy_policy':
        return (
          titleAr: 'سياسة الخصوصية',
          titleEn: 'Privacy Policy',
          contentAr:
              'نحن نجمع بيانات الحساب والطلبات وعناوين الشحن ووسائل التواصل فقط لتشغيل متجر متجرك وتحسين الخدمة. لا يتم بيع بياناتك لأي طرف ثالث. يتم استخدام البيانات لإدارة الطلبات، التحقق من الحسابات، دعم العملاء، وإرسال الإشعارات المتعلقة بالطلبات والعروض عند تفعيلها.',
          contentEn:
              'We collect account details, order data, shipping addresses, and contact information only to operate Matjark and improve the service. Your data is not sold to third parties. It is used for order management, account verification, customer support, and order or promotion notifications when enabled.',
        );
      case 'terms_conditions':
        return (
          titleAr: 'الشروط والأحكام',
          titleEn: 'Terms & Conditions',
          contentAr:
              'باستخدام التطبيق فإنك توافق على استخدامه بشكل قانوني وعدم إساءة استخدام الحساب أو المحتوى. جميع الطلبات تخضع لتوفر المنتج والمراجعة النهائية. يحتفظ التطبيق بحقه في إلغاء أو تعليق أي حساب أو طلب عند وجود مخالفة أو بيانات غير صحيحة.',
          contentEn:
              'By using the app, you agree to use it lawfully and not misuse accounts or content. All orders are subject to product availability and final review. The app reserves the right to cancel or suspend any account or order in case of violations or inaccurate information.',
        );
      case 'return_policy':
        return (
          titleAr: 'سياسة الإرجاع',
          titleEn: 'Return Policy',
          contentAr:
              'يمكن طلب الإرجاع خلال المدة المحددة لكل منتج بشرط أن يكون المنتج في حالته الأصلية وغير مستخدم وأن تكون جميع الملحقات مرفقة. بعض الفئات الاستهلاكية أو المنتجات الشخصية قد لا تكون قابلة للإرجاع وفقًا لطبيعتها.',
          contentEn:
              'Return requests may be submitted within the period defined for each product, provided the item is in its original condition, unused, and includes all accessories. Some consumable or personal-use categories may be non-returnable due to their nature.',
        );
      case 'shipping_policy':
        return (
          titleAr: 'سياسة الشحن',
          titleEn: 'Shipping Policy',
          contentAr:
              'يتم تجهيز الطلبات وشحنها إلى العنوان المسجل من العميل حسب نطاق التغطية ومواعيد شركات الشحن. تختلف مدة التوصيل حسب المحافظة ونوع المنتج. قد يتم التواصل مع العميل لتأكيد البيانات قبل الشحن أو في حالة وجود تأخير.',
          contentEn:
              'Orders are prepared and shipped to the address provided by the customer based on coverage area and courier schedules. Delivery time varies by governorate and product type. Customers may be contacted to confirm details before shipping or in case of delays.',
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final localFallback = _localFallback();

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(title: Text(fallbackTitle)),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('settings_pages')
            .doc(pageId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data();
          final titleCandidate = isArabic
              ? (data == null ? null : data['titleAr'])
              : (data == null ? null : data['titleEn']) ??
                    (isArabic
                        ? localFallback?.titleAr
                        : localFallback?.titleEn);
          final contentCandidate = isArabic
              ? (data == null ? null : data['contentAr'])
              : (data == null ? null : data['contentEn']) ??
                    (isArabic
                        ? localFallback?.contentAr
                        : localFallback?.contentEn);
          final title = (titleCandidate is String && titleCandidate.isNotEmpty)
              ? titleCandidate
              : fallbackTitle;
          final content =
              (contentCandidate is String && contentCandidate.isNotEmpty)
              ? contentCandidate
              : (isArabic
                    ? localFallback?.contentAr
                    : localFallback?.contentEn) ??
                    'static_pages.no_content'.tr();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(content, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          );
        },
      ),
    );
  }
}
