import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginSubmitted extends AuthEvent {
  final String usernameOrEmail;
  final String password;

  const AuthLoginSubmitted({
    required this.usernameOrEmail,
    required this.password,
  });

  @override
  List<Object?> get props => [usernameOrEmail, password];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
