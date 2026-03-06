import 'package:flutter/material.dart';

/// Lazy loading pagination handler for efficient data loading
/// Automatically loads more data when user scrolls near the end
class LazyLoadingController {
  final ScrollController scrollController;
  final VoidCallback onLoadMore;
  final int threshold; // Items remaining before loading more
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  LazyLoadingController({
    required this.scrollController,
    required this.onLoadMore,
    this.threshold = 5,
  }) {
    scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (!scrollController.hasClients || _isLoading) return;
    
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.offset;
    
    // Trigger load when user scrolls to 80% of list
    if (currentScroll >= maxScroll * 0.8) {
      _isLoading = true;
      onLoadMore();
    }
  }
  
  void setLoading(bool loading) {
    _isLoading = loading;
  }
  
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
  }
}

/// Pagination state manager
class PaginationState<T> {
  final List<T> items;
  final bool hasMore;
  final bool isLoading;
  final String? error;
  
  const PaginationState({
    this.items = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.error,
  });
  
  PaginationState<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? isLoading,
    String? error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
  
  PaginationState<T> addItems(List<T> newItems) {
    return copyWith(
      items: [...items, ...newItems],
      isLoading: false,
    );
  }
  
  PaginationState<T> setLoading(bool loading) {
    return copyWith(isLoading: loading);
  }
  
  PaginationState<T> setError(String? error) {
    return copyWith(error: error, isLoading: false);
  }
}
