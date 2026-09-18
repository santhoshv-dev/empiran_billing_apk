import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String username;
  final String name;
  final String email;
  final String role;
  final String? token;

  const UserModel({
    this.id = '',
    required this.username,
    required this.name,
    this.email = '',
    this.role = 'Biller',
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ??
          json['displayName']?.toString() ??
          json['username']?.toString() ??
          '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Biller',
      token: token ?? json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': name,
        'email': email,
        'role': role,
        if (token != null) 'token': token,
      };

  UserModel copyWith({
    String? id,
    String? username,
    String? name,
    String? email,
    String? role,
    String? token,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      token: token ?? this.token,
    );
  }

  @override
  List<Object?> get props => [id, username, name, email, role, token];
}
