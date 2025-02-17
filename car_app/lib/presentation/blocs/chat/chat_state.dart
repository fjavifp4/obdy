import 'package:equatable/equatable.dart';
import '../../../domain/entities/chat.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final Chat chat;

  const ChatLoaded(this.chat);

  @override
  List<Object> get props => [chat];
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object> get props => [message];
}

class ChatSending extends ChatLoaded {
  final String pendingMessage;

  const ChatSending(super.chat, this.pendingMessage);

  @override
  List<Object> get props => [chat, pendingMessage];
} 