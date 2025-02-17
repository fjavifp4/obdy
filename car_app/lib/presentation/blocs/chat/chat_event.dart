import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadChat extends ChatEvent {
  final String? vehicleId;
  
  const LoadChat({this.vehicleId});
  
  @override
  List<Object?> get props => [vehicleId];
}

class CreateChat extends ChatEvent {
  final String message;
  final String? vehicleId;

  const CreateChat({
    required this.message,
    this.vehicleId,
  });

  @override
  List<Object?> get props => [message, vehicleId];
}

class SendMessage extends ChatEvent {
  final String chatId;
  final String message;

  const SendMessage({
    required this.chatId,
    required this.message,
  });

  @override
  List<Object> get props => [chatId, message];
}

class SelectChat extends ChatEvent {
  final String chatId;

  const SelectChat(this.chatId);

  @override
  List<Object> get props => [chatId];
}

class InitializeChatRepository extends ChatEvent {
  final String token;

  const InitializeChatRepository(this.token);

  @override
  List<Object> get props => [token];
}

class ClearChat extends ChatEvent {
  final String chatId;

  const ClearChat(this.chatId);

  @override
  List<Object> get props => [chatId];
} 