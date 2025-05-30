import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/repositories/chat_repository.dart';
import '../../domain/entities/chat.dart';
import '../models/chat_model.dart';
import '../datasource/api_config.dart';

class ChatRepositoryImpl implements ChatRepository {
  String? _token;

  @override
  Future<void> initialize(String token) async {
    _token = token;
  }

  @override
  Future<List<Chat>> getChats() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatsEndpoint}'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> chatsJson = json.decode(response.body);
        return chatsJson
            .map((json) => ChatModel.fromJson(json).toEntity())
            .toList();
      } else {
        throw Exception('Error al obtener los chats');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<Chat> createChat(String message, {String? vehicleId}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatsEndpoint}'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'message': message,
        'vehicleId': vehicleId,
        'language': 'es',
      }),
    );

    if (response.statusCode == 201) {
      return ChatModel.fromJson(json.decode(response.body)).toEntity();
    } else {
      throw Exception('Error al crear el chat');
    }
  }

  @override
  Future<Chat> addMessage(String chatId, String message) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatsEndpoint}/$chatId/messages'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'content': message,
      }),
    );

    if (response.statusCode == 200) {
      return ChatModel.fromJson(json.decode(response.body)).toEntity();
    } else {
      throw Exception('Error al enviar el mensaje');
    }
  }

  @override
  Future<Chat> getOrCreateChat(String? vehicleId) async {
    try {
      if (_token == null) {
        throw Exception('Token no inicializado');
      }

      final body = vehicleId != null 
          ? {'vehicleId': vehicleId, 'language': 'es'}
          : {'vehicleId': null, 'language': 'es'};
      
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatsEndpoint}');
      
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = json.decode(response.body);
          print('Respuesta del servidor: $responseData');
          return ChatModel.fromJson(responseData).toEntity();
        } catch (e) {
          print('Error al parsear la respuesta: $e');
          throw Exception('Error al procesar la respuesta del servidor');
        }
      } else {
        Map<String, dynamic> errorData;
        try {
          errorData = json.decode(response.body);
        } catch (e) {
          throw Exception('Error en la respuesta del servidor');
        }
        
        final errorMessage = errorData['detail'] ?? 'Error al crear el chat';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error en getOrCreateChat: $e');
      rethrow;
    }
  }

  @override
  Future<Chat> clearChat(String chatId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatsEndpoint}/$chatId/clear'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return ChatModel.fromJson(json.decode(response.body)).toEntity();
    } else {
      throw Exception('Error al limpiar el chat');
    }
  }
} 
