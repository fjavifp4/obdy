import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/usecases.dart' as usecases;
import 'chat_event.dart';
import 'chat_state.dart';

class ResetChat extends ChatEvent {}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final usecases.GetOrCreateChat _getOrCreateChat;
  final usecases.CreateChat _createChat;
  final usecases.AddMessage _addMessage;
  final usecases.ClearChat _clearChat;
  final usecases.InitializeRepositories _initializeRepositories;

  ChatBloc({
    required usecases.GetOrCreateChat getOrCreateChat,
    required usecases.CreateChat createChat,
    required usecases.AddMessage addMessage,
    required usecases.ClearChat clearChat,
    required usecases.InitializeRepositories initializeRepositories,
  }) : _getOrCreateChat = getOrCreateChat,
       _createChat = createChat,
       _addMessage = addMessage,
       _clearChat = clearChat,
       _initializeRepositories = initializeRepositories,
       super(ChatInitial()) {
    on<LoadChat>(_handleLoadChat);
    on<CreateChat>(_handleCreateChat);
    on<SendMessage>(_handleSendMessage);
    on<InitializeChatRepository>(_handleInitialize);
    on<ClearChat>(_handleClearChat);
    on<ResetChat>((event, emit) => emit(ChatInitial()));
  }

  Future<void> _handleLoadChat(
    LoadChat event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoading());
    final result = await _getOrCreateChat(event.vehicleId ?? '');
    await result.fold(
      (failure) async => emit(ChatError(failure.message)),
      (chat) async => emit(ChatLoaded(chat)),
    );
  }

  Future<void> _handleCreateChat(
    CreateChat event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoading());
    final result = await _createChat(event.message, event.vehicleId ?? '');
    await result.fold(
      (failure) async => emit(ChatError(failure.message)),
      (chat) async => emit(ChatLoaded(chat)),
    );
  }

  Future<void> _handleSendMessage(
    SendMessage event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is ChatLoaded) {
      emit(ChatSending(
        currentState.chat,
        event.message,
      ));
      
      final result = await _addMessage(event.chatId, event.message);
      await result.fold(
        (failure) async {
          emit(currentState);
          emit(ChatError(failure.message));
        },
        (chat) async => emit(ChatLoaded(chat)),
      );
    }
  }

  Future<void> _handleInitialize(
    InitializeChatRepository event,
    Emitter<ChatState> emit,
  ) async {
    await _initializeRepositories(event.token);
  }

  Future<void> _handleClearChat(
    ClearChat event,
    Emitter<ChatState> emit,
  ) async {
    final result = await _clearChat(event.chatId);
    await result.fold(
      (failure) async => emit(ChatError(failure.message)),
      (chat) async => emit(ChatLoaded(chat)),
    );
  }

  void reset() {
    add(ResetChat());
  }
} 
