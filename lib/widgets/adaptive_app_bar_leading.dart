import 'package:flutter/material.dart';

class AdaptiveAppBarLeading extends StatelessWidget {
  final bool hasDrawer;

  const AdaptiveAppBarLeading({
    super.key,
    this.hasDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      return IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.of(context).maybePop(),
      );
    }

    if (hasDrawer) {
      return Builder(
        builder: (innerContext) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(innerContext).openDrawer(),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
