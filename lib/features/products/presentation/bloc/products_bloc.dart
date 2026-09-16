import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models.dart';
import '../../data/repositories/products_repository.dart';
import 'products_event.dart';
import 'products_state.dart';

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductsRepository productsRepository;

  ProductsBloc({required this.productsRepository}) : super(const ProductsInitial()) {
    on<LoadProductsRequested>(_onLoadProductsRequested);
    on<SaveProductRequested>(_onSaveProductRequested);
    on<DeleteProductRequested>(_onDeleteProductRequested);
    on<AdjustStockRequested>(_onAdjustStockRequested);
    on<FilterProductsRequested>(_onFilterProductsRequested);
  }

  List<Item> _filter(List<Item> items, String query, String category) {
    return items.where((i) {
      final matchesQuery = query.isEmpty ||
          i.name.toLowerCase().contains(query.toLowerCase()) ||
          i.itemCode.toLowerCase().contains(query.toLowerCase()) ||
          i.hsn.toLowerCase().contains(query.toLowerCase());
      final matchesCategory = category == 'All' || i.category == category;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  Future<void> _onLoadProductsRequested(
    LoadProductsRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(const ProductsLoading());
    try {
      final items = await productsRepository.loadProducts();
      emit(ProductsLoaded(
        items: items,
        filteredItems: items,
      ));
    } catch (e) {
      emit(ProductsFailure(e.toString()));
    }
  }

  Future<void> _onSaveProductRequested(
    SaveProductRequested event,
    Emitter<ProductsState> emit,
  ) async {
    try {
      await productsRepository.saveProduct(event.item);
      final items = await productsRepository.loadProducts();
      final currentCategory = state is ProductsLoaded ? (state as ProductsLoaded).selectedCategory : 'All';
      final currentQuery = state is ProductsLoaded ? (state as ProductsLoaded).query : '';
      emit(ProductsLoaded(
        items: items,
        filteredItems: _filter(items, currentQuery, currentCategory),
        query: currentQuery,
        selectedCategory: currentCategory,
        message: 'Product saved successfully.',
      ));
    } catch (e) {
      emit(ProductsFailure(e.toString()));
    }
  }

  Future<void> _onDeleteProductRequested(
    DeleteProductRequested event,
    Emitter<ProductsState> emit,
  ) async {
    try {
      await productsRepository.deleteProduct(event.item);
      final items = await productsRepository.loadProducts();
      final currentCategory = state is ProductsLoaded ? (state as ProductsLoaded).selectedCategory : 'All';
      final currentQuery = state is ProductsLoaded ? (state as ProductsLoaded).query : '';
      emit(ProductsLoaded(
        items: items,
        filteredItems: _filter(items, currentQuery, currentCategory),
        query: currentQuery,
        selectedCategory: currentCategory,
        message: 'Product deleted.',
      ));
    } catch (e) {
      emit(ProductsFailure(e.toString()));
    }
  }

  Future<void> _onAdjustStockRequested(
    AdjustStockRequested event,
    Emitter<ProductsState> emit,
  ) async {
    try {
      await productsRepository.adjustStock(event.item, event.change);
      final items = await productsRepository.loadProducts();
      final currentCategory = state is ProductsLoaded ? (state as ProductsLoaded).selectedCategory : 'All';
      final currentQuery = state is ProductsLoaded ? (state as ProductsLoaded).query : '';
      emit(ProductsLoaded(
        items: items,
        filteredItems: _filter(items, currentQuery, currentCategory),
        query: currentQuery,
        selectedCategory: currentCategory,
        message: 'Stock updated.',
      ));
    } catch (e) {
      emit(ProductsFailure(e.toString()));
    }
  }

  void _onFilterProductsRequested(
    FilterProductsRequested event,
    Emitter<ProductsState> emit,
  ) {
    if (state is! ProductsLoaded) return;
    final current = state as ProductsLoaded;
    final filtered = _filter(current.items, event.query, event.category);
    emit(current.copyWith(
      filteredItems: filtered,
      query: event.query,
      selectedCategory: event.category,
    ));
  }
}
