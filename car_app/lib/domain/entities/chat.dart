class Chat {
  final String id;
  final String? vehicleId;
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Chat({
    required this.id,
    this.vehicleId,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });
}

class Message {
  final String id;
  final String content;
  final bool isUser;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.content,
    required this.isUser,
    required this.createdAt,
  });
} 
