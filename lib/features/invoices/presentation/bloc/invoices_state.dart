import 'package:equatable/equatable.dart';
import '../../../../models.dart';

abstract class InvoicesState extends Equatable {
  const InvoicesState();

  @override
  List<Object?> get props => [];
}

class InvoicesInitial extends InvoicesState {
  const InvoicesInitial();
}

class InvoicesLoading extends InvoicesState {
  const InvoicesLoading();
}

class InvoicesLoaded extends InvoicesState {
  final List<BusinessTransaction> transactions;
  final List<BusinessTransaction> filteredTransactions;
  final String query;
  final String selectedType;
  final String? message;

  const InvoicesLoaded({
    required this.transactions,
    required this.filteredTransactions,
    this.query = '',
    this.selectedType = 'all',
    this.message,
  });

  InvoicesLoaded copyWith({
    List<BusinessTransaction>? transactions,
    List<BusinessTransaction>? filteredTransactions,
    String? query,
    String? selectedType,
    String? message,
  }) {
    return InvoicesLoaded(
      transactions: transactions ?? this.transactions,
      filteredTransactions: filteredTransactions ?? this.filteredTransactions,
      query: query ?? this.query,
      selectedType: selectedType ?? this.selectedType,
      message: message,
    );
  }

  @override
  List<Object?> get props =>
      [transactions, filteredTransactions, query, selectedType, message];
}

class InvoicesFailure extends InvoicesState {
  final String message;

  const InvoicesFailure(this.message);

  @override
  List<Object?> get props => [message];
}
