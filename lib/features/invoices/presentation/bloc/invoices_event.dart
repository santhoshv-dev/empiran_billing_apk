import 'package:equatable/equatable.dart';
import '../../../../models.dart';

abstract class InvoicesEvent extends Equatable {
  const InvoicesEvent();

  @override
  List<Object?> get props => [];
}

class LoadInvoicesRequested extends InvoicesEvent {
  const LoadInvoicesRequested();
}

class SaveTransactionRequested extends InvoicesEvent {
  final BusinessTransaction transaction;

  const SaveTransactionRequested(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

class DeleteTransactionRequested extends InvoicesEvent {
  final BusinessTransaction transaction;

  const DeleteTransactionRequested(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

class FilterInvoicesRequested extends InvoicesEvent {
  final String query;
  final String type; // 'order', 'quotation', 'all'

  const FilterInvoicesRequested({required this.query, required this.type});

  @override
  List<Object?> get props => [query, type];
}
