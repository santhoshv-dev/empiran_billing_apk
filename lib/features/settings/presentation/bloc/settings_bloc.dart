import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository settingsRepository;

  SettingsBloc({required this.settingsRepository}) : super(const SettingsInitial()) {
    on<LoadSettingsRequested>(_onLoadSettingsRequested);
    on<SaveCompanyRequested>(_onSaveCompanyRequested);
    on<SaveInvoiceSettingsRequested>(_onSaveInvoiceSettingsRequested);
    on<AddCategoryRequested>(_onAddCategoryRequested);
    on<DeleteCategoryRequested>(_onDeleteCategoryRequested);
    on<CreateStaffUserRequested>(_onCreateStaffUserRequested);
    on<UpdateStaffUserRequested>(_onUpdateStaffUserRequested);
    on<DeleteStaffUserRequested>(_onDeleteStaffUserRequested);
  }

  Future<void> _onLoadSettingsRequested(
    LoadSettingsRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());
    try {
      final company = await settingsRepository.loadCompany();
      final invoiceSettings = await settingsRepository.loadInvoiceSettings();
      final categories = await settingsRepository.loadCategories();
      final users = await settingsRepository.loadUsers();

      emit(SettingsLoaded(
        company: company,
        invoiceSettings: invoiceSettings,
        categories: categories,
        users: users,
      ));
    } catch (e) {
      emit(SettingsFailure(e.toString()));
    }
  }

  Future<void> _onSaveCompanyRequested(
    SaveCompanyRequested event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final current = state as SettingsLoaded;
    try {
      await settingsRepository.saveCompany(event.company);
      emit(current.copyWith(
        company: event.company,
        message: 'Business profile updated successfully.',
      ));
    } catch (e) {
      emit(SettingsFailure(e.toString()));
    }
  }

  Future<void> _onSaveInvoiceSettingsRequested(
    SaveInvoiceSettingsRequested event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final current = state as SettingsLoaded;
    try {
      await settingsRepository.saveInvoiceSettings(event.settings);
      emit(current.copyWith(
        invoiceSettings: event.settings,
        message: 'Numbering sequence controls saved.',
      ));
    } catch (e) {
      emit(SettingsFailure(e.toString()));
    }
  }

  Future<void> _onAddCategoryRequested(
    AddCategoryRequested event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final current = state as SettingsLoaded;
    final trimmed = event.category.trim();
    if (trimmed.isEmpty || current.categories.contains(trimmed)) return;

    await settingsRepository.addCategory(
      trimmed,
      imageBase64: event.imageBase64,
    );
    final updated = List<String>.from(current.categories)..add(trimmed);
    emit(current.copyWith(categories: updated));
  }

  Future<void> _onDeleteCategoryRequested(
    DeleteCategoryRequested event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final current = state as SettingsLoaded;
    final updated = List<String>.from(current.categories)..remove(event.category.trim());
    await settingsRepository.deleteCategory(event.category);
    emit(current.copyWith(categories: updated));
  }

  Future<void> _onCreateStaffUserRequested(
    CreateStaffUserRequested event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final current = state as SettingsLoaded;
    try {
      await settingsRepository.createUser(
        name: event.name,
        username: event.username,
        email: event.email,
        password: event.password,
        role: event.role,
      );
      final users = await settingsRepository.loadUsers();
      emit(current.copyWith(users: users, message: 'Staff user created.'));
    } catch (e) {
      emit(SettingsFailure(e.toString()));
    }
  }

  Future<void> _onUpdateStaffUserRequested(
    UpdateStaffUserRequested event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final current = state as SettingsLoaded;
    try {
      await settingsRepository.updateUser(
        id: event.id,
        username: event.username,
        name: event.name,
        email: event.email,
        password: event.password,
        role: event.role,
      );
      final users = await settingsRepository.loadUsers();
      emit(current.copyWith(users: users, message: 'Staff user updated.'));
    } catch (e) {
      emit(SettingsFailure(e.toString()));
    }
  }

  Future<void> _onDeleteStaffUserRequested(
    DeleteStaffUserRequested event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;
    final current = state as SettingsLoaded;
    try {
      await settingsRepository.deleteUser(event.username, id: event.id);
      final users = await settingsRepository.loadUsers();
      emit(current.copyWith(users: users, message: 'Staff user removed.'));
    } catch (e) {
      emit(SettingsFailure(e.toString()));
    }
  }
}
