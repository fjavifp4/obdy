import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user.dart';
import '../models/user_model.dart';
import '../datasource/api_config.dart';

class AuthRepositoryImpl implements AuthRepository {
  String? _token;

  @override
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  @override
  Future<User> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        _token = tokenData['access_token'];
        
        // Guardar el token en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);

        // Obtener datos del usuario usando el token
        final userResponse = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/users/me'),
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
        );

        if (userResponse.statusCode == 200) {
          final userData = json.decode(userResponse.body);
          final userModel = UserModel.fromJson({...userData, 'token': _token});
          return userModel.toEntity();
        } else {
          throw Exception('Error al obtener datos del usuario');
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Error de autenticación');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<String> register(String username, String email, String password) async {
    try {
      final registerResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (registerResponse.statusCode == 201) {
        // El backend ahora devuelve el token directamente en el registro
        final tokenData = json.decode(registerResponse.body);
        final token = tokenData['access_token'];
        if (token == null) {
          throw Exception('El backend no devolvió un token después del registro.');
        }
        _token = token; // Guardamos el token internamente
        // Guardar el token en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        return token; // Devolvemos el token
      } else {
        final error = json.decode(registerResponse.body);
        throw Exception(error['detail'] ?? 'Error en el registro');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<User> getUserData() async {
    if (_token == null) {
      throw Exception('No hay token disponible');
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        final userModel = UserModel.fromJson({...userData, 'token': _token});
        return userModel.toEntity();
      } else {
        throw Exception('Error al obtener datos del usuario');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (_token == null) throw Exception('No hay token de autenticación');
    
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Error al cambiar la contraseña');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      _token = null;
    } catch (e) {
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  @override
  String? get token => _token;
} 
