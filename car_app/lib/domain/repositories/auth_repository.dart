import '../entities/user.dart';

abstract class AuthRepository {
  Future<void> init();
  Future<User> login(String email, String password);
  Future<User> register(String username, String email, String password);
  Future<User> getUserData();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> logout();
  String? get token;
} 