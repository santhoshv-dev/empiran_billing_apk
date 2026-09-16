import 'package:equatable/equatable.dart';
import '../../../../models.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

class SettingsLoaded extends SettingsState {
  final Company company;
  final InvoiceSettings invoiceSettings;
  final List<String> categories;
  final List<Map<String, String>> users;
  final String? message;

  const SettingsLoaded({
    required this.company,
    required this.invoiceSettings,
    required this.categories,
    required this.users,
    this.message,
  });

  SettingsLoaded copyWith({
    Company? company,
    InvoiceSettings? invoiceSettings,
    List<String>? categories,
    List<Map<String, String>>? users,
    String? message,
  }) {
    return SettingsLoaded(
      company: company ?? this.company,
      invoiceSettings: invoiceSettings ?? this.invoiceSettings,
      categories: categories ?? this.categories,
      users: users ?? this.users,
      message: message,
    );
  }

  @override
  List<Object?> get props => [company, invoiceSettings, categories, users, message];
}

class SettingsFailure extends SettingsState {
  final String message;

  const SettingsFailure(this.message);

  @override
  List<Object?> get props => [message];
}
