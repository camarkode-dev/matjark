import 'package:flutter/material.dart';

/// Wrapper widget that builds only once (for image networks, etc.)
/// Useful for preventing unnecessary rebuilds
class BuildOnceWidget extends StatefulWidget {
  final WidgetBuilder builder;
  
  const BuildOnceWidget({
    required this.builder,
    super.key,
  });

  @override
  State<BuildOnceWidget> createState() => _BuildOnceWidgetState();
}

class _BuildOnceWidgetState extends State<BuildOnceWidget> {
  late Widget _cachedWidget;
  
  @override
  void initState() {
    super.initState();
    _cachedWidget = widget.builder(context);
  }

  @override
  Widget build(BuildContext context) => _cachedWidget;
}

/// Widget that prevents rebuilds of expensive child
class RepaintBoundaryWrapper extends StatelessWidget {
  final Widget child;
  final bool enableRepaintBoundary;
  
  const RepaintBoundaryWrapper({
    required this.child,
    this.enableRepaintBoundary = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableRepaintBoundary) return child;
    return RepaintBoundary(child: child);
  }
}

/// Efficient list implementation with better performance
/// Uses RepaintBoundary and const constructors
class PerformantListView extends StatelessWidget {
  final List<Widget> items;
  final ScrollController? controller;
  final void Function()? onLoadMore;
  final bool isLoading;
  
  const PerformantListView({
    required this.items,
    this.controller,
    this.onLoadMore,
    this.isLoading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification && !isLoading) {
          if (controller != null && 
              controller!.offset >= 
              controller!.position.maxScrollExtent * 0.8) {
            onLoadMore?.call();
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: controller,
        itemCount: items.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            // Loading indicator
            return const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            );
          }
          
          // Use RepaintBoundary for expensive items
          return RepaintBoundary(
            child: items[index],
          );
        },
      ),
    );
  }
}

/// Grid view with performance optimizations
class PerformantGridView extends StatelessWidget {
  final List<Widget> items;
  final int crossAxisCount;
  final ScrollController? controller;
  final void Function()? onLoadMore;
  final bool isLoading;
  
  const PerformantGridView({
    required this.items,
    this.crossAxisCount = 2,
    this.controller,
    this.onLoadMore,
    this.isLoading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification && !isLoading) {
          if (controller != null && 
              controller!.offset >= 
              controller!.position.maxScrollExtent * 0.8) {
            onLoadMore?.call();
          }
        }
        return false;
      },
      child: GridView.builder(
        controller: controller,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: items.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          return RepaintBoundary(
            child: items[index],
          );
        },
      ),
    );
  }
}
