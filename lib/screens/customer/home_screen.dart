import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notifications_service.dart';
import '../../widgets/category_card.dart';
import '../../widgets/marketplace_drawer.dart';
import '../../widgets/product_card.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final notifications = NotificationsService();
    final auth = context.watch<AuthProvider>();
    final uid = auth.currentUser?.uid;
    final isAr = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      drawer: const MarketplaceDrawer(),
      appBar: AppBar(
        title: Text('home.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () =>
                Navigator.of(context).pushNamed('/customer/categories'),
          ),
          if (uid != null)
            StreamBuilder<int>(
              stream: notifications.unreadCountStream(uid),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return IconButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed('/customer/notifications'),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none_rounded),
                      if (unread > 0)
                        Positioned(
                          right: -2,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 450));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            _SearchStrip(isAr: isAr),
            const SizedBox(height: 14),
            _HeroOfferCard(isAr: isAr),
            const SizedBox(height: 18),
            _SectionHeader(
              title: isAr ? 'التصنيفات' : 'Categories',
              onTap: () =>
                  Navigator.of(context).pushNamed('/customer/categories'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 158,
              child: StreamBuilder<List<Category>>(
                stream: firestore.getCategories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final categories = snapshot.data ?? [];
                  if (categories.isEmpty) {
                    return Center(child: Text('categories.empty'.tr()));
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 116,
                        child: CategoryCard(
                          category: categories[index],
                          onTap: () => Navigator.of(
                            context,
                          ).pushNamed('/customer/categories'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: isAr ? 'وصل حديثًا' : 'New Arrivals',
              onTap: () =>
                  Navigator.of(context).pushNamed('/customer/categories'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 316,
              child: StreamBuilder<List<Product>>(
                stream: firestore.getProducts(limit: 10),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final products = snapshot.data ?? [];
                  if (products.isEmpty) {
                    return Center(child: Text('home.no_featured'.tr()));
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length.clamp(0, 8),
                    separatorBuilder: (_, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => SizedBox(
                      width: 200,
                      child: ProductCard(product: products[index]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: isAr ? 'الأكثر مبيعًا' : 'Best Sellers',
              onTap: () =>
                  Navigator.of(context).pushNamed('/customer/categories'),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<Product>>(
              stream: firestore.getProducts(limit: 12),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return Center(child: Text('home.no_featured'.tr()));
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length.clamp(0, 6),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) =>
                      ProductCard(product: products[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchStrip extends StatelessWidget {
  final bool isAr;

  const _SearchStrip({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppTheme.secondaryText(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAr ? 'ابحث عن منتجات، فئات...' : 'Search products, brands...',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                  ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/customer/cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _HeroOfferCard extends StatelessWidget {
  final bool isAr;

  const _HeroOfferCard({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF16316E), Color(0xFF2A58BC), Color(0xFF6C98FF)],
        ),
        boxShadow: AppTheme.shadowMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'خصومات منتصف الموسم' : 'Mid-Season Sale',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAr ? 'خصم حتى 50% على الإكسسوارات' : 'Up to 50% off accessories',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pushNamed('/customer/categories'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF16316E),
              minimumSize: const Size(130, 40),
            ),
            child: Text(isAr ? 'تسوق الآن' : 'Shop Now'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SectionHeader({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: onTap, child: Text('home.see_all'.tr())),
      ],
    );
  }
}
