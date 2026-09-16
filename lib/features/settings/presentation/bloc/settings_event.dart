import 'package:equatable/equatable.dart';
import '../../../../models.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettingsRequested extends SettingsEvent {
  const LoadSettingsRequested();
}

class SaveCompanyRequested extends SettingsEvent {
  final Company company;

  const SaveCompanyRequested(this.company);

  @override
  List<Object?> get props => [company];
}

class SaveInvoiceSettingsRequested extends SettingsEvent {
  final InvoiceSettings settings;

  const SaveInvoiceSettingsRequested(this.settings);

  @override
  List<Object?> get props => [settings];
}

class AddCategoryRequested extends SettingsEvent {
  final String category;

  const AddCategoryRequested(this.category);

  @override
  List<Object?> get props => [category];
}

class DeleteCategoryRequested extends SettingsEvent {
  final String category;

  const DeleteCategoryRequested(this.category);

  @override
  List<Object?> get props => [category];
}

class CreateStaffUserRequested extends SettingsEvent {
  final String name;
  final String username;
  final String email;
  final String password;
  final String role;

  const CreateStaffUserRequested({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    required this.role,
  });

  @override
  List<Object?> get props => [name, username, email, password, role];
}

class UpdateStaffUserRequested extends SettingsEvent {
  final String username;
  final String name;
  final String email;
  final String? password;
  final String role;

  const UpdateStaffUserRequested({
    required this.username,
    required this.name,
    required this.email,
    this.password,
    required this.role,
  });

  @override
  List<Object?> get props => [username, name, email, password, role];
}

class DeleteStaffUserRequested extends SettingsEvent {
  final String username;

  const DeleteStaffUserRequested(this.username);

  @override
  List<Object?> get props => [username];
}
