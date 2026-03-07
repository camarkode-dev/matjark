import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/firestore_service.dart';
import '../../widgets/adaptive_app_bar_leading.dart';
import '../../widgets/marketplace_drawer.dart';
import '../../widgets/product_card.dart';

class CategoriesScreen extends StatefulWidget {
  final String? initialQuery;

  const CategoriesScreen({super.key, this.initialQuery});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Product> _products = <Product>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;
  bool _onlyDiscount = false;
  bool _bestSellers = false;
  String _sortBy = 'newest';
  double _minRating = 0;
  RangeValues _priceRange = const RangeValues(0, 10000);
  String? _selectedCategoryId;
  List<String> _suggestions = <String>[];

  @override
  void initState() {
    super.initState();
    final initialQuery = (widget.initialQuery ?? '').trim();
    if (initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
    }
    _loadInitial();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_updateSuggestions);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 320) {
      _loadNextPage();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _hasMore = true;
      _lastDoc = null;
      _products.clear();
    });
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await _firestore.fetchProductsPage(
        categoryId: _selectedCategoryId,
        minPrice: _priceRange.start,
        maxPrice: _priceRange.end,
        minRating: _minRating,
        onlyDiscounted: _onlyDiscount,
        bestSellers: _bestSellers,
        limit: 20,
        startAfter: _lastDoc,
      );
      if (!mounted) return;
      setState(() {
        _products.addAll(page.items);
        _lastDoc = page.lastDocument;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _updateSuggestions() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _suggestions = <String>[]);
      return;
    }
    final titles =
        _products
            .map(
              (p) =>
                  context.locale.languageCode == 'ar' ? p.titleAr : p.titleEn,
            )
            .where((t) => t.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final matches = titles
        .where((title) => _fuzzyMatch(q, title.toLowerCase()))
        .take(6)
        .toList();
    setState(() => _suggestions = matches);
  }

  bool _fuzzyMatch(String query, String text) {
    if (text.contains(query)) return true;
    return _levenshtein(
          query,
          text.length > 24 ? text.substring(0, 24) : text,
        ) <=
        2;
  }

  int _levenshtein(String a, String b) {
    final rows = a.length + 1;
    final cols = b.length + 1;
    final matrix = List.generate(rows, (_) => List<int>.filled(cols, 0));
    for (var i = 0; i < rows; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j < cols; j++) {
      matrix[0][j] = j;
    }
    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return matrix[a.length][b.length];
  }

  List<Product> get _visibleProducts {
    final q = _searchController.text.trim().toLowerCase();
    final filtered = _products.where((product) {
      final title = context.locale.languageCode == 'ar'
          ? (product.titleAr.isNotEmpty ? product.titleAr : product.titleEn)
          : (product.titleEn.isNotEmpty ? product.titleEn : product.titleAr);
      if (q.isNotEmpty && !_fuzzyMatch(q, title.toLowerCase())) {
        return false;
      }
      if (_onlyDiscount && !(product.costPrice > product.sellingPrice)) {
        return false;
      }
      if (_minRating > 0 && product.rating < _minRating) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'price_low_high':
          return a.sellingPrice.compareTo(b.sellingPrice);
        case 'price_high_low':
          return b.sellingPrice.compareTo(a.sellingPrice);
        case 'rating':
          return b.rating.compareTo(a.rating);
        case 'best_sellers':
          return b.salesCount.compareTo(a.salesCount);
        case 'newest':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final products = _visibleProducts;
    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(hasDrawer: true),
        title: Text('nav.categories'.tr()),
      ),
      drawer: const MarketplaceDrawer(),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.panel(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _updateSuggestions();
                            },
                          ),
                    hintText: 'home.search'.tr(),
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.panelSoft(context),
                      border: Border.all(color: AppTheme.border(context)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: _suggestions
                          .map(
                            (s) => ListTile(
                              dense: true,
                              title: Text(s),
                              onTap: () {
                                _searchController.text = s;
                                _searchController.selection =
                                    TextSelection.collapsed(offset: s.length);
                                _updateSuggestions();
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                StreamBuilder<List<Category>>(
                  stream: _firestore.getCategories(),
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? [];
                    return DropdownButtonFormField<String?>(
                      initialValue: _selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'catalog.filter.category'.tr(),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('catalog.filter.all_categories'.tr()),
                        ),
                        ...categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(
                              context.locale.languageCode == 'ar'
                                  ? c.nameAr
                                  : c.nameEn,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategoryId = value);
                        _loadInitial();
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      selected: !_bestSellers,
                      label: Text('catalog.filter.new_arrivals'.tr()),
                      onSelected: (v) {
                        if (!v) return;
                        setState(() => _bestSellers = false);
                        _loadInitial();
                      },
                    ),
                    FilterChip(
                      selected: _bestSellers,
                      label: Text('catalog.filter.best_sellers'.tr()),
                      onSelected: (v) {
                        setState(() => _bestSellers = v);
                        _loadInitial();
                      },
                    ),
                    FilterChip(
                      selected: _onlyDiscount,
                      label: Text('catalog.filter.discount_only'.tr()),
                      onSelected: (v) {
                        setState(() => _onlyDiscount = v);
                        _loadInitial();
                      },
                    ),
                    FilterChip(
                      selected: _minRating >= 4,
                      label: Text('catalog.filter.rating_4_plus'.tr()),
                      onSelected: (v) {
                        setState(() => _minRating = v ? 4 : 0);
                        _loadInitial();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _sortBy,
                  decoration: InputDecoration(
                    labelText: 'catalog.sort.label'.tr(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'newest',
                      child: Text('catalog.sort.newest'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'price_low_high',
                      child: Text('catalog.sort.price_low_high'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'price_high_low',
                      child: Text('catalog.sort.price_high_low'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'rating',
                      child: Text('catalog.sort.rating'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'best_sellers',
                      child: Text('catalog.sort.best_sellers'.tr()),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortBy = value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('catalog.filter.price_range'.tr())),
                    Text(
                      '${_priceRange.start.toStringAsFixed(0)} - ${_priceRange.end.toStringAsFixed(0)} ${'common.currency_egp'.tr()}',
                    ),
                  ],
                ),
                RangeSlider(
                  values: _priceRange,
                  min: 0,
                  max: 10000,
                  divisions: 100,
                  labels: RangeLabels(
                    _priceRange.start.toStringAsFixed(0),
                    _priceRange.end.toStringAsFixed(0),
                  ),
                  onChanged: (value) => setState(() => _priceRange = value),
                  onChangeEnd: (_) => _loadInitial(),
                ),
              ],
            ),
          ),
          Expanded(
            child: products.isEmpty && !_loading
                ? Center(child: Text('catalog.empty'.tr()))
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: products.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= products.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ProductCard(product: products[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
