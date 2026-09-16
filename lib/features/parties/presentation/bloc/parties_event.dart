import 'package:equatable/equatable.dart';
import '../../../../models.dart';

abstract class PartiesEvent extends Equatable {
  const PartiesEvent();

  @override
  List<Object?> get props => [];
}

class LoadPartiesRequested extends PartiesEvent {
  const LoadPartiesRequested();
}

class SavePartyRequested extends PartiesEvent {
  final Party party;

  const SavePartyRequested(this.party);

  @override
  List<Object?> get props => [party];
}

class DeletePartyRequested extends PartiesEvent {
  final Party party;

  const DeletePartyRequested(this.party);

  @override
  List<Object?> get props => [party];
}

class FilterPartiesRequested extends PartiesEvent {
  final String query;
  final String partyFilter; // 'All', 'Customers', 'Suppliers'

  const FilterPartiesRequested({required this.query, required this.partyFilter});

  @override
  List<Object?> get props => [query, partyFilter];
}
