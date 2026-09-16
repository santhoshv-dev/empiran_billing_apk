import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models.dart';
import '../../data/repositories/invoices_repository.dart';
import 'invoices_event.dart';
import 'invoices_state.dart';

class InvoicesBloc extends Bloc<InvoicesEvent, InvoicesState> {
  final InvoicesRepository invoicesRepository;

  InvoicesBloc({required this.invoicesRepository}) : super(const InvoicesInitial()) {
    on<LoadInvoicesRequested>(_onLoadInvoicesRequested);
    on<SaveTransactionRequested>(_onSaveTransactionRequested);
    on<DeleteTransactionRequested>(_onDeleteTransactionRequested);
    on<FilterInvoicesRequested>(_onFilterInvoicesRequested);
  }

  List<BusinessTransaction> _filter(List<BusinessTransaction> txns, String query, String type) {
    return txns.where((t) {
      final matchesQuery = query.isEmpty ||
          t.number.toLowerCase().contains(query.toLowerCase()) ||
          t.partyName.toLowerCase().contains(query.toLowerCase());
      final matchesType = type == 'all' || t.type == type;
      return matchesQuery && matchesType;
    }).toList();
  }

  Future<void> _onLoadInvoicesRequested(
    LoadInvoicesRequested event,
    Emitter<InvoicesState> emit,
  ) async {
    emit(const InvoicesLoading());
    try {
      final txns = await invoicesRepository.loadInvoices();
      emit(InvoicesLoaded(transactions: txns, filteredTransactions: txns));
    } catch (e) {
      emit(InvoicesFailure(e.toString()));
    }
  }

  Future<void> _onSaveTransactionRequested(
    SaveTransactionRequested event,
    Emitter<InvoicesState> emit,
  ) async {
    try {
      await invoicesRepository.saveTransaction(event.transaction);
      final txns = await invoicesRepository.loadInvoices();
      final currentType = state is InvoicesLoaded ? (state as InvoicesLoaded).selectedType : 'all';
      final currentQuery = state is InvoicesLoaded ? (state as InvoicesLoaded).query : '';
      emit(InvoicesLoaded(
        transactions: txns,
        filteredTransactions: _filter(txns, currentQuery, currentType),
        query: currentQuery,
        selectedType: currentType,
        message: 'Transaction saved successfully.',
      ));
    } catch (e) {
      emit(InvoicesFailure(e.toString()));
    }
  }

  Future<void> _onDeleteTransactionRequested(
    DeleteTransactionRequested event,
    Emitter<InvoicesState> emit,
  ) async {
    try {
      await invoicesRepository.deleteTransaction(event.transaction);
      final txns = await invoicesRepository.loadInvoices();
      final currentType = state is InvoicesLoaded ? (state as InvoicesLoaded).selectedType : 'all';
      final currentQuery = state is InvoicesLoaded ? (state as InvoicesLoaded).query : '';
      emit(InvoicesLoaded(
        transactions: txns,
        filteredTransactions: _filter(txns, currentQuery, currentType),
        query: currentQuery,
        selectedType: currentType,
        message: 'Transaction removed.',
      ));
    } catch (e) {
      emit(InvoicesFailure(e.toString()));
    }
  }

  void _onFilterInvoicesRequested(
    FilterInvoicesRequested event,
    Emitter<InvoicesState> emit,
  ) {
    if (state is! InvoicesLoaded) return;
    final current = state as InvoicesLoaded;
    final filtered = _filter(current.transactions, event.query, event.type);
    emit(current.copyWith(
      filteredTransactions: filtered,
      query: event.query,
      selectedType: event.type,
    ));
  }
}
