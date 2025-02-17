import '../../domain/entities/chat.dart' as entity;

class MessageModel {
  final String id;
  final String content;
  final bool isUserMessage;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.content,
    required this.isUserMessage,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      isUserMessage: json['isFromUser'] ?? false,
      createdAt: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  entity.Message toEntity() {
    return entity.Message(
      id: id,
      content: content,
      isUser: isUserMessage,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUserMessage': isUserMessage,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ChatModel {
  final String id;
  final String? vehicleId;
  final List<MessageModel> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatModel({
    required this.id,
    this.vehicleId,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'],
      vehicleId: json['vehicleId'],
      messages: (json['messages'] as List)
          .map((m) => MessageModel.fromJson(m))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  entity.Chat toEntity() {
    return entity.Chat(
      id: id,
      vehicleId: vehicleId,
      messages: messages.map((m) => m.toEntity()).toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
} 