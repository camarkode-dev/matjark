import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/theme.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'favorites_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  final int initialIndex;

  const CustomerMainScreen({super.key, this.initialIndex = 0});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  late int _selected;

  List<Widget> get _pages => const <Widget>[
        CustomerHomeScreen(),
        CartScreen(),
        OrdersScreen(),
        FavoritesScreen(),
        ProfileScreen(),
      ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex.clamp(0, _pages.length - 1);
  }

  void _onTab(int index) {
    setState(() {
      _selected = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      body: _pages[_selected],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.panel(context),
          border: Border(top: BorderSide(color: AppTheme.border(context))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selected,
          onTap: _onTab,
          elevation: 0,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textHint,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: 'nav.home'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.shopping_cart_outlined),
              activeIcon: const Icon(Icons.shopping_cart),
              label: 'nav.cart'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.receipt_outlined),
              activeIcon: const Icon(Icons.receipt),
              label: 'nav.orders'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.favorite_outline),
              activeIcon: const Icon(Icons.favorite),
              label: 'nav.favorites'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: 'nav.profile'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}
