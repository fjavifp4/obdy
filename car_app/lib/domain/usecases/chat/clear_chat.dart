import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/entities/chat.dart';
import 'package:car_app/domain/repositories/chat_repository.dart';

class ClearChat {
  final ChatRepository repository;

  ClearChat(this.repository);

  Future<Either<Failure, Chat>> call(String chatId) async {
    try {
      final chat = await repository.clearChat(chatId);
      return Either.right(chat);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 