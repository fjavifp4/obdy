import '../entities/chat.dart';

abstract class ChatRepository {
  Future<void> initialize(String token);
  Future<List<Chat>> getChats();
  Future<Chat> createChat(String message, {String? vehicleId});
  Future<Chat> addMessage(String chatId, String message);
  Future<Chat> getOrCreateChat(String? vehicleId);
  Future<Chat> clearChat(String chatId);
} 