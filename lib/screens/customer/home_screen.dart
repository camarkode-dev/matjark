import 'dart:async';

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
import '../../widgets/remote_image.dart';
import 'categories_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  void _openCatalog(BuildContext context, {String? query}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoriesScreen(initialQuery: query),
      ),
    );
  }

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
            icon: const Icon(Icons.manage_search_rounded),
            onPressed: () => _openCatalog(context),
          ),
          if (uid != null)
            StreamBuilder<int>(
              stream: notifications.unreadCountStream(uid),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return IconButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamed('/customer/notifications'),
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
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          children: [
            _SearchStrip(onSearch: (query) => _openCatalog(context, query: query)),
            const SizedBox(height: 14),
            _HeroOffersCarousel(isAr: isAr, firestore: firestore),
            const SizedBox(height: 14),
            _PromotionsHintCard(
              isAr: isAr,
              onTap: uid == null
                  ? () => _openCatalog(context)
                  : () => Navigator.of(context).pushNamed('/customer/notifications'),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: isAr ? 'الأقسام' : 'Categories',
              onTap: () => _openCatalog(context),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 158,
              child: StreamBuilder<List<Category>>(
                stream: firestore.getCategories(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final categories = snapshot.data ?? const <Category>[];
                  if (categories.isEmpty) {
                    return Center(child: Text('categories.empty'.tr()));
                  }
                  final visible = categories.take(8).toList();
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 116,
                        child: CategoryCard(
                          category: visible[index],
                          onTap: () => _openCatalog(context),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: isAr ? 'وصل حديثاً' : 'New Arrivals',
              onTap: () => _openCatalog(context),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 356,
              child: StreamBuilder<List<Product>>(
                stream: firestore.getProducts(limit: 10),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final products = snapshot.data ?? const <Product>[];
                  if (products.isEmpty) {
                    return Center(child: Text('home.no_featured'.tr()));
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: products.take(8).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => SizedBox(
                      width: 208,
                      child: ProductCard(product: products[index]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: isAr ? 'الأكثر مبيعاً' : 'Best Sellers',
              onTap: () => _openCatalog(context),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<Product>>(
              stream: firestore.getBestSellerProducts(limit: 6),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final products = snapshot.data ?? const <Product>[];
                if (products.isEmpty) {
                  return Center(child: Text('home.no_featured'.tr()));
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.take(6).length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.76,
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

class _SearchStrip extends StatefulWidget {
  final ValueChanged<String?> onSearch;

  const _SearchStrip({required this.onSearch});

  @override
  State<_SearchStrip> createState() => _SearchStripState();
}

class _SearchStripState extends State<_SearchStrip> {
  final TextEditingController _controller = TextEditingController();
  static const List<String> _quickTerms = <String>[
    'أحذية',
    'إلكترونيات',
    'هواتف',
    'حقائب',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppTheme.panel(context),
            AppTheme.panelSoft(context),
          ],
        ),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => widget.onSearch(value.trim()),
                  decoration: InputDecoration(
                    hintText: isAr
                        ? 'ابحث عن منتج أو قسم أو علامة تجارية'
                        : 'Search for products, categories, or brands',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _controller.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.border(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.border(context)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pushNamed('/customer/cart'),
                  icon: const Icon(Icons.shopping_bag_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickTerms
                .map(
                  (term) => ActionChip(
                    label: Text(term),
                    onPressed: () => widget.onSearch(term),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _HeroOffersCarousel extends StatefulWidget {
  final bool isAr;
  final FirestoreService firestore;

  const _HeroOffersCarousel({
    required this.isAr,
    required this.firestore,
  });

  @override
  State<_HeroOffersCarousel> createState() => _HeroOffersCarouselState();
}

class _HeroOffersCarouselState extends State<_HeroOffersCarousel> {
  final PageController _controller = PageController(viewportFraction: 1);
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoPlay(int itemCount) {
    _timer?.cancel();
    if (itemCount <= 1) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      final nextIndex = (_currentIndex + 1) % itemCount;
      _controller.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.firestore.getActiveOffers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _OfferFallbackCard(
            isAr: widget.isAr,
            title: widget.isAr ? 'أحدث العروض' : 'Latest Offers',
            subtitle: widget.isAr
                ? 'تعذر تحميل العروض الآن. يمكنك متابعة التسوق من جميع الأقسام.'
                : 'Offers are unavailable right now. Continue shopping across categories.',
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 210,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final offers = snapshot.data ?? const <Map<String, dynamic>>[];
        if (offers.isEmpty) {
          return _OfferFallbackCard(
            isAr: widget.isAr,
            title: widget.isAr ? 'أحدث العروض' : 'Latest Offers',
            subtitle: widget.isAr
                ? 'لا توجد عروض مفعلة حالياً. تابع أحدث المنتجات والأقسام.'
                : 'There are no active offers right now. Explore new products and categories.',
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _startAutoPlay(offers.length);
        });
        return Column(
          children: [
            SizedBox(
              height: 210,
              child: PageView.builder(
                controller: _controller,
                itemCount: offers.length,
                onPageChanged: (index) {
                  if (!mounted) {
                    return;
                  }
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _OfferSlideCard(
                    isAr: widget.isAr,
                    offer: offers[index],
                  ),
                ),
              ),
            ),
            if (offers.length > 1) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: List.generate(offers.length, (index) {
                  final active = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: active ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primary : AppTheme.border(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _OfferSlideCard extends StatelessWidget {
  final bool isAr;
  final Map<String, dynamic> offer;

  const _OfferSlideCard({
    required this.isAr,
    required this.offer,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = (offer['imageUrl'] ?? '').toString().trim();
    final title = ((isAr ? offer['titleAr'] : offer['titleEn']) ??
            offer['titleEn'] ??
            offer['titleAr'] ??
            '')
        .toString()
        .trim();
    final discountValue = offer['discountPercent'];
    final discount = discountValue is num
        ? discountValue.toDouble()
        : double.tryParse('$discountValue') ?? 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF16316E), Color(0xFF2A58BC), Color(0xFF6C98FF)],
        ),
        boxShadow: AppTheme.shadowMedium,
      ),
      child: Stack(
        children: [
          if (imageUrl.isNotEmpty)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: RemoteImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22081425), Color(0xC4081425)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    discount > 0
                        ? (isAr ? 'خصم حتى ${discount.toStringAsFixed(discount % 1 == 0 ? 0 : 1)}%' : 'Up to ${discount.toStringAsFixed(discount % 1 == 0 ? 0 : 1)}% off')
                        : (isAr ? 'عرض مميز' : 'Featured offer'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const Spacer(),
                Text(
                  title.isEmpty ? (isAr ? 'أحدث العروض' : 'Latest Offers') : title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAr
                      ? 'العروض المضافة من الإدارة تظهر هنا تلقائياً بصورة متحركة.'
                      : 'Offers added from the admin panel rotate here automatically.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF16316E),
                    minimumSize: const Size(132, 42),
                  ),
                  child: Text(isAr ? 'تسوق الآن' : 'Shop now'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionsHintCard extends StatelessWidget {
  final bool isAr;
  final VoidCallback onTap;

  const _PromotionsHintCard({
    required this.isAr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.panel(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.local_offer_outlined, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'العروض وأكواد الخصم' : 'Offers and discount codes',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAr
                        ? 'عند إضافة كود خصم جديد من الإدارة سيصل إلى إشعارات العملاء.'
                        : 'When a new discount code is added, customers receive it in notifications.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.secondaryText(context),
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _OfferFallbackCard extends StatelessWidget {
  final bool isAr;
  final String title;
  final String subtitle;

  const _OfferFallbackCard({
    required this.isAr,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 188,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF16316E), Color(0xFF2A58BC), Color(0xFF6C98FF)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF16316E),
              minimumSize: const Size(130, 42),
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
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: onTap, child: Text('home.see_all'.tr())),
      ],
    );
  }
}
