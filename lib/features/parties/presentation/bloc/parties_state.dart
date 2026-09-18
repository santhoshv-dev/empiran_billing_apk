import 'package:equatable/equatable.dart';
import '../../../../models.dart';

abstract class PartiesState extends Equatable {
  const PartiesState();

  @override
  List<Object?> get props => [];
}

class PartiesInitial extends PartiesState {
  const PartiesInitial();
}

class PartiesLoading extends PartiesState {
  const PartiesLoading();
}

class PartiesLoaded extends PartiesState {
  final List<Party> parties;
  final List<Party> filteredParties;
  final String query;
  final String partyFilter;
  final String? message;

  const PartiesLoaded({
    required this.parties,
    required this.filteredParties,
    this.query = '',
    this.partyFilter = 'All',
    this.message,
  });

  PartiesLoaded copyWith({
    List<Party>? parties,
    List<Party>? filteredParties,
    String? query,
    String? partyFilter,
    String? message,
  }) {
    return PartiesLoaded(
      parties: parties ?? this.parties,
      filteredParties: filteredParties ?? this.filteredParties,
      query: query ?? this.query,
      partyFilter: partyFilter ?? this.partyFilter,
      message: message,
    );
  }

  @override
  List<Object?> get props =>
      [parties, filteredParties, query, partyFilter, message];
}

class PartiesFailure extends PartiesState {
  final String message;

  const PartiesFailure(this.message);

  @override
  List<Object?> get props => [message];
}
