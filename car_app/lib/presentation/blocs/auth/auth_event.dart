import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class InitializeApp extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested(this.email, this.password);

  @override
  List<Object> get props => [email, password];
}

class RegisterRequested extends AuthEvent {
  final String username;
  final String email;
  final String password;

  const RegisterRequested({
    required this.username,
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [username, email, password];
}

class LogoutRequested extends AuthEvent {
  final VoidCallback? onLogoutSuccess;

  const LogoutRequested({this.onLogoutSuccess});

  @override
  List<Object?> get props => [onLogoutSuccess];
}

class GetUserDataRequested extends AuthEvent {}

class ChangePasswordRequested extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordRequested({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object> get props => [currentPassword, newPassword];
}

class CheckAuthStatus extends AuthEvent {
  @override
  List<Object?> get props => [];
}

class InitializeAuth extends AuthEvent {
  const InitializeAuth();

  @override
  List<Object?> get props => [];
} 
