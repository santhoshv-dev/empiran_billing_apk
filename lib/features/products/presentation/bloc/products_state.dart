import 'package:equatable/equatable.dart';
import '../../../../models.dart';

abstract class ProductsState extends Equatable {
  const ProductsState();

  @override
  List<Object?> get props => [];
}

class ProductsInitial extends ProductsState {
  const ProductsInitial();
}

class ProductsLoading extends ProductsState {
  const ProductsLoading();
}

class ProductsLoaded extends ProductsState {
  final List<Item> items;
  final List<Item> filteredItems;
  final String query;
  final String selectedCategory;
  final String? message;

  const ProductsLoaded({
    required this.items,
    required this.filteredItems,
    this.query = '',
    this.selectedCategory = 'All',
    this.message,
  });

  ProductsLoaded copyWith({
    List<Item>? items,
    List<Item>? filteredItems,
    String? query,
    String? selectedCategory,
    String? message,
  }) {
    return ProductsLoaded(
      items: items ?? this.items,
      filteredItems: filteredItems ?? this.filteredItems,
      query: query ?? this.query,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      message: message,
    );
  }

  @override
  List<Object?> get props =>
      [items, filteredItems, query, selectedCategory, message];
}

class ProductsFailure extends ProductsState {
  final String message;

  const ProductsFailure(this.message);

  @override
  List<Object?> get props => [message];
}
