import 'package:equatable/equatable.dart';
import '../../../../models.dart';

abstract class ProductsEvent extends Equatable {
  const ProductsEvent();

  @override
  List<Object?> get props => [];
}

class LoadProductsRequested extends ProductsEvent {
  const LoadProductsRequested();
}

class SaveProductRequested extends ProductsEvent {
  final Item item;

  const SaveProductRequested(this.item);

  @override
  List<Object?> get props => [item];
}

class DeleteProductRequested extends ProductsEvent {
  final Item item;

  const DeleteProductRequested(this.item);

  @override
  List<Object?> get props => [item];
}

class AdjustStockRequested extends ProductsEvent {
  final Item item;
  final double change;
  final String reason;

  const AdjustStockRequested({
    required this.item,
    required this.change,
    this.reason = 'Stock Adjustment',
  });

  @override
  List<Object?> get props => [item, change, reason];
}

class FilterProductsRequested extends ProductsEvent {
  final String query;
  final String category;

  const FilterProductsRequested({required this.query, required this.category});

  @override
  List<Object?> get props => [query, category];
}
