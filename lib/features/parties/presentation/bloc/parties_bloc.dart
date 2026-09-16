import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models.dart';
import '../../data/repositories/parties_repository.dart';
import 'parties_event.dart';
import 'parties_state.dart';

class PartiesBloc extends Bloc<PartiesEvent, PartiesState> {
  final PartiesRepository partiesRepository;

  PartiesBloc({required this.partiesRepository}) : super(const PartiesInitial()) {
    on<LoadPartiesRequested>(_onLoadPartiesRequested);
    on<SavePartyRequested>(_onSavePartyRequested);
    on<DeletePartyRequested>(_onDeletePartyRequested);
    on<FilterPartiesRequested>(_onFilterPartiesRequested);
  }

  List<Party> _filter(List<Party> parties, String query, String filter) {
    return parties.where((p) {
      final matchesQuery = '${p.name} ${p.phone} ${p.type} ${p.gstin}'
          .toLowerCase()
          .contains(query.toLowerCase());
      if (!matchesQuery) return false;
      if (filter == 'Customers') return p.type == 'Customer' || p.type == 'Both';
      if (filter == 'Suppliers') return p.type == 'Supplier' || p.type == 'Both';
      return true;
    }).toList();
  }

  Future<void> _onLoadPartiesRequested(
    LoadPartiesRequested event,
    Emitter<PartiesState> emit,
  ) async {
    emit(const PartiesLoading());
    try {
      final parties = await partiesRepository.loadParties();
      emit(PartiesLoaded(parties: parties, filteredParties: parties));
    } catch (e) {
      emit(PartiesFailure(e.toString()));
    }
  }

  Future<void> _onSavePartyRequested(
    SavePartyRequested event,
    Emitter<PartiesState> emit,
  ) async {
    try {
      await partiesRepository.saveParty(event.party);
      final parties = await partiesRepository.loadParties();
      final currentFilter = state is PartiesLoaded ? (state as PartiesLoaded).partyFilter : 'All';
      final currentQuery = state is PartiesLoaded ? (state as PartiesLoaded).query : '';
      emit(PartiesLoaded(
        parties: parties,
        filteredParties: _filter(parties, currentQuery, currentFilter),
        query: currentQuery,
        partyFilter: currentFilter,
        message: 'Contact saved successfully.',
      ));
    } catch (e) {
      emit(PartiesFailure(e.toString()));
    }
  }

  Future<void> _onDeletePartyRequested(
    DeletePartyRequested event,
    Emitter<PartiesState> emit,
  ) async {
    try {
      await partiesRepository.deleteParty(event.party);
      final parties = await partiesRepository.loadParties();
      final currentFilter = state is PartiesLoaded ? (state as PartiesLoaded).partyFilter : 'All';
      final currentQuery = state is PartiesLoaded ? (state as PartiesLoaded).query : '';
      emit(PartiesLoaded(
        parties: parties,
        filteredParties: _filter(parties, currentQuery, currentFilter),
        query: currentQuery,
        partyFilter: currentFilter,
        message: 'Contact deleted.',
      ));
    } catch (e) {
      emit(PartiesFailure(e.toString()));
    }
  }

  void _onFilterPartiesRequested(
    FilterPartiesRequested event,
    Emitter<PartiesState> emit,
  ) {
    if (state is! PartiesLoaded) return;
    final current = state as PartiesLoaded;
    final filtered = _filter(current.parties, event.query, event.partyFilter);
    emit(current.copyWith(
      filteredParties: filtered,
      query: event.query,
      partyFilter: event.partyFilter,
    ));
  }
}
